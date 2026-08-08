import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chats_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/user_avatar.dart';

/// Search-by-username/name flow used both to add a new contact and to
/// start a fresh chat directly from search results.
///
/// Pushed as a plain [MaterialPageRoute] (rather than a named go_router
/// route) from both the Chats tab's "+" button and the Contacts tab's
/// add-contact button, since it's a modal-style flow rather than a
/// deep-linkable destination.
class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  final TextEditingController _controller = TextEditingController();
  late final ContactsProvider _provider;

  @override
  void initState() {
    super.initState();
    final String uid = context.read<AuthProvider>().currentUser!.uid;
    _provider = ContactsProvider(currentUid: uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _openChat(UserModel user) async {
    final ChatsProvider chatsProvider = context.read<ChatsProvider>();
    final chat = await chatsProvider.openPrivateChatWith(user.uid);
    if (!mounted) return;
    Navigator.of(context).pop();
    context.go(AppRoutes.chatPath(chat.id));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ContactsProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Chat'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: GlassContainer(
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                blurSigma: 12,
                tintOpacity: 0.5,
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _provider.search,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search by name or @username',
                    prefixIcon: Icon(Icons.search_rounded, size: 21),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Consumer<ContactsProvider>(
                builder: (context, provider, _) {
                  if (provider.isSearching) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_controller.text.trim().isEmpty) {
                    return _HintState(
                      icon: Icons.search_rounded,
                      message: 'Search for people by name or username',
                    );
                  }
                  if (provider.searchResults.isEmpty) {
                    return _HintState(
                      icon: Icons.person_search_rounded,
                      message: 'No users found',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.md,
                    ),
                    itemCount: provider.searchResults.length,
                    itemBuilder: (context, index) {
                      final UserModel user = provider.searchResults[index];
                      final bool isContact = provider.isContact(user.uid);
                      return ListTile(
                        leading: UserAvatar(
                          seed: user.uid,
                          avatarUrl: user.avatarUrl,
                          initials: user.initials,
                          radius: AppDimens.avatarRadiusMedium,
                        ),
                        title: Text(
                          user.name.isNotEmpty ? user.name : user.username,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('@${user.username}'),
                        trailing: IconButton(
                          icon: Icon(
                            isContact
                                ? Icons.check_circle_rounded
                                : Icons.person_add_alt_1_outlined,
                            color: isContact ? AppColors.success : null,
                          ),
                          tooltip: isContact ? 'Already a contact' : 'Add contact',
                          onPressed: isContact
                              ? null
                              : () => provider.addContact(user),
                        ),
                        onTap: () => _openChat(user),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintState extends StatelessWidget {
  const _HintState({required this.icon, required this.message});

  final IconData icon;
  final String message;

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
            Icon(icon, size: 48, color: muted),
            const SizedBox(height: AppDimens.md),
            Text(
              message,
              style: TextStyle(color: muted, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
