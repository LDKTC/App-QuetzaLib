import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'image_path_utils.dart';

/// Copies [file] into the app's local documents directory (under
/// `covers/` or `pages/`) so it persists independently of the picker's
/// often-temporary source file, and returns the saved file's path.
Future<String> saveLocalImage(XFile file, String subfolder, int bookId) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final targetDir = Directory('${docsDir.path}/$subfolder');
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }
  final filename =
      '${bookId}_${DateTime.now().microsecondsSinceEpoch}${_extensionOf(file.name)}';
  final targetPath = '${targetDir.path}/$filename';
  await File(file.path).copy(targetPath);
  return targetPath;
}

String _extensionOf(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot == -1 || dot == filename.length - 1) return '.jpg';
  return filename.substring(dot).toLowerCase();
}

/// Writes [bytes] straight to a local file, the same way [saveLocalImage]
/// does for a picker [XFile] -- used to restore a cover/page photo from a
/// backup archive, where the image only exists as raw bytes.
Future<String> saveLocalImageBytes(
  Uint8List bytes,
  String subfolder,
  int bookId,
  String extension,
) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final targetDir = Directory('${docsDir.path}/$subfolder');
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }
  final filename =
      '${bookId}_${DateTime.now().microsecondsSinceEpoch}$extension';
  final targetPath = '${targetDir.path}/$filename';
  await File(targetPath).writeAsBytes(bytes);
  return targetPath;
}

/// Reads a locally-saved file's bytes back, or null if [path] is a remote
/// URL or no longer exists on disk -- used when exporting a backup archive.
Future<Uint8List?> readLocalImageBytes(String path) async {
  if (isRemoteImagePath(path)) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

/// Deletes a locally-saved file. A no-op for `null` and for remote paths,
/// since those point at the book's original API thumbnail rather than a
/// file this service owns.
Future<void> deleteLocalImage(String? path) async {
  if (path == null) return;
  if (isRemoteImagePath(path)) return;
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
