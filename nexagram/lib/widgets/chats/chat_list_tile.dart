import 'package:flutter/material.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../theme/theme.dart';
import '../common/user_avatar.dart';

/// A single row in the chat list: avatar, title, last-message preview,
/// timestamp, unread badge, and mute/pin indicators.
///
/// Takes fully-resolved display data (title/subtitle/avatar) rather than
/// a raw [ChatModel] plus a lookup, so the same tile can render both
/// private chats (title = other participant's name) and group chats
/// (title = group name) without branching inside the widget itself.
class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    required this.currentUid,
    required this.title,
    this.avatarUrl,
    this.avatarSeed,
    this.isOnline = false,
    this.onTap,
    this.onLongPress,
  });

  final ChatModel chat;
  final String currentUid;
  final String title;
  final String? avatarUrl;
  final String? avatarSeed;
  final bool isOnline;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int unread = chat.unreadCountFor(currentUid);
    final bool isMuted = chat.isMutedBy(currentUid);
    final bool isPinned = chat.isPinnedBy(currentUid);
    final bool isUnread = unread > 0;

    final String initials = title.trim().isNotEmpty
        ? title.trim().substring(0, 1).toUpperCase()
        : '?';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.sm,
        ),
        child: Row(
          children: [
            UserAvatar(
              seed: avatarSeed ?? chat.id,
              avatarUrl: avatarUrl,
              initials: initials,
              radius: AppDimens.avatarRadiusMedium,
              showOnlineDot: chat.type == ChatType.private,
              isOnline: isOnline,
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPinned) ...[
                        Icon(
                          Icons.push_pin_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.chatListName.copyWith(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Text(
                        DateFormatter.chatListTimestamp(chat.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isUnread ? FontWeight.w600 : FontWeight.w400,
                          color: isUnread
                              ? (isDark
                                  ? AppColors.darkAccent
                                  : AppColors.lightAccent)
                              : (isDark
                                  ? AppColors.darkSecondaryText
                                  : AppColors.lightSecondaryText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (chat.lastMessageSenderId == currentUid)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.done_all_rounded,
                            size: 15,
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          chat.lastMessage?.isNotEmpty == true
                              ? chat.lastMessage!
                              : 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.chatListPreview(
                            isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      if (isMuted)
                        Icon(
                          Icons.notifications_off_rounded,
                          size: 15,
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText,
                        ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        _UnreadBadge(count: unread, muted: isMuted),
                      ],
                    ],
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.muted});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: muted ? AppColors.lightSecondaryText : AppColors.lightAccent,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
