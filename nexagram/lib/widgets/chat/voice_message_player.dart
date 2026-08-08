import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/utils/date_formatter.dart';

/// Play/pause voice-message widget shown inside a chat bubble.
///
/// A tappable circular play button sits beside a waveform that fills in
/// (accent color) up to the current playback position — tapping anywhere
/// on the waveform seeks. The displayed time switches from the total
/// duration to the elapsed position once playback starts, iMessage/
/// Telegram-style, so the bubble stays useful both before and during
/// playback.
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.sourceUrl,
    required this.totalDuration,
    required this.color,
    this.isMe = false,
  });

  /// Remote URL (already-uploaded voice notes) or a local file path.
  final String sourceUrl;
  final Duration totalDuration;
  final Color color;
  final bool isMe;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  static final List<double> _barHeights = List.generate(
    28,
    (i) => 0.28 + 0.72 * (math.sin(i * 1.7) * 0.5 + 0.5) * ((i % 3 == 0) ? 1 : 0.65),
  );

  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _knownDuration;
  bool _isLoading = false;

  Duration get _duration => _knownDuration ?? widget.totalDuration;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
    _positionSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _state = PlayerState.stopped;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final bool isRemote = widget.sourceUrl.startsWith('http');
      await _player.play(
        isRemote ? UrlSource(widget.sourceUrl) : DeviceFileSource(widget.sourceUrl),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seekToFraction(double fraction) {
    final Duration total = _duration;
    if (total == Duration.zero) return;
    final Duration target = total * fraction.clamp(0.0, 1.0);
    _player.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = _state == PlayerState.playing;
    final double progress = _duration.inMilliseconds == 0
        ? 0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    final String timeLabel = (isPlaying || _position > Duration.zero)
        ? DateFormatter.voiceDuration(_position.inMilliseconds)
        : DateFormatter.voiceDuration(_duration.inMilliseconds);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayButton(
          isPlaying: isPlaying,
          isLoading: _isLoading,
          color: widget.color,
          onTap: _togglePlay,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final double dx = details.localPosition.dx;
                _seekToFraction(dx / 132);
              },
              onHorizontalDragUpdate: (details) {
                final double dx = details.localPosition.dx;
                _seekToFraction(dx / 132);
              },
              child: SizedBox(
                width: 132,
                height: 24,
                child: CustomPaint(
                  painter: _WaveformProgressPainter(
                    heights: _barHeights,
                    progress: progress,
                    trackColor: widget.color.withOpacity(0.28),
                    fillColor: widget.color,
                  ),
                  size: const Size(132, 24),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              timeLabel,
              style: TextStyle(
                color: widget.color.withOpacity(0.7),
                fontSize: 11.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.color,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(9),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(isPlaying),
                    color: color,
                    size: 20,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Paints a static waveform where bars up to [progress] are filled with
/// [fillColor] and the remainder with [trackColor] — the classic
/// WhatsApp/Telegram "waveform scrubber" look, without needing real
/// decoded audio amplitude data.
class _WaveformProgressPainter extends CustomPainter {
  _WaveformProgressPainter({
    required this.heights,
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  final List<double> heights;
  final double progress;
  final Color trackColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double gap = size.width / heights.length;
    final double barWidth = gap * 0.55;
    final double progressX = size.width * progress;

    for (int i = 0; i < heights.length; i++) {
      final double x = i * gap + gap / 2;
      final double h = size.height * heights[i];
      final bool filled = x <= progressX;
      final Paint paint = Paint()
        ..color = filled ? fillColor : trackColor
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.trackColor != trackColor;
}
