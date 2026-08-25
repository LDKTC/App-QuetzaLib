import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/book.dart';
import '../models/book_page.dart';
import '../models/category.dart';
import '../models/cover_preset.dart';
import '../models/name_alias_group.dart';
import '../models/stamp.dart';
import 'database_service.dart';
import 'image_storage_service.dart';

/// The result of a successful [BackupService.importFromZipBytes] call, for
/// the settings screen to report back to the user (e.g. "Imported 42
/// books").
class BackupImportResult {
  const BackupImportResult({required this.bookCount});

  final int bookCount;
}

/// Raised when a file handed to [BackupService.importFromZipBytes] isn't a
/// QuetzaLib backup archive (wrong file, corrupted zip, or missing the
/// `data.json` entry every export writes).
class InvalidBackupException implements Exception {
  const InvalidBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The zip entry name every image is stored under, followed by a
/// per-archive sequence number -- e.g. `images/img_0.jpg`. Only the
/// `images/` prefix is load-bearing (it's how [importFromZipBytes] tells an
/// in-archive image apart from a `http(s)://` URL kept as-is), the rest is
/// just a unique, human-readable filename.
const _imageEntryPrefix = 'images/';
const _dataEntryName = 'data.json';

/// Exports the whole library (books, categories, reading stamps, cover
/// presets, saved pages, name-alias sets) plus every locally-stored cover
/// and page photo they reference into a single `.zip` file, and restores
/// one back.
///
/// The archive holds a `data.json` dump of every table (using the same
/// `toMap()`/`fromMap()` shape [DatabaseService] itself reads and writes,
/// so nothing needs re-deriving) plus an `images/` folder of the referenced
/// photos. A book's own remote API thumbnail (`http(s)://`) is kept as a
/// plain URL in `data.json` rather than downloaded, since it isn't this
/// app's file to bundle and can always be re-fetched.
///
/// Restoring replaces the entire library: every table is wiped and
/// repopulated from the archive (see [DatabaseService.replaceAllData]),
/// and every referenced image is re-saved through [ImageStorageService] so
/// it gets a fresh, valid path on whatever device/platform is importing --
/// the paths recorded in `data.json` are only ever zip-relative keys or
/// remote URLs, never a raw device file path that wouldn't survive the
/// trip.
class BackupService {
  BackupService({DatabaseService? db, ImageStorageService? images})
      : _db = db ?? DatabaseService.instance,
        _images = images ?? ImageStorageService.instance;

  static final BackupService instance = BackupService();

  final DatabaseService _db;
  final ImageStorageService _images;

  Future<Uint8List> exportToZipBytes() async {
    final books = await _db.getAllBooks();
    final categories = await _db.getAllCategories();
    final bookCategoryLinks = await _db.getAllBookCategoryLinks();
    final aliasGroups = await _db.getAllNameAliasGroups();
    final stamps = await _db.getAllStamps();
    final presets = await _db.getAllCoverPresets();
    final pages = await _db.getAllBookPages();

    final archive = Archive();
    final embeddedPaths = <String, String>{};
    var imageSequence = 0;

    /// Embeds the local image at [path] into [archive] (once per distinct
    /// path) and returns the zip-relative key that stands in for it in
    /// `data.json`. Remote URLs, empty/null paths, and local images that
    /// have gone missing on disk all pass through unchanged (the last case
    /// simply won't have anything to restore on import).
    Future<String?> embedImage(String? path) async {
      if (path == null || path.isEmpty) return path;
      if (isRemoteImagePath(path)) return path;
      final alreadyEmbedded = embeddedPaths[path];
      if (alreadyEmbedded != null) return alreadyEmbedded;

      final bytes = await _images.readBytes(path);
      if (bytes == null) return null;

      final entryName =
          '$_imageEntryPrefix'
          'img_${imageSequence++}'
          '${imageExtensionFor(path)}';
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
      embeddedPaths[path] = entryName;
      return entryName;
    }

    final presetMaps = <Map<String, Object?>>[];
    for (final preset in presets) {
      presetMaps.add({
        ...preset.toMap(),
        'frontImagePath': await embedImage(preset.frontImagePath),
        'spineImagePath': await embedImage(preset.spineImagePath),
        'backImagePath': await embedImage(preset.backImagePath),
      });
    }

    final pageMaps = <Map<String, Object?>>[];
    for (final page in pages) {
      pageMaps.add({
        ...page.toMap(),
        'imagePath': await embedImage(page.imagePath) ?? page.imagePath,
      });
    }

    final data = <String, Object?>{
      'formatVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'books': books.map((b) => b.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'bookCategories': [
        for (final entry in bookCategoryLinks.entries)
          for (final categoryId in entry.value)
            {'bookId': entry.key, 'categoryId': categoryId},
      ],
      'nameAliasGroups': aliasGroups.map((g) => g.toMap()).toList(),
      'readingStamps': stamps.map((s) => s.toMap()).toList(),
      'coverPresets': presetMaps,
      'bookPages': pageMaps,
    };

