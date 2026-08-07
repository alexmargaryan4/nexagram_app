import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

/// Uploads avatars and chat media (images, files, voice notes) to
/// Firebase Storage and returns their public download URLs.
///
/// All paths are centralised in [StoragePaths] so the bucket layout stays
/// consistent with the security rules in `docs/storage.rules`.
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadAvatar(String uid, File file) async {
    _assertSize(file, AppConstants.maxImageSizeBytes, 'Avatar');
    return _upload(
      path: StoragePaths.avatar(uid),
      file: file,
      contentType: 'image/jpeg',
    );
  }

  Future<String> uploadChatImage(
    String chatId,
    String fileName,
    File file,
  ) async {
    _assertSize(file, AppConstants.maxImageSizeBytes, 'Image');
    return _upload(
      path: StoragePaths.chatImage(chatId, fileName),
      file: file,
      contentType: 'image/jpeg',
    );
  }

  Future<String> uploadChatFile(
    String chatId,
    String fileName,
    File file, {
    String contentType = 'application/octet-stream',
  }) async {
    _assertSize(file, AppConstants.maxFileSizeBytes, 'File');
    return _upload(
      path: StoragePaths.chatFile(chatId, fileName),
      file: file,
      contentType: contentType,
    );
  }

  Future<String> uploadVoiceMessage(
    String chatId,
    String fileName,
    File file,
  ) async {
    _assertSize(file, AppConstants.maxFileSizeBytes, 'Voice message');
    return _upload(
      path: StoragePaths.chatVoice(chatId, fileName),
      file: file,
      contentType: 'audio/m4a',
    );
  }

  Future<String> _upload({
    required String path,
    required File file,
    required String contentType,
  }) async {
    try {
      final Reference ref = _storage.ref(path);
      final UploadTask task = ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      final TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw StorageException(
        e.message ?? 'Upload failed. Please try again.',
        code: e.code,
      );
    }
  }

  Future<void> deleteAtUrl(String downloadUrl) async {
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } catch (_) {
      // Best-effort cleanup; a missing/already-deleted object isn't fatal.
    }
  }

  void _assertSize(File file, int maxBytes, String label) {
    final int size = file.lengthSync();
    if (size > maxBytes) {
      final double maxMb = maxBytes / (1024 * 1024);
      throw ValidationException(
        '$label is too large. Maximum size is ${maxMb.toStringAsFixed(0)} MB.',
      );
    }
  }

  /// Upload progress stream, useful for showing a progress bar on large
  /// files. Returns (bytesTransferred, totalBytes) pairs.
  Stream<(int, int)> uploadWithProgress({
    required String path,
    required File file,
    required String contentType,
  }) {
    final Reference ref = _storage.ref(path);
    final UploadTask task = ref.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );
    return task.snapshotEvents.map(
      (event) => (event.bytesTransferred, event.totalBytes),
    );
  }
}
