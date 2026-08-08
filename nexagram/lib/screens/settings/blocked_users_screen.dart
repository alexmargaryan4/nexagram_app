import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common/user_avatar.dart';

/// Lists everyone the current user has blocked (from
/// `users.blocked_user_ids`, see [UserService.blockUser]) and lets them be
/// unblocked from a single place.
///
/// Reached from Settings → Privacy → Blocked Users. Blocking itself happens
/// from [UserProfileScreen]; this screen only needs to read the current
/// user's block list and offer the reverse action.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final UserService _userService = UserService();

  bool _loading = true;
  List<UserModel> _blockedUsers = [];
  final Set<String> _pendingUids = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final UserModel? me = context.read<AuthProvider>().currentUser;
    if (me == null || me.blockedUserIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _blockedUsers = [];
        _loading = false;
      });
      return;
    }

    final List<UserModel> users =
        await _userService.getUsers(me.blockedUserIds);
    if (!mounted) return;
    setState(() {
      _blockedUsers = users;
      _loading = false;
    });
  }

  Future<void> _unblock(UserModel user) async {
    final String? myUid = context.read<AuthProvider>().currentUser?.uid;
    if (myUid == null) return;

    setState(() => _pendingUids.add(user.uid));
    try {
      await _userService.unblockUser(myUid, user.uid);
      if (!mounted) return;
      setState(() {
        _blockedUsers.removeWhere((u) => u.uid == user.uid);
        _pendingUids.remove(user.uid);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} was unblocked.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingUids.remove(user.uid));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not unblock this user.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _EmptyState(muted: muted)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.md,
                  ),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(left: 72),
                    child: Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final UserModel user = _blockedUsers[index];
                    final bool isPending = _pendingUids.contains(user.uid);
                    return ListTile(
                      leading: UserAvatar(
                        seed: user.uid,
                        avatarUrl: user.avatarUrl,
                        initials: user.initials,
                        radius: 22,
                      ),
                      title: Text(
                        user.name.isNotEmpty ? user.name : user.username,
                      ),
                      subtitle: Text(
                        '@${user.username}',
                        style: TextStyle(color: muted),
                      ),
                      trailing: TextButton(
                        onPressed: isPending ? null : () => _unblock(user),
                        child: isPending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Unblock'),
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 48, color: muted),
            const SizedBox(height: AppDimens.md),
            Text(
              'No blocked users',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'People you block won\'t be able to message you or see your '
              'profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
