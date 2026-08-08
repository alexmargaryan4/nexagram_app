import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../services/voice_recorder_service.dart';
import '../../theme/theme.dart';
import '../../widgets/chat/forward_message_sheet.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/message_input_bar.dart';
import '../../widgets/chat/reaction_picker.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/user_avatar.dart';
import 'group_info_screen.dart';

/// The conversation screen for a single chat.
///
/// Receives only [chatId] from the router (see [AppRoutes.chat]) and loads
/// the corresponding [ChatModel] itself before standing up a [ChatProvider]
/// — this keeps the route param wire-format simple (a bare id in the URL)
/// while [ChatProvider] still gets the fully-hydrated chat object it needs
/// at construction time.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  ChatModel? _chat;
  UserModel? _otherUser;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ChatModel? chat = await _chatService.getChat(widget.chatId);
      if (chat == null) {
        setState(() {
          _error = 'This conversation no longer exists.';
          _loading = false;
        });
        return;
      }

      UserModel? other;
      if (chat.type == ChatType.private) {
        final String? uid = context.read<AuthProvider>().currentUser?.uid;
        final String? otherUid =
            uid != null ? chat.otherParticipantId(uid) : null;
        if (otherUid != null && otherUid.isNotEmpty) {
          other = await _userService.getUser(otherUid);
        }
      }

      if (!mounted) return;
      setState(() {
        _chat = chat;
        _otherUser = other;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this conversation.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUid = context.watch<AuthProvider>().currentUser?.uid;

    if (_loading || currentUid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _chat == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Something went wrong.')),
      );
    }

    return ChangeNotifierProvider<ChatProvider>(
      create: (_) => ChatProvider(chat: _chat!, currentUid: currentUid),
      child: _ChatScreenBody(chat: _chat!, otherUser: _otherUser),
    );
  }
}

class _ChatScreenBody extends StatefulWidget {
  const _ChatScreenBody({required this.chat, this.otherUser});

  final ChatModel chat;
  final UserModel? otherUser;

  @override
  State<_ChatScreenBody> createState() => _ChatScreenBodyState();
}

class _ChatScreenBodyState extends State<_ChatScreenBody> {
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final UserService _userService = UserService();
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();

