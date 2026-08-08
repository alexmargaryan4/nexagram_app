import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../models/contact_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../services/chat_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common/glass_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/user_avatar.dart';

/// Two-step group creation flow: pick members from saved contacts, then
/// name the group.
///
/// Reuses the existing contact list rather than a fresh user search,
/// since group members are drawn from people you already know — anyone
/// not yet a contact needs to be added via [ContactPickerScreen] first.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final Set<String> _selectedUids = {};
  final Map<String, ContactModel> _selectedContacts = {};
  final TextEditingController _groupNameController = TextEditingController();
  final ChatService _chatService = ChatService();

  bool _namingStep = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _toggle(ContactModel contact) {
    setState(() {
      if (_selectedUids.contains(contact.contactUid)) {
        _selectedUids.remove(contact.contactUid);
        _selectedContacts.remove(contact.contactUid);
      } else {
        _selectedUids.add(contact.contactUid);
        _selectedContacts[contact.contactUid] = contact;
      }
    });
  }

  Future<void> _createGroup() async {
    final String name = _groupNameController.text.trim();
    if (name.isEmpty || _selectedUids.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final String creatorUid = context.read<AuthProvider>().currentUser!.uid;
      final chat = await _chatService.createGroupChat(
        creatorUid: creatorUid,
        groupName: name,
        memberUids: _selectedUids.toList(),
      );
      if (!mounted) return;
      context.go(AppRoutes.chatPath(chat.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the group.')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = context.watch<AuthProvider>().currentUser!.uid;

    return ChangeNotifierProvider<ContactsProvider>(
      create: (_) => ContactsProvider(currentUid: uid),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_namingStep ? 'Name Group' : 'New Group'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (_namingStep) {
                setState(() => _namingStep = false);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: _namingStep ? _buildNamingStep() : _buildMemberPicker(),
      ),
    );
  }

  Widget _buildMemberPicker() {
    return Consumer<ContactsProvider>(
      builder: (context, provider, _) {
        final List<ContactModel> contacts = provider.contacts;

        return Column(
          children: [
            if (_selectedUids.isNotEmpty)
              SizedBox(
                height: 88,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.lg,
                    vertical: AppDimens.sm,
                  ),
                  itemCount: _selectedContacts.length,
                  itemBuilder: (context, index) {
                    final ContactModel c =
                        _selectedContacts.values.elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.only(right: AppDimens.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              UserAvatar(
                                seed: c.contactUid,
                                avatarUrl: c.avatarUrl,
                                initials: c.name.isNotEmpty
                                    ? c.name.substring(0, 1).toUpperCase()
                                    : '?',
                                radius: 26,
                              ),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: GestureDetector(
                                  onTap: () => _toggle(c),
                                  child: const CircleAvatar(
                                    radius: 9,
                                    backgroundColor: AppColors.error,
                                    child: Icon(Icons.close_rounded,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 56,
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : contacts.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.xxl),
                            child: Text(
                              'Add some contacts first to create a group.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final ContactModel contact = contacts[index];
                            final bool selected =
                                _selectedUids.contains(contact.contactUid);
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (_) => _toggle(contact),
                              controlAffinity:
                                  ListTileControlAffinity.trailing,
                              secondary: UserAvatar(
                                seed: contact.contactUid,
                                avatarUrl: contact.avatarUrl,
                                initials: contact.name.isNotEmpty
                                    ? contact.name.substring(0, 1).toUpperCase()
                                    : '?',
                                radius: AppDimens.avatarRadiusMedium,
                              ),
                              title: Text(contact.name),
                              subtitle: Text('@${contact.username}'),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.lg),
                child: PrimaryButton(
                  label: 'Next',
                  enabled: _selectedUids.isNotEmpty,
                  onPressed: () => setState(() => _namingStep = true),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNamingStep() {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppDimens.md),
          Center(
            child: Text(
              '${_selectedUids.length} member${_selectedUids.length == 1 ? '' : 's'} selected',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          AppTextField(
            controller: _groupNameController,
            label: 'Group name',
            prefixIcon: Icons.group_outlined,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppDimens.xl),
          PrimaryButton(
            label: 'Create Group',
            isLoading: _isCreating,
            onPressed: _createGroup,
          ),
        ],
      ),
    );
  }
}
