import 'package:flutter/material.dart';

import '../../services/local_storage_service.dart';
import '../../theme/theme.dart';

/// Toggles the local "notifications enabled" preference used to suppress
/// foreground/background local-notification display (see
/// [NotificationService]).
///
/// Note: this only controls whether NexaGram shows a heads-up banner for
/// messages it receives over its live Realtime connection — it doesn't
/// unsubscribe from that connection outright (see
/// `NotificationService.unregisterToken`, called on sign-out instead).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final LocalStorageService _storage = LocalStorageService();

  bool _enabled = true;
  bool _messagePreview = true;
  bool _sound = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bool enabled = await _storage.getNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimens.lg),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Notifications'),
                        value: _enabled,
                        onChanged: (value) {
                          setState(() => _enabled = value);
                          _storage.setNotificationsEnabled(value);
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
                        title: const Text('Message Preview'),
                        subtitle: const Text(
                          'Show message text in notifications',
                        ),
                        value: _messagePreview && _enabled,
                        onChanged: _enabled
                            ? (value) =>
                                setState(() => _messagePreview = value)
                            : null,
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
                        title: const Text('Sound'),
                        value: _sound && _enabled,
                        onChanged: _enabled
                            ? (value) => setState(() => _sound = value)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