    final jsonBytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile(_dataEntryName, jsonBytes.length, jsonBytes));

    // `encode`'s nullability has varied across `archive` package versions --
    // the explicit `List<int>?` type keeps this safe either way.
    final List<int>? encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  Future<BackupImportResult> importFromZipBytes(Uint8List zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw InvalidBackupException('Not a valid backup file: $e');
    }

    final dataEntry = _findEntry(archive, _dataEntryName);
    if (dataEntry == null) {
      throw const InvalidBackupException(
        'This file doesn\'t look like a QuetzaLib backup (missing data.json).',
      );
    }
    final data =
        jsonDecode(utf8.decode(dataEntry.content as List<int>))
            as Map<String, Object?>;

    /// The inverse of `embedImage` above: re-saves the bytes for a
    /// zip-relative [path] through [ImageStorageService] so it gets a
    /// fresh path valid on this device/platform. Remote URLs and
    /// null/empty paths pass through unchanged.
    Future<String?> restoreImage(
      String? path,
      String subfolder,
      int bookId,
    ) async {
      if (path == null || path.isEmpty) return path;
      if (isRemoteImagePath(path)) return path;
      if (!path.startsWith(_imageEntryPrefix)) return null;
      final entry = _findEntry(archive, path);
      if (entry == null) return null;
      final bytes = Uint8List.fromList(entry.content as List<int>);
      return _images.saveImportedImage(
        bytes,
        subfolder,
        bookId,
        imageExtensionFor(path),
      );
    }

    final booksJson = _listOf(data['books']);
    final categoriesJson = _listOf(data['categories']);
    final bookCategoriesJson = _listOf(data['bookCategories']);
    final aliasGroupsJson = _listOf(data['nameAliasGroups']);
    final stampsJson = _listOf(data['readingStamps']);
    final presetsJson = _listOf(data['coverPresets']);
    final pagesJson = _listOf(data['bookPages']);

    final restoredPresets = <BookCoverPreset>[];
    for (final map in presetsJson) {
      final bookId = map['bookId'] as int;
      restoredPresets.add(
        BookCoverPreset.fromMap({
          ...map,
          'frontImagePath': await restoreImage(
            map['frontImagePath'] as String?,
            'covers',
            bookId,
          ),
          'spineImagePath': await restoreImage(
            map['spineImagePath'] as String?,
            'covers',
            bookId,
          ),
          'backImagePath': await restoreImage(
            map['backImagePath'] as String?,
            'covers',
            bookId,
          ),
        }),
      );
    }

    final restoredPages = <BookPage>[];
    for (final map in pagesJson) {
      final bookId = map['bookId'] as int;
      restoredPages.add(
        BookPage.fromMap({
          ...map,
          'imagePath':
              await restoreImage(map['imagePath'] as String?, 'pages', bookId) ??
                  map['imagePath'],
        }),
      );
    }

    final books = booksJson.map(Book.fromMap).toList();
    await _db.replaceAllData(
      books: books,
      categories: categoriesJson.map(BookCategory.fromMap).toList(),
      bookCategoryLinks: bookCategoriesJson,
      aliasGroups: aliasGroupsJson.map(NameAliasGroup.fromMap).toList(),
      stamps: stampsJson.map(ReadingStamp.fromMap).toList(),
      coverPresets: restoredPresets,
      pages: restoredPages,
    );

    return BackupImportResult(bookCount: books.length);
  }

  ArchiveFile? _findEntry(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.name == name) return file;
    }
    return null;
  }

  List<Map<String, Object?>> _listOf(Object? value) =>
      (value as List? ?? const []).cast<Map<String, Object?>>();
}

/// The file extension (with leading dot, e.g. `.jpg`) to save a restored
/// image under, guessed from [path]'s own extension and falling back to
/// `.jpg` for anything unrecognizable -- a path with no dot in its last
/// segment, or a "extension" implausibly long to actually be one (a sign
/// the dot found belongs to something other than a filename suffix).
String imageExtensionFor(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1 || dot == path.length - 1) return '.jpg';
  final ext = path.substring(dot).toLowerCase();
  return ext.length <= 5 ? ext : '.jpg';
}
