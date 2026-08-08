import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/message_model.dart';
import '../../theme/theme.dart';
import '../common/glass_container.dart';
import 'emoji_picker_sheet.dart';

/// The glass composer pinned to the bottom of [ChatScreen].
///
/// Swaps its trailing action between a mic button (empty field) and a send
/// button (non-empty field) the way Telegram/iMessage do, and renders an
/// optional reply-preview strip above the field when [replyTarget] is set.
/// Kept purely presentational — all persistence (typing pings, actually
/// sending) is delegated to the callbacks so [ChatScreen] stays the single
/// place that talks to [ChatProvider].
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.onSendText,
    required this.onChanged,
    required this.onAttachPressed,
    required this.onCameraPressed,
    this.onStartVoiceRecording,
    this.onCancelVoiceRecording,
    this.onFinishVoiceRecording,
    this.replyTarget,
    this.onCancelReply,
  });

  final ValueChanged<String> onSendText;
  final ValueChanged<String> onChanged;
  final VoidCallback onAttachPressed;
  final VoidCallback onCameraPressed;

  /// Starts recording. Returns false (without entering recording UI) if
  /// e.g. microphone permission was denied.
  final Future<bool> Function()? onStartVoiceRecording;
  final Future<void> Function()? onCancelVoiceRecording;
  final Future<void> Function()? onFinishVoiceRecording;
  final MessageModel? replyTarget;
  final VoidCallback? onCancelReply;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _isRecording = false;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final bool hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
      widget.onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _send() {
    final String text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
  }

  Future<void> _startRecording() async {
    final bool started = await widget.onStartVoiceRecording?.call() ?? false;
    if (!started || !mounted) return;
    setState(() {
      _isRecording = true;
      _recordingElapsed = Duration.zero;
    });
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _recordingElapsed += const Duration(milliseconds: 200);
      });
      // Auto-stop at the max voice message length so a forgotten held
      // finger doesn't record indefinitely.
      if (_recordingElapsed.inSeconds >= AppConstants.maxVoiceMessageSeconds) {
        _finishRecording();
      }
    });
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
    await widget.onCancelVoiceRecording?.call();
  }

  Future<void> _finishRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
    await widget.onFinishVoiceRecording?.call();
  }

  void _insertEmoji(String emoji) {
    final TextSelection selection = _controller.selection;
    final String text = _controller.text;

    // If the field has no valid cursor position (e.g. it never had focus),
    // fall back to appending at the end rather than losing the tap.
    final int insertAt =
        selection.isValid ? selection.start : text.length;
    final int removeEnd =
        selection.isValid ? selection.end : text.length;

    final String newText =
        text.replaceRange(insertAt, removeEnd, emoji);
    final int newOffset = insertAt + emoji.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    widget.onChanged(newText);
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _showEmojiPicker() {
    FocusScope.of(context).unfocus();
    showGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => EmojiPickerSheet(onSelected: _insertEmoji),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.xs,
          AppDimens.md,
          AppDimens.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.replyTarget != null)
              _ReplyStrip(
                message: widget.replyTarget!,
                onCancel: widget.onCancelReply,
              ),
            GlassContainer(
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              blurSigma: AppConstants.glassBlurSigma,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.xs,
                vertical: AppDimens.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    tooltip: 'Attach',
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(),
                    splashRadius: 22,
                    onPressed: widget.onAttachPressed,
                  ),
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    tooltip: 'Emoji',
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(),
                    splashRadius: 22,
                    onPressed: _showEmojiPicker,
                  ),
                  Expanded(
                    child: _isRecording
                        ? _RecordingIndicator(elapsed: _recordingElapsed)
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Message',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                  ),
                  if (!_isRecording)
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined),
                      tooltip: 'Camera',
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                      onPressed: widget.onCameraPressed,
                    ),
                  _TrailingAction(
                    hasText: _hasText,
                    isRecording: _isRecording,
                    onSend: _send,
                    onStartRecording: _startRecording,
                    onCancelRecording: _cancelRecording,
                    onFinishRecording: _finishRecording,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the text field while recording: a pulsing red dot, an
/// elapsed-time readout (tabular figures so it doesn't jitter the layout
/// as digits change), and a "Slide to cancel" hint — the same shape as
/// Telegram/WhatsApp's in-composer recording state.
class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator({required this.elapsed});

  final Duration elapsed;

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final int totalSeconds = widget.elapsed.inSeconds;
    final String minutes = (totalSeconds ~/ 60).toString();
    final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulseController.drive(
              Tween<double>(begin: 1, end: 0.25),
            ),
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeLabel,
            style: TextStyle(
              fontSize: 16,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Slide to cancel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailingAction extends StatelessWidget {
  const _TrailingAction({
    required this.hasText,
    required this.isRecording,
    required this.onSend,
    required this.onStartRecording,
    required this.onCancelRecording,
    required this.onFinishRecording,
  });

  final bool hasText;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onStartRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onFinishRecording;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    if (isRecording) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: AppColors.error,
            onPressed: onCancelRecording,
          ),
          _RoundActionButton(
            icon: Icons.check_rounded,
            color: accent,
            onPressed: onFinishRecording,
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: AppConstants.animFast,
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: hasText
          ? _RoundActionButton(
              key: const ValueKey('send'),
              icon: Icons.arrow_upward_rounded,
              color: accent,
              onPressed: onSend,
            )
          : _RoundActionButton(
              key: const ValueKey('mic'),
              icon: Icons.mic_none_rounded,
              color: accent,
              onLongPressStart: (_) => onStartRecording(),
              onLongPressEnd: (_) => onFinishRecording(),
              onPressed: onStartRecording,
            ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final void Function(LongPressStartDetails)? onLongPressStart;
  final void Function(LongPressEndDetails)? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ReplyStrip extends StatelessWidget {
  const _ReplyStrip({required this.message, this.onCancel});

  final MessageModel message;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                Text(
                  _previewFor(message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onCancel,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _previewFor(MessageModel m) {
    switch (m.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.file:
        return '📎 ${m.fileName ?? 'File'}';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.text:
      case MessageType.system:
        return m.text;
    }
  }
}
