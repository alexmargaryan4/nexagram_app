import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/common/user_avatar.dart';

/// Read-only view of the signed-in user's own profile, reached from the
/// Settings tab. Editing happens on [EditProfileScreen], pushed from here.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UserModel? user = context.watch<AuthProvider>().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: () => context.pushNamed(AppRoutes.editProfileName),
            child: const Text('Edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.lg),
        children: [
          Center(
            child: UserAvatar(
              seed: user.uid,
              avatarUrl: user.avatarUrl,
              initials: user.initials,
              radius: 56,
              heroTag: 'avatar-${user.uid}',
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.xxl),
          if (user.bio.isNotEmpty) ...[
            _InfoTile(icon: Icons.info_outline_rounded, label: 'Bio', value: user.bio),
            const SizedBox(height: AppDimens.sm),
          ],
          _InfoTile(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: user.email,
          ),
          if (user.phoneNumber.isNotEmpty) ...[
            const SizedBox(height: AppDimens.sm),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phoneNumber,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
                Text(value, style: const TextStyle(fontSize: 15.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