  final Map<String, UserModel> _memberCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.chat.type == ChatType.group) {
      _hydrateMembers();
    }
  }

  Future<void> _hydrateMembers() async {
    final List<UserModel> users =
        await _userService.getUsers(widget.chat.participantIds);
    if (!mounted) return;
    setState(() {
      for (final user in users) {
        _memberCache[user.uid] = user;
      }
    });
  }

  String? _displayNameFor(String uid) =>
      _memberCache[uid]?.name ?? _memberCache[uid]?.username;

  @override
  void dispose() {
    _scrollController.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.chat.type == ChatType.group) {
      return widget.chat.groupName ?? 'Group';
    }
    return widget.otherUser?.name ?? widget.otherUser?.username ?? 'Chat';
  }

  String get _subtitle {
    final ChatProvider provider = context.watch<ChatProvider>();
    if (provider.isSomeoneTyping) return 'typing…';
    if (widget.chat.type == ChatType.group) {
      return '${widget.chat.participantIds.length} members';
    }
    return DateFormatter.lastSeen(
      widget.otherUser?.lastSeen,
      isOnline: widget.otherUser?.isOnline ?? false,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _imagePicker.pickImage(
      source: source,
      imageQuality: AppConstants.imageCompressQuality,
    );
    if (file == null || !mounted) return;
    await context.read<ChatProvider>().sendImage(File(file.path));
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null || !mounted) {
      return;
    }
    final String path = result.files.single.path!;
    final String name = result.files.single.name;
    await context.read<ChatProvider>().sendFile(File(path), name);
  }

  /// Starts a voice-message recording. Returns false (without entering the
  /// composer's recording UI) if the microphone permission is denied, so
  /// [MessageInputBar] can silently stay on the text field instead of
  /// showing a stuck recording indicator.
  Future<bool> _startVoiceRecording() async {
    final bool started = await _voiceRecorder.start();
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone access is needed to record voice messages.'),
        ),
      );
    }
    return started;
  }

  Future<void> _cancelVoiceRecording() => _voiceRecorder.cancel();

  Future<void> _finishVoiceRecording() async {
    final VoiceRecording? recording = await _voiceRecorder.stop();
    if (recording == null || !mounted) return;
    await context
        .read<ChatProvider>()
        .sendVoice(recording.file, recording.duration.inMilliseconds);
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AttachSheet(
        onGallery: () {
          Navigator.pop(context);
          _pickImage(ImageSource.gallery);
        },
        onCamera: () {
          Navigator.pop(context);
          _pickImage(ImageSource.camera);
        },
        onFile: () {
          Navigator.pop(context);
          _pickFile();
        },
      ),
    );
  }

  void _showMessageActions(MessageModel message, bool isMe) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final ChatProvider provider = context.read<ChatProvider>();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.sm),
                child: ReactionPicker(
                  onSelected: (emoji) {
                    Navigator.pop(context);
                    provider.toggleReaction(message, emoji);
                  },
                ),
              ),
              GlassContainer(
                borderRadius:
                    BorderRadius.circular(AppDimens.radiusMedium),
                blurSigma: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionTile(
                      icon: Icons.reply_rounded,
                      label: 'Reply',
                      onTap: () {
                        Navigator.pop(context);
                        provider.setReplyTarget(message);
                      },
                    ),
                    _ActionTile(
                      icon: Icons.forward_rounded,
                      label: 'Forward',
                      onTap: () {
                        Navigator.pop(context);
                        ForwardMessageSheet.show(context, message);
                      },
                    ),
                    if (message.type == MessageType.text)
                      _ActionTile(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onTap: () async {
                          Navigator.pop(context);
                          await Clipboard.setData(
                            ClipboardData(text: message.text),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Message copied.')),
                          );
                        },
                      ),
                    if (isMe && !message.isDeleted)
                      _ActionTile(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        isDestructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          provider.deleteMessage(message);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.lg),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatProvider provider = context.watch<ChatProvider>();
    final String currentUid = provider.currentUid;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<MessageModel> messages = provider.messages;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            if (widget.chat.type == ChatType.private &&
                widget.otherUser != null) {
              context.push(AppRoutes.userProfilePath(widget.otherUser!.uid));
            } else if (widget.chat.type == ChatType.group) {
              context.push(AppRoutes.groupInfoPath(widget.chat.id));
            }
          },
          child: Row(
            children: [
              UserAvatar(
                seed: widget.chat.type == ChatType.group
                    ? widget.chat.id
                    : (widget.otherUser?.uid ?? widget.chat.id),
                avatarUrl: widget.chat.type == ChatType.group
                    ? widget.chat.groupAvatarUrl
                    : widget.otherUser?.avatarUrl,
                initials: widget.chat.type == ChatType.group
                    ? 'G'
                    : (widget.otherUser?.initials ?? '?'),
                radius: 18,
                showOnlineDot: widget.chat.type == ChatType.private,
                isOnline: widget.otherUser?.isOnline ?? false,
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).appBarTheme.titleTextStyle,
                    ),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: provider.isSomeoneTyping
                            ? (isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent)
                            : (isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {},
            tooltip: 'Call',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? _EmptyChatState(title: _title)
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.md,
                          vertical: AppDimens.md,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final MessageModel message = messages[index];
                          final bool isMe = message.senderId == currentUid;

                          final bool showDateHeader = index ==
                                  messages.length - 1 ||
                              !DateFormatter.isSameDay(
                                message.createdAt ?? DateTime.now(),
                                messages[index + 1].createdAt ??
                                    DateTime.now(),
                              );

                          final bool showTail = index == 0 ||
                              messages[index - 1].senderId != message.senderId;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: MessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  currentUid: currentUid,
                                  isGroupChat:
                                      widget.chat.type == ChatType.group,
                                  senderName:
                                      _displayNameFor(message.senderId),
                                  showTail: showTail,
                                  onLongPress: () =>
                                      _showMessageActions(message, isMe),
                                  onReactionTap: (emoji) =>
                                      provider.toggleReaction(message, emoji),
                                ),
                              ),
                              if (showDateHeader)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDimens.sm,
                                  ),
                                  child: Center(
                                    child: _DateChip(
                                      label: DateFormatter.messageDateHeader(
                                        message.createdAt,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
          ),
          MessageInputBar(
            replyTarget: provider.replyTarget,
            onCancelReply: () => provider.setReplyTarget(null),
            onChanged: provider.onComposerChanged,
            onSendText: provider.sendText,
            onAttachPressed: _showAttachSheet,
            onCameraPressed: () => _pickImage(ImageSource.camera),
            onStartVoiceRecording: _startVoiceRecording,
            onCancelVoiceRecording: _cancelVoiceRecording,
            onFinishVoiceRecording: _finishVoiceRecording,
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.title});

  final String title;

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
            Icon(Icons.waving_hand_rounded, size: 48, color: muted),
            const SizedBox(height: AppDimens.md),
            Text(
              'Say hello to $title',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      blurSigma: 10,
      tintOpacity: 0.6,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AttachSheet extends StatelessWidget {
  const _AttachSheet({
    required this.onGallery,
    required this.onCamera,
    required this.onFile,
  });

  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        0,
        AppDimens.lg,
        AppDimens.xl,
      ),
      child: SafeArea(
        top: false,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          blurSigma: 22,
          padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.photo_outlined,
                label: 'Photo & Video Library',
                onTap: onGallery,
              ),
              _ActionTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                onTap: onCamera,
              ),
              _ActionTile(
                icon: Icons.insert_drive_file_outlined,
                label: 'File',
                onTap: onFile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = isDestructive
        ? AppColors.error
        : (isDark ? AppColors.darkText : AppColors.lightText);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
