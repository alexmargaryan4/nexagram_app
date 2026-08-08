import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common/user_avatar.dart';

/// Read-only profile view for another user, reached by tapping a chat
/// header or a contact. Offers "message" and "add/remove contact" actions
/// scoped to the viewer's own contact list.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final UserModel? user = await _userService.getUser(widget.uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _openChat() async {
    final String myUid = context.read<AuthProvider>().currentUser!.uid;
    final chat = await _chatService.getOrCreatePrivateChat(myUid, widget.uid);
    if (!mounted) return;
    context.push(AppRoutes.chatPath(chat.id));
  }

  @override
  Widget build(BuildContext context) {
    final String myUid = context.watch<AuthProvider>().currentUser!.uid;

    return ChangeNotifierProvider<ContactsProvider>(
      create: (_) => ContactsProvider(currentUid: myUid),
      child: Scaffold(
        appBar: AppBar(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _user == null
                ? const Center(child: Text('User not found.'))
                : _buildBody(context, _user!),
      ),
    );
  }

  Widget _buildBody(BuildContext context, UserModel user) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(AppDimens.lg),
      children: [
        Center(
          child: UserAvatar(
            seed: user.uid,
            avatarUrl: user.avatarUrl,
            initials: user.initials,
            radius: 56,
            heroTag: 'avatar-${user.uid}',
            showOnlineDot: true,
            isOnline: user.isOnline,
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        Center(
          child: Text(
            user.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            '@${user.username}',
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? AppColors.darkSecondaryText
                  : AppColors.lightSecondaryText,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            DateFormatter.lastSeen(user.lastSeen, isOnline: user.isOnline),
            style: TextStyle(
              fontSize: 13,
              color: user.isOnline
                  ? AppColors.online
                  : (isDark
                      ? AppColors.darkSecondaryText
                      : AppColors.lightSecondaryText),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.xl),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Message',
                onTap: _openChat,
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Consumer<ContactsProvider>(
              builder: (context, provider, _) {
                final bool isContact = provider.isContact(user.uid);
                return Expanded(
                  child: _ActionButton(
                    icon: isContact
                        ? Icons.person_remove_outlined
                        : Icons.person_add_alt_1_outlined,
                    label: isContact ? 'Remove' : 'Add Contact',
                    onTap: () => isContact
                        ? provider.removeContact(user.uid)
                        : provider.addContact(user),
                  ),
                );
              },
            ),
          ],
        ),
        if (user.bio.isNotEmpty) ...[
          const SizedBox(height: AppDimens.xxl),
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BIO',
                  style: AppTypography.sectionHeader(
                    isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(user.bio, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    return Material(
      color: accent.withOpacity(isDark ? 0.18 : 0.1),
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
