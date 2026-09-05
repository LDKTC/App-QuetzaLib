import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import '../models/book.dart';
import '../models/book_page.dart';
import '../models/category.dart';
import '../models/cover_preset.dart';
import '../models/name_alias_group.dart';
import '../models/stamp.dart';
import '../services/database_service.dart';
import '../services/image_storage_service.dart';
import '../services/name_alias_index.dart';
import '../services/settings_service.dart';
import 'library_search.dart';

enum CategoryFilter { all }

/// The reading-status filter chips shown in the library: every [StampType]
/// plus "not started" (a book with no stamps at all). The provider's
/// `statusFilter` being `null` itself means "All" / no filter.
enum LibraryStatusFilter { notStarted, reading, finished, dropped, paused }

extension LibraryStatusFilterX on LibraryStatusFilter {
  String label(AppLocalizations t) => switch (this) {
        LibraryStatusFilter.notStarted => t.statusNotStarted,
        LibraryStatusFilter.reading => t.statusReading,
        LibraryStatusFilter.finished => t.statusFinished,
        LibraryStatusFilter.dropped => t.statusDropped,
        LibraryStatusFilter.paused => t.statusPaused,
      };

  /// The [StampType] a book's current stamp must have to match this
  /// filter, or `null` for [LibraryStatusFilter.notStarted] (no stamps).
  StampType? get stampType => switch (this) {
        LibraryStatusFilter.notStarted => null,
        LibraryStatusFilter.reading => StampType.reading,
        LibraryStatusFilter.finished => StampType.finished,
        LibraryStatusFilter.dropped => StampType.dropped,
        LibraryStatusFilter.paused => StampType.paused,
      };
}

