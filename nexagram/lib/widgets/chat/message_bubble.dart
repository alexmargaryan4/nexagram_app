import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/message_model.dart';
import '../../theme/theme.dart';
import 'voice_message_player.dart';

/// Renders a single [MessageModel] as a chat bubble.
///
/// Handles all four visible message types (text/image/file/voice),
/// reply-preview headers, reaction chips, edited/read/delivered status,
/// and the tail-side alignment difference between outgoing and incoming
/// messages. Deleted messages collapse to a muted placeholder rather than
/// disappearing, matching Telegram's "This message was deleted" pattern.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUid,
    this.isGroupChat = false,
    this.senderName,
    this.showTail = true,
    this.onLongPress,
    this.onReplyTap,
    this.onReactionTap,
  });

  final MessageModel message;
  final bool isMe;
  final String currentUid;
  final bool isGroupChat;
  final String? senderName;
  final bool showTail;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bubbleColor = isMe
        ? (isDark ? AppColors.darkOutgoingBubble : AppColors.lightOutgoingBubble)
        : (isDark ? AppColors.darkIncomingBubble : AppColors.lightIncomingBubble);
    final Color textColor = isMe
        ? Colors.white
        : (isDark ? AppColors.darkText : AppColors.lightText);

    if (message.isDeleted) {
      return _DeletedBubble(isMe: isMe, isDark: isDark);
    }

    if (message.type == MessageType.system) {
      return _SystemMessageChip(message: message, currentUid: currentUid);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width *
                AppDimens.chatBubbleMaxWidthFraction,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: _bubbleRadius(),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: _paddingFor(message.type),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isGroupChat && !isMe && senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderName!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.avatarGradientFor(senderName!).first,
                          ),
                        ),
                      ),
                    if (message.replyToMessageId != null)
                      _ReplyPreview(
                        message: message,
                        isMe: isMe,
                        onTap: onReplyTap,
                      ),
                    _MessageContent(message: message, isMe: isMe, textColor: textColor),
                    const SizedBox(height: 2),
                    _MessageMeta(message: message, isMe: isMe, textColor: textColor),
                  ],
                ),
              ),
              if (message.hasReactions)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _ReactionRow(
                    message: message,
                    onReactionTap: onReactionTap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets _paddingFor(MessageType type) {
    switch (type) {
      case MessageType.image:
        return const EdgeInsets.all(6);
      case MessageType.text:
      case MessageType.file:
      case MessageType.voice:
      case MessageType.system:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    }
  }

  BorderRadius _bubbleRadius() {
    const double r = AppDimens.radiusLarge;
    const double tail = 6;
    return BorderRadius.only(
      topLeft: const Radius.circular(r),
      topRight: const Radius.circular(r),
      bottomLeft: Radius.circular(isMe || !showTail ? r : tail),
      bottomRight: Radius.circular(isMe && showTail ? tail : r),
    );
  }
}

class _DeletedBubble extends StatelessWidget {
  const _DeletedBubble({required this.isMe, required this.isDark});

  final bool isMe;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded,
                size: 15,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText),
            const SizedBox(width: 6),
            Text(
              'This message was deleted',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered, pill-shaped chip for [MessageType.system] events (currently:
/// "member added to group"). Decodes [message.text] per-viewer via
/// [SystemMessageCodec] so the person who was just added sees "{who} added
/// you", while everyone else sees "{who} joined" — falls back to showing
/// the raw text as-is if it isn't a recognized encoded payload (e.g. an
/// older plain-text system message).
class _SystemMessageChip extends StatelessWidget {
  const _SystemMessageChip({required this.message, required this.currentUid});

  final MessageModel message;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final String text =
        SystemMessageCodec.displayTextFor(message.text, currentUid);

    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.isMe, this.onTap});

  final MessageModel message;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color barColor = isMe ? Colors.white : AppColors.lightAccent;
    final Color textColor = isMe ? Colors.white : AppColors.lightAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: (isMe ? Colors.white : Colors.black).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3, decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.replyToSenderName ?? 'Message',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      message.replyToPreview ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: (isMe ? Colors.white : Colors.black87)
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.isMe,
    required this.textColor,
  });

  final MessageModel message;
  final bool isMe;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
      case MessageType.system:
        return Text(
          message.text,
          style: TextStyle(fontSize: 16, color: textColor, height: 1.3),
        );
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, minWidth: 160),
            child: CachedNetworkImage(
              imageUrl: message.mediaUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.black12,
                height: 180,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black12,
                height: 180,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        );
      case MessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.insert_drive_file_rounded,
                  color: textColor, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.fileName ?? 'File',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    DateFormatter.fileSize(message.fileSizeBytes),
                    style: TextStyle(
                        color: textColor.withOpacity(0.7), fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        );
      case MessageType.voice:
        return VoiceMessagePlayer(
          sourceUrl: message.mediaUrl ?? '',
          totalDuration: Duration(milliseconds: message.voiceDurationMs ?? 0),
          color: textColor,
          isMe: isMe,
        );
    }
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.message,
    required this.isMe,
    required this.textColor,
  });

  final MessageModel message;
  final bool isMe;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final Color metaColor = textColor.withOpacity(0.65);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.editedAt != null) ...[
          Text('edited', style: TextStyle(fontSize: 11, color: metaColor)),
          const SizedBox(width: 4),
        ],
        Text(
          DateFormatter.messageTime(message.createdAt),
          style: TextStyle(fontSize: 11, color: metaColor),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            message.readBy.length > 1 ? Icons.done_all_rounded : Icons.done_rounded,
            size: 15,
            color: message.readBy.length > 1
                ? Colors.white
                : metaColor,
          ),
        ],
      ],
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.message, this.onReactionTap});

  final MessageModel message;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = message.reactions.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: entries.map((e) {
        return GestureDetector(
          onTap: () => onReactionTap?.call(e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              border: Border.all(
                color: isDark ? AppColors.darkGlassBorder : AppColors.lightDivider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 13)),
                if (e.value.length > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '${e.value.length}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
