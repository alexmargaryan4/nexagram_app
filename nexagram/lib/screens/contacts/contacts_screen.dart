import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../models/contact_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chats_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/user_avatar.dart';
import 'contact_picker_screen.dart';
import 'new_group_screen.dart';

/// Tab 2 of [MainShell]: the signed-in user's saved contact list.
///
/// Scopes its own [ContactsProvider] (unlike [ChatsScreen], which reads
/// one from the shell) because contacts don't need to survive a tab
/// switch the way an open chat subscription does — this screen's list is
/// cheap to resubscribe to each time it becomes visible.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = context.watch<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ChangeNotifierProvider<ContactsProvider>(
      create: (_) => ContactsProvider(currentUid: uid),
      child: const _ContactsScreenBody(),
    );
  }
}

class _ContactsScreenBody extends StatelessWidget {
  const _ContactsScreenBody();

  @override
  Widget build(BuildContext context) {
    final ContactsProvider provider = context.watch<ContactsProvider>();
    final List<ContactModel> contacts = provider.contacts;

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
            title: const Text('Contacts'),
            actions: [
              IconButton(
                icon: const Icon(Icons.group_add_outlined),
                tooltip: 'New group',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewGroupScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                tooltip: 'Add contact',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ContactPickerScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (contacts.isEmpty)
            const SliverFillRemaining(child: _EmptyContactsState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: AppDimens.sm,
              ),
              sliver: SliverList.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final ContactModel contact = contacts[index];
                  return _ContactTile(contact: contact);
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final ContactModel contact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          onTap: () async {
            final ChatsProvider chatsProvider =
                context.read<ChatsProvider>();
            final chat =
                await chatsProvider.openPrivateChatWith(contact.contactUid);
            if (context.mounted) {
              context.go(AppRoutes.chatPath(chat.id));
            }
          },
          onLongPress: () => _confirmRemove(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: AppDimens.sm,
            ),
            child: Row(
              children: [
                UserAvatar(
                  seed: contact.contactUid,
                  avatarUrl: contact.avatarUrl,
                  initials: contact.name.isNotEmpty
                      ? contact.name.substring(0, 1).toUpperCase()
                      : '?',
                  radius: AppDimens.avatarRadiusMedium,
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@${contact.username}',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final ContactsProvider provider = context.read<ContactsProvider>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove contact?'),
        content: Text('${contact.name} will be removed from your contacts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.removeContact(contact.contactUid);
    }
  }
}

class _EmptyContactsState extends StatelessWidget {
  const _EmptyContactsState();

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
            Icon(Icons.people_outline_rounded, size: 56, color: muted),
            const SizedBox(height: AppDimens.md),
            Text(
              'No contacts yet',
              style: TextStyle(color: muted, fontSize: 16),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Tap the add-contact icon to find people',
              style: TextStyle(color: muted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
