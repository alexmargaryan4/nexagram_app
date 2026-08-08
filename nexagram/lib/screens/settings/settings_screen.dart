import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/common/user_avatar.dart';

/// Tab 3 of [MainShell]: profile summary, theme switcher, and links into
/// the deeper settings sub-screens (privacy, notifications) plus sign-out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.currentUser;

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
            title: const Text('Settings'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user != null)
                    _ProfileCard(
                      name: user.name,
                      username: user.username,
                      avatarUrl: user.avatarUrl,
                      uid: user.uid,
                      initials: user.initials,
                      onTap: () => context.pushNamed(AppRoutes.profileName),
                    ),
                  const SizedBox(height: AppDimens.xl),
                  _SectionHeader('Appearance'),
                  _SettingsGroup(
                    children: [
                      _ThemeTile(
                        label: 'Light',
                        icon: Icons.light_mode_outlined,
                        selected: themeProvider.themeMode == ThemeMode.light,
                        onTap: () =>
                            themeProvider.setThemeMode(ThemeMode.light),
                      ),
                      _ThemeTile(
                        label: 'Dark',
                        icon: Icons.dark_mode_outlined,
                        selected: themeProvider.themeMode == ThemeMode.dark,
                        onTap: () =>
                            themeProvider.setThemeMode(ThemeMode.dark),
                      ),
                      _ThemeTile(
                        label: 'System',
                        icon: Icons.smartphone_rounded,
                        selected: themeProvider.themeMode == ThemeMode.system,
                        onTap: () =>
                            themeProvider.setThemeMode(ThemeMode.system),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.xl),
                  _SectionHeader('Preferences'),
                  _SettingsGroup(
                    children: [
                      _NavTile(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () => context.pushNamed(
                          AppRoutes.notificationSettingsName,
                        ),
                      ),
                      _NavTile(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacy',
                        onTap: () => context.pushNamed(
                          AppRoutes.privacySettingsName,
                        ),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.xl),
                  _SettingsGroup(
                    children: [
                      _NavTile(
                        icon: Icons.logout_rounded,
                        label: 'Log Out',
                        isDestructive: true,
                        isLast: true,
                        onTap: () => _confirmSignOut(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.xl),
                  Center(
                    child: Text(
                      '${AppConstants.appName} v${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.username,
    required this.uid,
    required this.initials,
    this.avatarUrl,
    this.onTap,
  });

  final String name;
  final String username;
  final String uid;
  final String initials;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Row(
            children: [
              UserAvatar(
                seed: uid,
                avatarUrl: avatarUrl,
                initials: initials,
                radius: 32,
                heroTag: 'avatar-$uid',
              ),
              const SizedBox(width: AppDimens.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sm, left: 4),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.sectionHeader(
          isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      ),
      child: Column(children: children),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = isDestructive
        ? AppColors.error
        : (isDark ? AppColors.darkText : AppColors.lightText);

    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: color),
          title: Text(label, style: TextStyle(color: color)),
          trailing: isDestructive
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.darkSecondaryText
                      : AppColors.lightSecondaryText,
                ),
          onTap: onTap,
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Divider(
              height: 1,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.isLast = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: selected
              ? Icon(Icons.check_rounded, color: accent)
              : null,
          onTap: onTap,
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Divider(
              height: 1,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
      ],
    );
  }
}
