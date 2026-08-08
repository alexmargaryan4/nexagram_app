import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/router/app_routes.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chats_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/chats/chat_list_tile.dart';
import '../../widgets/common/glass_container.dart';
import '../contacts/contact_picker_screen.dart';

/// Tab 1 of [MainShell]: the live, real-time list of the signed-in user's
/// conversations, sorted pinned-first then by recency.
///
/// Deliberately reads [ChatsProvider] from the shell (via [context.watch])
/// rather than creating its own — see [MainShell]'s doc comment for why
/// the subscription is scoped to the shell instead of this screen.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChatsProvider chatsProvider = context.watch<ChatsProvider>();
    final String? currentUid = context.watch<AuthProvider>().currentUser?.uid;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<ChatModel> chats = chatsProvider.sortedChats.where((chat) {
      if (_query.isEmpty) return true;
      final UserModel? other = chatsProvider.participantFor(chat);
      final String title = chat.type == ChatType.group
          ? (chat.groupName ?? 'Group')
          : (other?.name ?? other?.username ?? '');
      return title.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor:
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text('Chats'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'New chat',
                onPressed: () => _openNewChat(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                AppDimens.sm,
                AppDimens.lg,
                AppDimens.sm,
              ),
              child: _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          if (chatsProvider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (chats.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(hasQuery: _query.isNotEmpty),
            )
          else
            SliverList.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final ChatModel chat = chats[index];
                final UserModel? other = chatsProvider.participantFor(chat);
                final String title = chat.type == ChatType.group
                    ? (chat.groupName ?? 'Group')
                    : (other?.name ?? other?.username ?? 'Unknown');

                return Slidable(
                  key: ValueKey(chat.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.62,
                    children: [
                      SlidableAction(
                        onPressed: (_) => chatsProvider.togglePin(chat),
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        icon: chat.isPinnedBy(currentUid)
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        label: chat.isPinnedBy(currentUid) ? 'Unpin' : 'Pin',
                      ),
                      SlidableAction(
                        onPressed: (_) => chatsProvider.toggleMute(chat),
                        backgroundColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSecondaryText,
                        foregroundColor: Colors.white,
                        icon: chat.isMutedBy(currentUid)
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        label: chat.isMutedBy(currentUid) ? 'Unmute' : 'Mute',
                      ),
                      SlidableAction(
                        onPressed: (_) => _confirmDelete(context, chatsProvider, chat),
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                      ),
                    ],
                  ),
                  child: ChatListTile(
                    chat: chat,
                    currentUid: currentUid,
                    title: title,
                    avatarUrl: chat.type == ChatType.group
                        ? chat.groupAvatarUrl
                        : other?.avatarUrl,
                    avatarSeed: chat.type == ChatType.group
                        ? chat.id
                        : (other?.uid ?? chat.id),
                    isOnline: other?.isOnline ?? false,
                    onTap: () => context.push(AppRoutes.chatPath(chat.id)),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ChatsProvider provider,
    ChatModel chat,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text(
          'This removes the conversation from your chat list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteChat(chat);
    }
  }

  void _openNewChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContactPickerScreen()),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      blurSigma: 12,
      tintOpacity: 0.5,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Search chats',
          prefixIcon: Icon(Icons.search_rounded, size: 21),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery
                  ? Icons.search_off_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 56,
              color: muted,
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              hasQuery ? 'No chats match your search' : 'No conversations yet',
              style: TextStyle(color: muted, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: AppDimens.xs),
              Text(
                'Tap + to start a new conversation',
                style: TextStyle(color: muted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
