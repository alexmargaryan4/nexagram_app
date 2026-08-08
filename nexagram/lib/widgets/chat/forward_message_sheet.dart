import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chats_provider.dart';
import '../../services/chat_service.dart';
import '../../theme/theme.dart';
import '../common/glass_container.dart';
import '../common/user_avatar.dart';

/// Bottom sheet used by the message long-press menu's "Forward" action.
///
/// Lists the current user's chats (via a fresh, screen-scoped
/// [ChatsProvider], the same one the main chat list uses) and re-sends the
/// tapped [message]'s content into whichever chat the user picks.
/// Forwarded messages intentionally drop the original's reply-thread and
/// reaction state — they're a fresh message in the destination chat, the
/// same way Telegram/WhatsApp forwards behave.
class ForwardMessageSheet extends StatelessWidget {
  const ForwardMessageSheet({super.key, required this.message});

  final MessageModel message;

  static Future<void> show(BuildContext context, MessageModel message) {
    return showGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ForwardMessageSheet(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = context.read<AuthProvider>().currentUser!.uid;

    return ChangeNotifierProvider<ChatsProvider>(
      create: (_) => ChatsProvider(currentUid: currentUid),
      child: _ForwardSheetBody(message: message, currentUid: currentUid),
    );
  }
}

class _ForwardSheetBody extends StatefulWidget {
  const _ForwardSheetBody({required this.message, required this.currentUid});

  final MessageModel message;
  final String currentUid;

  @override
  State<_ForwardSheetBody> createState() => _ForwardSheetBodyState();
}

class _ForwardSheetBodyState extends State<_ForwardSheetBody> {
  final ChatService _chatService = ChatService();
  final Set<String> _sendingTo = {};
  final Set<String> _sentTo = {};

  Future<void> _forwardTo(ChatModel chat) async {
    if (_sendingTo.contains(chat.id) || _sentTo.contains(chat.id)) return;
    setState(() => _sendingTo.add(chat.id));

    try {
      await _chatService.sendMessage(
        chatId: chat.id,
        senderId: widget.currentUid,
        type: widget.message.type,
        text: widget.message.text,
        mediaUrl: widget.message.mediaUrl,
        mediaThumbUrl: widget.message.mediaThumbUrl,
        fileName: widget.message.fileName,
        fileSizeBytes: widget.message.fileSizeBytes,
        voiceDurationMs: widget.message.voiceDurationMs,
        participantIds: chat.participantIds,
      );
      if (!mounted) return;
      setState(() {
        _sendingTo.remove(chat.id);
        _sentTo.add(chat.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingTo.remove(chat.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not forward the message.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final ChatsProvider provider = context.watch<ChatsProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        0,
        AppDimens.md,
        AppDimens.md,
      ),
      child: SafeArea(
        top: false,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          blurSigma: 22,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                const SizedBox(height: AppDimens.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.md,
                  ),
                  child: Text(
                    'Forward to…',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.sortedChats.isEmpty
                          ? Center(
                              child: Text(
                                'No chats yet.',
                                style: TextStyle(color: muted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: provider.sortedChats.length,
                              itemBuilder: (context, index) {
                                final ChatModel chat =
                                    provider.sortedChats[index];
                                final bool isGroup =
                                    chat.type == ChatType.group;
                                final String title = isGroup
                                    ? (chat.groupName ?? 'Group')
                                    : (provider.participantFor(chat)?.name ??
                                        provider
                                            .participantFor(chat)
                                            ?.username ??
                                        'Chat');
                                final bool isSending =
                                    _sendingTo.contains(chat.id);
                                final bool isSent = _sentTo.contains(chat.id);

                                return ListTile(
                                  leading: UserAvatar(
                                    seed: isGroup
                                        ? chat.id
                                        : (provider
                                                .participantFor(chat)
                                                ?.uid ??
                                            chat.id),
                                    avatarUrl: isGroup
                                        ? chat.groupAvatarUrl
                                        : provider
                                            .participantFor(chat)
                                            ?.avatarUrl,
                                    initials: isGroup
                                        ? 'G'
                                        : (provider
                                                .participantFor(chat)
                                                ?.initials ??
                                            '?'),
                                    radius: 22,
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isSending
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : isSent
                                          ? Icon(
                                              Icons.check_circle_rounded,
                                              color: isDark
                                                  ? AppColors.darkAccent
                                                  : AppColors.lightAccent,
                                            )
                                          : null,
                                  onTap: () => _forwardTo(chat),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
