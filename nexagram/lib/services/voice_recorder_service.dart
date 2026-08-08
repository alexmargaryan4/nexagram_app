import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Result of a finished voice recording: the encoded audio file on disk
/// plus its duration.
class VoiceRecording {
  const VoiceRecording({required this.file, required this.duration});

  final File file;
  final Duration duration;
}

/// Thin wrapper around [AudioRecorder] (the `record` package) that owns
/// the recording lifecycle for the chat composer's mic button.
///
/// Records to a temporary `.m4a` (AAC) file — small enough to upload
/// quickly and playable by [AudioPlayer]/most native players on both
/// platforms, matching what [StorageService.uploadVoiceMessage] expects
/// (`audio/m4a`).
class VoiceRecorderService {
  VoiceRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentPath;
  DateTime? _startedAt;

  bool get isRecording => _startedAt != null;

  /// Live amplitude stream (decibels, roughly -45..0), used to animate the
  /// composer's waveform while recording. Emits null before recording
  /// starts / after it stops.
  Stream<double> get onAmplitude => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      .map((a) => a.current);

  /// Requests the microphone permission and starts recording. Returns
  /// false (without starting) if permission is denied.
  Future<bool> start() async {
    final bool granted = await _recorder.hasPermission();
    if (!granted) return false;

    final Directory dir = await getTemporaryDirectory();
    final String path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _currentPath = path;
    _startedAt = DateTime.now();
    return true;
  }

  /// Stops recording and returns the resulting file + duration, or null
  /// if nothing was recorded (e.g. stopped immediately, or never started).
  Future<VoiceRecording?> stop() async {
    final DateTime? startedAt = _startedAt;
    final String? path = await _recorder.stop();
    final Duration duration =
        startedAt != null ? DateTime.now().difference(startedAt) : Duration.zero;
    _startedAt = null;
    _currentPath = null;

    if (path == null) return null;
    final File file = File(path);
    if (!await file.exists()) return null;
    // Guard against near-zero taps: treat as a cancel rather than a
    // valid (silent, empty-sounding) voice message.
    if (duration < const Duration(milliseconds: 400)) {
      unawaited(file.delete().catchError((_) => file));
      return null;
    }
    return VoiceRecording(file: file, duration: duration);
  }

  /// Stops recording (if any) and discards the file — used when the user
  /// cancels via the composer's "x" button.
  Future<void> cancel() async {
    final String? path = _currentPath;
    _startedAt = null;
    _currentPath = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // Already stopped/never started — nothing to clean up.
    }
    if (path != null) {
      final File file = File(path);
      if (await file.exists()) {
        unawaited(file.delete().catchError((_) => file));
      }
    }
  }

  Duration get elapsed =>
      _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  void dispose() {
    _recorder.dispose();
  }
}
