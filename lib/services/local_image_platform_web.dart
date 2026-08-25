import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'database_service.dart';
import 'image_path_utils.dart';

const _keyPrefix = 'webimg://';

/// Web has no filesystem, so a "saved" image is just its bytes persisted in
/// the [DatabaseService]'s `local_images` table (itself backed by the
/// browser's IndexedDB), keyed by a synthetic `webimg://` path that stands
/// in for the file path a native save would have returned.
Future<String> saveLocalImage(XFile file, String subfolder, int bookId) async {
  final bytes = await file.readAsBytes();
  final key =
      '$_keyPrefix$subfolder/${bookId}_${DateTime.now().microsecondsSinceEpoch}';
  await DatabaseService.instance.putLocalImage(key, bytes);
  return key;
}

/// Persists raw [bytes] under a fresh `webimg://` key, the same way
/// [saveLocalImage] does for a picker [XFile] -- used to restore a
/// cover/page photo from a backup archive, where the image only exists as
/// raw bytes. [extension] is unused here (the `local_images` table is keyed
/// by path, not filename) but kept so this matches the native signature.
Future<String> saveLocalImageBytes(
  Uint8List bytes,
  String subfolder,
  int bookId,
  String extension,
) async {
  final key =
      '$_keyPrefix$subfolder/${bookId}_${DateTime.now().microsecondsSinceEpoch}';
  await DatabaseService.instance.putLocalImage(key, bytes);
  return key;
}

/// Reads a locally-saved image's bytes back, or null if [path] is a remote
/// URL or not a `webimg://` key -- used when exporting a backup archive.
Future<Uint8List?> readLocalImageBytes(String path) async {
  if (isRemoteImagePath(path)) return null;
  if (!path.startsWith(_keyPrefix)) return null;
  return DatabaseService.instance.getLocalImage(path);
}

/// Deletes a locally-saved image's bytes. A no-op for `null`, remote paths,
/// and paths that were never a `webimg://` key (nothing else is ours to
/// delete on web).
Future<void> deleteLocalImage(String? path) async {
  if (path == null) return;
  if (isRemoteImagePath(path)) return;
  if (!path.startsWith(_keyPrefix)) return;
  await DatabaseService.instance.deleteLocalImage(path);
}
