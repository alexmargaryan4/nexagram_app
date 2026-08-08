import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../supabase_options.dart';

/// Uploads avatars and chat media (images, files, voice notes) to
/// Supabase Storage and returns their public download URLs.
///
/// The whole backend — Auth, database, Storage, and Realtime — now runs
/// on Supabase; there is no Firebase project involved anywhere in the app.
///
/// All paths are centralised in [StoragePaths] so the bucket layout stays
/// consistent with the Storage policies configured in the Supabase
/// dashboard (see `supabase_storage_policy.sql` and README.md).
class StorageService {
  StorageService({sb.SupabaseStorageClient? storage})
      : _storage = storage ?? sb.Supabase.instance.client.storage;

  final sb.SupabaseStorageClient _storage;

  sb.StorageFileApi get _bucket => _storage.from(SupabaseConfig.bucket);

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
      await _bucket.upload(
        path,
        file,
        fileOptions: sb.FileOptions(contentType: contentType, upsert: true),
      );
      return _bucket.getPublicUrl(path);
    } on sb.StorageException catch (e) {
      throw StorageException(e.message, code: e.statusCode);
    }
  }

  /// Deletes the object at [downloadUrl]. Accepts a full public URL (as
  /// returned by the upload methods above) or a bare storage path.
  Future<void> deleteAtUrl(String downloadUrl) async {
    try {
      final String path = _pathFromUrl(downloadUrl);
      await _bucket.remove([path]);
    } catch (_) {
      // Best-effort cleanup; a missing/already-deleted object isn't fatal.
    }
  }

  /// Supabase public URLs look like
  /// `.../storage/v1/object/public/<bucket>/<path>` — this pulls just the
  /// `<path>` part back out so it can be passed to `remove()`.
  String _pathFromUrl(String downloadUrl) {
    final String marker = '/object/public/${SupabaseConfig.bucket}/';
    final int index = downloadUrl.indexOf(marker);
    if (index == -1) return downloadUrl;
    return Uri.decodeComponent(downloadUrl.substring(index + marker.length));
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
  ///
  /// Note: the installed supabase_flutter version's `upload()` doesn't
  /// expose a progress callback, so this can only report a single
  /// (fileSize, fileSize) event once the upload completes rather than
  /// incremental progress — unlike Firebase's resumable upload task.
  Stream<(int, int)> uploadWithProgress({
    required String path,
    required File file,
    required String contentType,
  }) {
    final controller = StreamController<(int, int)>();
    final int totalBytes = file.lengthSync();
    _bucket
        .upload(
          path,
          file,
          fileOptions: sb.FileOptions(contentType: contentType, upsert: true),
        )
        .then((_) {
          controller.add((totalBytes, totalBytes));
          controller.close();
        })
        .catchError((Object e) => controller.addError(e));
    return controller.stream;
  }
}
