import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';

/// Live chat list for the signed-in user, plus lightweight caching of the
/// "other participant" [UserModel] for each private chat so chat-list
/// tiles can render name/avatar without a widget-level fetch each time.
class ChatsProvider extends ChangeNotifier {
  ChatsProvider({
    required String currentUid,
    ChatService? chatService,
    UserService? userService,
  })  : _currentUid = currentUid,
        _chatService = chatService ?? ChatService(),
        _userService = userService ?? UserService() {
    _subscribe();
  }

  final String _currentUid;
  final ChatService _chatService;
  final UserService _userService;

  StreamSubscription<List<ChatModel>>? _sub;

  List<ChatModel> _chats = [];
  final Map<String, UserModel> _participantCache = {};
  bool _isLoading = true;
  String? _error;

  List<ChatModel> get chats => _chats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Chats sorted with pinned conversations first, then by recency —
  /// both groups already arrive recency-sorted from Firestore.
  List<ChatModel> get sortedChats {
    final List<ChatModel> pinned =
        _chats.where((c) => c.isPinnedBy(_currentUid)).toList();
    final List<ChatModel> rest =
        _chats.where((c) => !c.isPinnedBy(_currentUid)).toList();
    return [...pinned, ...rest];
  }

  int get totalUnreadCount =>
      _chats.fold(0, (sum, c) => sum + c.unreadCountFor(_currentUid));

  UserModel? participantFor(ChatModel chat) {
    final String? otherUid = chat.otherParticipantId(_currentUid);
    if (otherUid == null) return null;
    return _participantCache[otherUid];
  }

  void _subscribe() {
    _sub = _chatService.watchUserChats(_currentUid).listen(
      (chats) async {
        _chats = chats;
        _isLoading = false;
        _error = null;
        notifyListeners();
        await _hydrateParticipants(chats);
      },
      onError: (Object e) {
        _isLoading = false;
        _error = 'Could not load chats.';
        notifyListeners();
      },
    );
  }

  Future<void> _hydrateParticipants(List<ChatModel> chats) async {
    final Set<String> missingUids = {};
    for (final chat in chats) {
      final String? otherUid = chat.otherParticipantId(_currentUid);
      if (otherUid != null &&
          otherUid.isNotEmpty &&
          !_participantCache.containsKey(otherUid)) {
        missingUids.add(otherUid);
      }
    }
    if (missingUids.isEmpty) return;

    final List<UserModel> users = await _userService.getUsers(
      missingUids.toList(),
    );
    for (final user in users) {
      _participantCache[user.uid] = user;
    }
    notifyListeners();
  }

  Future<ChatModel> openPrivateChatWith(String otherUid) {
    return _chatService.getOrCreatePrivateChat(_currentUid, otherUid);
  }

  Future<void> togglePin(ChatModel chat) {
    return _chatService.togglePin(
      chat.id,
      _currentUid,
      !chat.isPinnedBy(_currentUid),
    );
  }

  Future<void> toggleMute(ChatModel chat) {
    return _chatService.toggleMute(
      chat.id,
      _currentUid,
      !chat.isMutedBy(_currentUid),
    );
  }

  Future<void> deleteChat(ChatModel chat) {
    return _chatService.deleteChat(chat.id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
