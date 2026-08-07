import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/errors/app_exception.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/typing_status_model.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';

/// Drives a single open conversation: the live message feed, sending text
/// and media, typing-indicator plumbing, and read-receipt bookkeeping.
///
/// One instance is created per chat screen (scoped with a `ChangeNotifierProxyProvider`
/// or created directly in the screen's `initState`) and disposed when the
/// screen closes, which is why typing state is cleared in [dispose].
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.chat,
    required this.currentUid,
    ChatService? chatService,
    StorageService? storageService,
  })  : _chatService = chatService ?? ChatService(),
        _storageService = storageService ?? StorageService() {
    _subscribeMessages();
    _subscribeTyping();
    markAsRead();
  }

  final ChatModel chat;
  final String currentUid;
  final ChatService _chatService;
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<MessageModel>>? _messagesSub;
  StreamSubscription<List<TypingStatusModel>>? _typingSub;
  Timer? _typingDebounce;
  Timer? _typingClearTimer;

  List<MessageModel> _messages = [];
  List<TypingStatusModel> _typingUsers = [];
  bool _isLoading = true;
  String? _error;
  MessageModel? _replyTarget;
  bool _isSendingMedia = false;

  List<MessageModel> get messages => _messages;
  List<TypingStatusModel> get typingUsers => _typingUsers;
  bool get isLoading => _isLoading;
  bool get isSomeoneTyping => _typingUsers.isNotEmpty;
  String? get error => _error;
  MessageModel? get replyTarget => _replyTarget;
  bool get isSendingMedia => _isSendingMedia;

  void _subscribeMessages() {
    _messagesSub = _chatService.watchMessages(chat.id).listen(
      (msgs) {
        _messages = msgs;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _isLoading = false;
        _error = 'Could not load messages.';
        notifyListeners();
      },
    );
  }

  void _subscribeTyping() {
    _typingSub =
        _chatService.watchTyping(chat.id, excludeUid: currentUid).listen(
      (typing) {
        _typingUsers = typing;
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead() => _chatService.markChatAsRead(chat.id, currentUid);

  void setReplyTarget(MessageModel? message) {
    _replyTarget = message;
    notifyListeners();
  }

  Future<void> sendText(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final MessageModel? reply = _replyTarget;
    _replyTarget = null;
    notifyListeners();
    await setTyping(false);

    try {
      await _chatService.sendMessage(
        chatId: chat.id,
        senderId: currentUid,
        type: MessageType.text,
        text: trimmed,
        replyToMessageId: reply?.id,
        replyToPreview: reply == null ? null : _previewFor(reply),
        replyToSenderName: reply?.senderId,
        participantIds: chat.participantIds,
      );
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> sendImage(File file) async {
    _isSendingMedia = true;
    notifyListeners();
    try {
      final String fileName = '${_uuid.v4()}.jpg';
      final String url =
          await _storageService.uploadChatImage(chat.id, fileName, file);
      await _chatService.sendMessage(
        chatId: chat.id,
        senderId: currentUid,
        type: MessageType.image,
        mediaUrl: url,
        participantIds: chat.participantIds,
      );
    } on AppException catch (e) {
      _error = e.message;
    } finally {
      _isSendingMedia = false;
      notifyListeners();
    }
  }

  Future<void> sendFile(File file, String fileName) async {
    _isSendingMedia = true;
    notifyListeners();
    try {
      final int size = file.lengthSync();
      final String storageName = '${_uuid.v4()}_$fileName';
      final String url =
          await _storageService.uploadChatFile(chat.id, storageName, file);
      await _chatService.sendMessage(
        chatId: chat.id,
        senderId: currentUid,
        type: MessageType.file,
        fileName: fileName,
        fileSizeBytes: size,
        mediaUrl: url,
        participantIds: chat.participantIds,
      );
    } on AppException catch (e) {
      _error = e.message;
    } finally {
      _isSendingMedia = false;
      notifyListeners();
    }
  }

  Future<void> sendVoice(File file, int durationMs) async {
    _isSendingMedia = true;
    notifyListeners();
    try {
      final String fileName = '${_uuid.v4()}.m4a';
      final String url =
          await _storageService.uploadVoiceMessage(chat.id, fileName, file);
      await _chatService.sendMessage(
        chatId: chat.id,
        senderId: currentUid,
        type: MessageType.voice,
        mediaUrl: url,
        voiceDurationMs: durationMs,
        participantIds: chat.participantIds,
      );
    } on AppException catch (e) {
      _error = e.message;
    } finally {
      _isSendingMedia = false;
      notifyListeners();
    }
  }

  String _previewFor(MessageModel message) {
    switch (message.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.file:
        return '📎 ${message.fileName ?? 'File'}';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.text:
      case MessageType.system:
        return message.text;
    }
  }

  Future<void> deleteMessage(MessageModel message) {
    return _chatService.deleteMessage(chat.id, message.id);
  }

  Future<void> editMessage(MessageModel message, String newText) {
    return _chatService.editMessage(chat.id, message.id, newText);
  }

  Future<void> toggleReaction(MessageModel message, String emoji) {
    final bool alreadyReacted =
        message.reactions[emoji]?.contains(currentUid) ?? false;
    return _chatService.toggleReaction(
      chatId: chat.id,
      messageId: message.id,
      emoji: emoji,
      uid: currentUid,
      add: !alreadyReacted,
    );
  }

  /// Call on every keystroke in the composer. Debounces writes to Firestore
  /// (so we don't fire a write per character) and auto-clears the typing
  /// flag after [AppConstants.typingTimeout] of inactivity.
  void onComposerChanged(String text) {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 400), () {
      setTyping(text.trim().isNotEmpty);
    });
  }

  Future<void> setTyping(bool isTyping) async {
    _typingClearTimer?.cancel();
    await _chatService.setTyping(chat.id, currentUid, isTyping);
    if (isTyping) {
      _typingClearTimer = Timer(const Duration(seconds: 4), () {
        _chatService.setTyping(chat.id, currentUid, false);
      });
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _typingSub?.cancel();
    _typingDebounce?.cancel();
    _typingClearTimer?.cancel();
    _chatService.setTyping(chat.id, currentUid, false);
    super.dispose();
  }
}