/// Holds the in-memory library state (books, categories, reading-status
/// stamp timelines, cover presets, and saved pages) backed by sqflite, and
/// the current search/filter selections for the library list screen.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider({DatabaseService? db, SettingsService? settings})
      : _db = db ?? DatabaseService.instance,
        _settings = settings ?? SettingsService.instance;

  final DatabaseService _db;
  final SettingsService _settings;

  List<Book> _books = [];
  List<BookCategory> _categories = [];
  Map<int, List<int>> _bookCategoryLinks = {};
  Map<int, List<String>> _categoryNamesByBookId = {};
  Map<int, String?> _primaryCategoryByBookId = {};
  List<NameAliasGroup> _aliasGroups = [];
  NameAliasIndex _aliasIndex = NameAliasIndex.empty;
  Map<int, List<ReadingStamp>> _stampsByBook = {};
  Map<int, List<BookCoverPreset>> _coverPresetsByBook = {};
  Map<int, List<BookPage>> _pagesByBook = {};
  LibraryViewMode _viewMode = LibraryViewMode.list;
  LibrarySortField _sortField = LibrarySortField.dateAdded;
  AppLocale _appLocale = AppLocale.system;
  AppThemeMode _appThemeMode = AppThemeMode.system;

  String _searchQuery = '';
  LibraryStatusFilter? _statusFilter;
  int? _categoryFilterId;
  bool _loading = false;

  List<BookCategory> get categories => List.unmodifiable(_categories);

  /// The user's name-alias sets (e.g. `TH` / `thai` / `ไทย`), managed on
  /// the categories screen and applied by [filteredBooks].
  List<NameAliasGroup> get aliasGroups => List.unmodifiable(_aliasGroups);

  /// [aliasGroups] in the form the search matcher uses.
  NameAliasIndex get aliasIndex => _aliasIndex;

  String get searchQuery => _searchQuery;
  LibraryStatusFilter? get statusFilter => _statusFilter;
  int? get categoryFilterId => _categoryFilterId;
  bool get loading => _loading;
  LibraryViewMode get viewMode => _viewMode;
  ShelfDisplayMode get shelfDisplayMode => _viewMode.shelfDisplayMode;
  LibrarySortField get sortField => _sortField;
  AppLocale get appLocale => _appLocale;
  AppThemeMode get appThemeMode => _appThemeMode;

  List<int> categoryIdsFor(int bookId) =>
      List.unmodifiable(_bookCategoryLinks[bookId] ?? const []);

  /// The names of [bookId]'s linked categories, alphabetically ordered.
  List<String> categoryNamesFor(int bookId) =>
      List.unmodifiable(_categoryNamesByBookId[bookId] ?? const []);

  Book? getById(int id) {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Previously-used field values, for the edit form's suggestion dropdowns
  // ---------------------------------------------------------------------

  Set<String> get knownTitles => {for (final b in _books) b.title};

  Set<String> get knownAuthors => {for (final b in _books) ...b.authors};

  Set<String> get knownIllustrators =>
      {for (final b in _books) ...b.illustrators};

  Set<String> get knownPublishers => {
        for (final b in _books)
          if (b.publisher != null && b.publisher!.isNotEmpty) b.publisher!,
      };

  Set<String> get knownSeries => {
        for (final b in _books)
          if (b.series != null && b.series!.isNotEmpty) b.series!,
      };

  Set<String> get knownGenres => {
        for (final b in _books)
          if (b.genre != null && b.genre!.isNotEmpty) b.genre!,
      };

  Set<String> get knownLanguages => {
        for (final b in _books)
          if (b.language != null && b.language!.isNotEmpty) b.language!,
      };

  /// Every name already sitting in the library's books — authors,
  /// illustrators, series, genres, languages, publishers and categories —
  /// offered as suggestions when building a name set instead of retyping
  /// them. Always reflects the current library, so a name just entered on
  /// a new or edited book is available here immediately.
  Set<String> get nameSetSuggestions => {
        ...knownAuthors,
        ...knownIllustrators,
        ...knownSeries,
        ...knownGenres,
        ...knownLanguages,
        ...knownPublishers,
        for (final category in _categories) category.name,
      };

  /// The most recent stamp for [bookId] (by timestamp), or null if the
  /// book has no stamps yet — i.e. "not started".
  ReadingStamp? currentStampFor(int bookId) =>
      latestStamp(_stampsByBook[bookId] ?? const []);

  /// All of [bookId]'s stamps, most recent first — the reading-status
  /// timeline shown on the book detail screen.
  List<ReadingStamp> stampsFor(int bookId) {
    final stamps = List<ReadingStamp>.from(_stampsByBook[bookId] ?? const []);
    stamps.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return stamps;
  }

  List<BookCoverPreset> coverPresetsFor(int bookId) =>
      List.unmodifiable(_coverPresetsByBook[bookId] ?? const []);

  /// The preset currently used to render [bookId] on the visual shelf, if
  /// it has any presets at all.
  BookCoverPreset? activeCoverPresetFor(int bookId) {
    final presets = _coverPresetsByBook[bookId];
    if (presets == null) return null;
    for (final preset in presets) {
      if (preset.isActive) return preset;
    }
    return null;
  }

  List<BookPage> pagesFor(int bookId) {
    final pages = List<BookPage>.from(_pagesByBook[bookId] ?? const []);
    pages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pages;
  }

  /// Total number of books in the library, ignoring any active filters —
  /// used alongside [statusCounts]/[categoryCounts] to show "X books"
  /// counts next to the filter options themselves.
  int get totalBookCount => _books.length;

  /// How many books currently sit under each reading-status filter,
  /// unaffected by the currently active filters/search — shown next to
  /// each option in the status filter dropdown.
  Map<LibraryStatusFilter, int> get statusCounts {
    final counts = {for (final f in LibraryStatusFilter.values) f: 0};
    for (final book in _books) {
      final current = currentStampFor(book.id!)?.type;
      final filter =
          LibraryStatusFilter.values.firstWhere((f) => f.stampType == current);
      counts[filter] = counts[filter]! + 1;
    }
    return counts;
  }

  /// How many books are linked to each category, keyed by category id —
  /// shown next to each option in the category filter dropdown.
  Map<int, int> get categoryCounts {
    final counts = <int, int>{};
    for (final ids in _bookCategoryLinks.values) {
      for (final id in ids) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<Book> get filteredBooks {
    final books = _books.where((book) {
      if (_statusFilter != null) {
        final current = currentStampFor(book.id!)?.type;
        if (current != _statusFilter!.stampType) return false;
      }
      if (_categoryFilterId != null) {
        final ids = _bookCategoryLinks[book.id] ?? const [];
        if (!ids.contains(_categoryFilterId)) return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final matches = bookMatchesQuery(
          book,
          _searchQuery,
          aliasIndex: _aliasIndex,
          categoryNames: _categoryNamesByBookId[book.id] ?? const [],
        );
        if (!matches) return false;
      }
      return true;
    }).toList();
    books.sort(_compareBySortField);
    return books;
  }

  /// Orders two books per [sortField]. [LibrarySortField.dateAdded] keeps
  /// the newest-first order already used everywhere else in the app; every
  /// other field sorts ascending (A→Z / lowest ISBN first), with books
  /// missing that field pushed to the end rather than clustered at the
  /// top by sorting as empty strings. Whichever field is primary, ties are
  /// broken the same way — by language, then category, then title (see
  /// [_compareSecondaryFields]) — instead of leaving same-key books in
  /// whatever order they happened to come out of the database in.
  int _compareBySortField(Book a, Book b) {
    final primaryCompare = _comparePrimaryField(a, b);
    if (primaryCompare != 0) return primaryCompare;
    return _compareSecondaryFields(a, b);
  }

  int _comparePrimaryField(Book a, Book b) {
    switch (_sortField) {
      case LibrarySortField.dateAdded:
        return b.dateAdded.compareTo(a.dateAdded);
      case LibrarySortField.title:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case LibrarySortField.author:
        return a.authorsDisplay
            .toLowerCase()
            .compareTo(b.authorsDisplay.toLowerCase());
      case LibrarySortField.publisher:
        return _compareNullableStrings(a.publisher, b.publisher);
      case LibrarySortField.isbn:
        return _compareNullableStrings(a.isbn13, b.isbn13);
      case LibrarySortField.series:
        // Within the same series, group by language then category before
        // ordering by volume, so translated/alternate editions of a series
        // don't interleave with each other by volume number alone.
        final hasSeriesCompare =
            (a.series != null && a.series!.isNotEmpty ? 0 : 1)
                .compareTo(b.series != null && b.series!.isNotEmpty ? 0 : 1);
        if (hasSeriesCompare != 0) return hasSeriesCompare;
        final seriesCompare = _compareNullableStrings(a.series, b.series);
        if (seriesCompare != 0) return seriesCompare;
        final languageCompare = _compareNullableStrings(a.language, b.language);
        if (languageCompare != 0) return languageCompare;
        final categoryCompare = _compareNullableStrings(
          _primaryCategoryByBookId[a.id],
          _primaryCategoryByBookId[b.id],
        );
        if (categoryCompare != 0) return categoryCompare;
        return (a.seriesVolume ?? 1 << 30).compareTo(b.seriesVolume ?? 1 << 30);
      case LibrarySortField.languageGenre:
        final languageCompare = _compareNullableStrings(a.language, b.language);
        if (languageCompare != 0) return languageCompare;
        final genreCompare = _compareNullableStrings(a.genre, b.genre);
        if (genreCompare != 0) return genreCompare;
        return (a.seriesVolume ?? 1 << 30).compareTo(b.seriesVolume ?? 1 << 30);
    }
  }

  /// The tie-breaker applied after whatever [sortField] is currently
  /// primary: language, then category (a book's alphabetically-first
  /// linked category, from [_primaryCategoryByBookId]), then title as the
  /// final fallback so equal-key books still land in a stable order.
  int _compareSecondaryFields(Book a, Book b) {
    final languageCompare = _compareNullableStrings(a.language, b.language);
    if (languageCompare != 0) return languageCompare;
    final categoryCompare = _compareNullableStrings(
      _primaryCategoryByBookId[a.id],
      _primaryCategoryByBookId[b.id],
    );
    if (categoryCompare != 0) return categoryCompare;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  /// Case-insensitive string compare with null/empty pushed after every
  /// real value (rather than sorting first, as `''` naturally would).
  int _compareNullableStrings(String? a, String? b) {
    if (a == null || a.isEmpty) {
      return (b == null || b.isEmpty) ? 0 : 1;
    }
    if (b == null || b.isEmpty) return -1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    _books = await _db.getAllBooks();
    _categories = await _db.getAllCategories();
    _bookCategoryLinks = await _db.getAllBookCategoryLinks();
    _categoryNamesByBookId = _computeCategoryNamesByBookId();
    _primaryCategoryByBookId = {
      for (final entry in _categoryNamesByBookId.entries)
        entry.key: entry.value.isEmpty ? null : entry.value.first,
    };
    _aliasGroups = await _db.getAllNameAliasGroups();
    _aliasIndex = NameAliasIndex(_aliasGroups);
    _stampsByBook = _groupByBookId(await _db.getAllStamps(), (s) => s.bookId);
    _coverPresetsByBook = _groupByBookId(
      await _db.getAllCoverPresets(),
      (p) => p.bookId,
    );
    _pagesByBook = _groupByBookId(
      await _db.getAllBookPages(),
      (p) => p.bookId,
    );
    _viewMode = await _settings.getLibraryViewMode();
    _sortField = await _settings.getLibrarySortField();
    _appLocale = await _settings.getAppLocale();
    _appThemeMode = await _settings.getAppThemeMode();
    _loading = false;
    notifyListeners();
  }

  /// Every book's linked category names, alphabetically ordered — read by
  /// the search matcher (a category name is one of the fields a name-alias
  /// set can stand in for) and by the sort tie-breaker, which uses the
  /// first name of each list as the book's "primary" category (see
  /// [_compareSecondaryFields]).
  Map<int, List<String>> _computeCategoryNamesByBookId() {
    final categoryNameById = {
      for (final category in _categories) category.id!: category.name,
    };
    final result = <int, List<String>>{};
    for (final entry in _bookCategoryLinks.entries) {
      result[entry.key] = entry.value
          .map((id) => categoryNameById[id])
          .whereType<String>()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return result;
  }

  Map<int, List<T>> _groupByBookId<T>(
    List<T> items,
    int Function(T) bookIdOf,
  ) {
    final map = <int, List<T>>{};
    for (final item in items) {
      map.putIfAbsent(bookIdOf(item), () => []).add(item);
    }
    return map;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(LibraryStatusFilter? filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void setCategoryFilter(int? categoryId) {
    _categoryFilterId = categoryId;
    notifyListeners();
  }

  Future<void> setViewMode(LibraryViewMode mode) async {
    _viewMode = mode;
    notifyListeners();
    await _settings.setLibraryViewMode(mode);
  }

  /// Advances the single view-toggle button to the next mode in its cycle
  /// (list -> shelf covers -> shelf spines -> list).
  Future<void> cycleViewMode() => setViewMode(_viewMode.next);

  Future<void> setSortField(LibrarySortField field) async {
    _sortField = field;
    notifyListeners();
    await _settings.setLibrarySortField(field);
  }

  Future<void> setAppLocale(AppLocale locale) async {
    _appLocale = locale;
    notifyListeners();
    await _settings.setAppLocale(locale);
  }

  Future<void> setAppThemeMode(AppThemeMode mode) async {
    _appThemeMode = mode;
    notifyListeners();
    await _settings.setAppThemeMode(mode);
  }

  Future<Book?> findByIsbn(String isbn13) => _db.findByIsbn(isbn13);

  /// Adds [book], pre-seeding it with a front-only cover preset from its
  /// API thumbnail (if any) so it renders on the visual shelf right away
  /// instead of falling back to the text info tile until the user manually
  /// scans a cover.
  Future<int> addBook(Book book, {List<int> categoryIds = const []}) async {
    final id = await _db.insertBook(book);
    if (categoryIds.isNotEmpty) {
      await _db.setBookCategories(id, categoryIds);
    }
    final thumbnailUrl = book.thumbnailUrl;
    if (thumbnailUrl != null) {
      final presetId = await _db.insertCoverPreset(
        BookCoverPreset(
          bookId: id,
          frontImagePath: thumbnailUrl,
          createdAt: DateTime.now(),
        ),
      );
      await _db.setActiveCoverPreset(id, presetId);
    }
    await loadAll();
    return id;
  }

  Future<void> updateBook(Book book, {List<int>? categoryIds}) async {
    await _db.updateBook(book);
    if (categoryIds != null && book.id != null) {
      await _db.setBookCategories(book.id!, categoryIds);
    }
    await loadAll();
  }

  Future<void> deleteBook(int id) async {
    await _db.deleteBook(id);
    await loadAll();
  }

  Future<void> setBookCategories(int bookId, List<int> categoryIds) async {
    await _db.setBookCategories(bookId, categoryIds);
    await loadAll();
  }

  Future<int> addCategory(String name) async {
    final id = await _db.insertCategory(BookCategory(name: name));
    await loadAll();
    return id;
  }

  Future<void> renameCategory(BookCategory category, String newName) async {
    await _db.updateCategory(category.copyWith(name: newName));
    await loadAll();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    if (_categoryFilterId == id) _categoryFilterId = null;
    await loadAll();
  }

  // ---------------------------------------------------------------------
  // Name alias groups
  // ---------------------------------------------------------------------

  /// Saves a new set of equivalent names. [terms] is sanitized first
  /// (trimmed, de-duplicated case-insensitively); a set that ends up empty
  /// isn't saved at all and returns null.
  Future<int?> addAliasGroup(Iterable<String> terms) async {
    final sanitized = NameAliasGroup.sanitizeTerms(terms);
    if (sanitized.isEmpty) return null;
    final id = await _db.insertNameAliasGroup(NameAliasGroup(terms: sanitized));
    await loadAll();
    return id;
  }

  /// Replaces [group]'s names with [terms]. Clearing every name deletes
  /// the set rather than leaving an empty one behind.
  Future<void> updateAliasGroup(
    NameAliasGroup group,
    Iterable<String> terms,
  ) async {
    final sanitized = NameAliasGroup.sanitizeTerms(terms);
    if (sanitized.isEmpty) {
      if (group.id != null) await deleteAliasGroup(group.id!);
      return;
    }
    await _db.updateNameAliasGroup(group.copyWith(terms: sanitized));
    await loadAll();
  }

  Future<void> deleteAliasGroup(int id) async {
    await _db.deleteNameAliasGroup(id);
    await loadAll();
  }

  /// Combines every set in [ids] into one, keeping the first id and
  /// deleting the rest. Fewer than two ids is a no-op.
  Future<void> mergeAliasGroups(List<int> ids) async {
    if (ids.length < 2) return;
    final groups = [
      for (final id in ids) _aliasGroups.firstWhere((group) => group.id == id),
    ];
    final keep = groups.first;
    await _db.updateNameAliasGroup(
      keep.copyWith(terms: NameAliasGroup.merged(groups)),
    );
    for (final group in groups.skip(1)) {
      await _db.deleteNameAliasGroup(group.id!);
    }
    await loadAll();
  }

  /// Pulls [namesToExtract] out of [group] into a brand-new set of their
  /// own — the repair for a set that turned out to bundle names that
  /// don't actually mean the same thing. A no-op if nothing would be left
  /// on either side.
  Future<void> splitAliasGroup(
    NameAliasGroup group,
    List<String> namesToExtract,
  ) async {
    if (group.id == null) return;
    final (remaining, extracted) =
        NameAliasGroup.split(group.terms, namesToExtract);
    if (remaining.isEmpty || extracted.isEmpty) return;
    await _db.updateNameAliasGroup(group.copyWith(terms: remaining));
    await _db.insertNameAliasGroup(NameAliasGroup(terms: extracted));
    await loadAll();
  }

  // ---------------------------------------------------------------------
  // Reading stamps
  // ---------------------------------------------------------------------

  Future<void> addStamp(
    int bookId,
    StampType type, {
    DateTime? timestamp,
    String? note,
  }) async {
    await _db.insertStamp(
      ReadingStamp(
        bookId: bookId,
        type: type,
        timestamp: timestamp ?? DateTime.now(),
        note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      ),
    );
    await loadAll();
  }

  Future<void> updateStamp(ReadingStamp stamp) async {
    await _db.updateStamp(stamp);
    await loadAll();
  }

  Future<void> deleteStamp(int stampId) async {
    await _db.deleteStamp(stampId);
    await loadAll();
  }

  // ---------------------------------------------------------------------
  // Cover presets
  // ---------------------------------------------------------------------

  /// Saves a new preset. It becomes the book's active shelf image if it's
  /// the book's first preset, or if the caller explicitly marks it active.
  Future<int> addCoverPreset(BookCoverPreset preset) async {
    final id = await _db.insertCoverPreset(preset);
    final isFirstForBook = coverPresetsFor(preset.bookId).isEmpty;
    if (isFirstForBook || preset.isActive) {
      await _db.setActiveCoverPreset(preset.bookId, id);
    }
    await loadAll();
    return id;
  }

  Future<void> setActiveCoverPreset(int bookId, int presetId) async {
    await _db.setActiveCoverPreset(bookId, presetId);
    await loadAll();
  }

  /// Overwrites an existing preset in place — used when the user comes
  /// back to fill in a slot (front/spine/back) they skipped earlier, or
  /// replaces/removes one that's already there. Which local image files
  /// need saving or deleting is worked out by the caller (the cover scan
  /// screen), since only it knows what actually changed.
  Future<void> updateCoverPreset(BookCoverPreset preset) async {
    await _db.updateCoverPreset(preset);
    await loadAll();
  }

  Future<void> renameCoverPreset(BookCoverPreset preset, String? label) async {
    final trimmed = label?.trim();
    await _db.updateCoverPreset(
      preset.copyWith(
        label: trimmed,
        clearLabel: trimmed == null || trimmed.isEmpty,
      ),
    );
    await loadAll();
  }

  Future<void> deleteCoverPreset(BookCoverPreset preset) async {
    await _db.deleteCoverPreset(preset.id!);
    await ImageStorageService.instance.deleteFile(preset.frontImagePath);
    await ImageStorageService.instance.deleteFile(preset.spineImagePath);
    await ImageStorageService.instance.deleteFile(preset.backImagePath);

    if (preset.isActive) {
      final remaining = coverPresetsFor(
        preset.bookId,
      ).where((p) => p.id != preset.id).toList();
      if (remaining.isNotEmpty) {
        await _db.setActiveCoverPreset(preset.bookId, remaining.first.id!);
      }
    }
    await loadAll();
  }

  // ---------------------------------------------------------------------
  // Saved pages
  // ---------------------------------------------------------------------

  Future<int> addBookPage(BookPage page) async {
    final id = await _db.insertBookPage(page);
    await loadAll();
    return id;
  }

  Future<void> updateBookPage(BookPage page) async {
    await _db.updateBookPage(page);
    await loadAll();
  }

  Future<void> deleteBookPage(BookPage page) async {
    await _db.deleteBookPage(page.id!);
    await ImageStorageService.instance.deleteFile(page.imagePath);
    await loadAll();
  }
}
