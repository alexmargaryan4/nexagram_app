import 'package:flutter/material.dart';

import '../../services/local_storage_service.dart';
import '../../theme/theme.dart';

/// Local, device-scoped privacy toggles (read receipts, last-seen
/// visibility). These flip a preference read by the chat/profile UI
/// rather than a server-enforced rule — see [LocalStorageService].
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final LocalStorageService _storage = LocalStorageService();

  bool _readReceipts = true;
  bool _lastSeen = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bool readReceipts = await _storage.getReadReceiptsEnabled();
    final bool lastSeen = await _storage.getLastSeenEnabled();
    if (!mounted) return;
    setState(() {
      _readReceipts = readReceipts;
      _lastSeen = lastSeen;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimens.lg),
              children: [
                _Section(
                  title: 'Messaging',
                  children: [
                    SwitchListTile(
                      title: const Text('Read Receipts'),
                      subtitle: const Text(
                        'Let others see when you\'ve read their messages',
                      ),
                      value: _readReceipts,
                      onChanged: (value) {
                        setState(() => _readReceipts = value);
                        _storage.setReadReceiptsEnabled(value);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Last Seen'),
                      subtitle: const Text(
                        'Show others when you were last online',
                      ),
                      value: _lastSeen,
                      onChanged: (value) {
                        setState(() => _lastSeen = value);
                        _storage.setLastSeenEnabled(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.xl),
                _Section(
                  title: 'Account',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.block_rounded),
                      title: const Text('Blocked Users'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(color: AppColors.error),
                      ),
                      onTap: () => _confirmDeleteAccount(context),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and profile. This action '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.sm, left: 4),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.sectionHeader(
              isDark
                  ? AppColors.darkSecondaryText
                  : AppColors.lightSecondaryText,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
