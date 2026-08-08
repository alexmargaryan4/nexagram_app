import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_model.dart';
import '../../models/contact_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/user_avatar.dart';

/// Group details screen: member list, plus an "Add member" flow.
///
/// Adding someone here calls [ChatService.addGroupMember], which drops a
/// system message into the chat so the group finds out how the new person
/// joined — the person who was just added sees "{who} added you to the
/// group", and everyone else sees "{who} joined the group" (decoded
/// per-viewer by [MessageBubble] at render time; see
/// `SystemMessageCodec`).
class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  ChatModel? _chat;
  final Map<String, UserModel> _members = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ChatModel? chat = await _chatService.getChat(widget.chatId);
    if (chat == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final List<UserModel> users =
        await _userService.getUsers(chat.participantIds);
    if (!mounted) return;
    setState(() {
      _chat = chat;
      for (final u in users) {
        _members[u.uid] = u;
      }
      _loading = false;
    });
  }

  Future<void> _openAddMember() async {
    final ChatModel? chat = _chat;
    if (chat == null) return;
    final String myUid = context.read<AuthProvider>().currentUser!.uid;
    final UserModel? me = _members[myUid];

    final UserModel? picked = await showModalBottomSheet<UserModel>(
      context: context,
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBackground
              : AppColors.lightBackground,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider<ContactsProvider>(
        create: (_) => ContactsProvider(currentUid: myUid),
        child: _AddMemberSheet(existingMemberIds: chat.participantIds),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => _members[picked.uid] = picked);

    try {
      await _chatService.addGroupMember(
        chat.id,
        picked.uid,
        addedByUid: myUid,
        addedByName: me?.name ?? me?.username ?? 'Someone',
        newMemberName: picked.name.isNotEmpty ? picked.name : picked.username,
      );
      final ChatModel? refreshed = await _chatService.getChat(chat.id);
      if (!mounted || refreshed == null) return;
      setState(() => _chat = refreshed);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that person.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final ChatModel? chat = _chat;
    if (chat == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This group no longer exists.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Group Info')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.lg),
        children: [
          Center(
            child: Column(
              children: [
                UserAvatar(
                  seed: chat.id,
                  avatarUrl: chat.groupAvatarUrl,
                  initials: 'G',
                  radius: 44,
                ),
                const SizedBox(height: AppDimens.md),
                Text(
                  chat.groupName ?? 'Group',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${chat.participantIds.length} members',
                  style: TextStyle(color: muted, fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          GlassContainer(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                            .withOpacity(0.15),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    ),
                  ),
                  title: const Text(
                    'Add member',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: _openAddMember,
                ),
                for (final uid in chat.participantIds)
                  ListTile(
                    leading: UserAvatar(
                      seed: uid,
                      avatarUrl: _members[uid]?.avatarUrl,
                      initials: _members[uid]?.initials ?? '?',
                      radius: AppDimens.avatarRadiusMedium,
                    ),
                    title: Text(
                      _members[uid]?.name.isNotEmpty == true
                          ? _members[uid]!.name
                          : (_members[uid]?.username ?? 'Unknown'),
                    ),
                    subtitle: chat.groupAdminIds.contains(uid)
                        ? const Text('Admin')
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

class _AddMemberSheet extends StatelessWidget {
  const _AddMemberSheet({required this.existingMemberIds});

  final List<String> existingMemberIds;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.md,
          0,
          AppDimens.md,
          AppDimens.md,
        ),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          blurSigma: 22,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                const SizedBox(height: AppDimens.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
                  child: Text(
                    'Add member',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer<ContactsProvider>(
                    builder: (context, provider, _) {
                      final List<ContactModel> available = provider.contacts
                          .where((c) => !existingMemberIds.contains(c.contactUid))
                          .toList();

                      if (provider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (available.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppDimens.xl),
                            child: Text(
                              'Everyone in your contacts is already here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: available.length,
                        itemBuilder: (context, index) {
                          final ContactModel c = available[index];
                          return ListTile(
                            leading: UserAvatar(
                              seed: c.contactUid,
                              avatarUrl: c.avatarUrl,
                              initials: c.name.isNotEmpty
                                  ? c.name.substring(0, 1).toUpperCase()
                                  : '?',
                              radius: AppDimens.avatarRadiusMedium,
                            ),
                            title: Text(c.name),
                            subtitle: Text('@${c.username}'),
                            onTap: () => Navigator.of(context).pop(
                              UserModel(
                                uid: c.contactUid,
                                username: c.username,
                                name: c.name,
                                email: '',
                                avatarUrl: c.avatarUrl,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
