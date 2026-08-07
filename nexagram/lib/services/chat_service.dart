import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/typing_status_model.dart';

/// Handles everything under `chats/{chatId}` — conversation metadata,
/// the `messages` sub-collection, typing indicators, reactions, and
/// read/delivery receipts.
class ChatService {
  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection(FirestoreCollections.chats);

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection(FirestoreCollections.messages);

  CollectionReference<Map<String, dynamic>> _typing(String chatId) =>
      _chats.doc(chatId).collection(FirestoreCollections.typingStatus);

  // ---------------------------------------------------------------------
  // Chat list & metadata
  // ---------------------------------------------------------------------

  /// Live list of chats the given user participates in, most-recent first.
  Stream<List<ChatModel>> watchUserChats(String uid) {
    return _chats
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatModel.fromDoc).toList());
  }

  Stream<ChatModel?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map(
          (doc) => doc.exists ? ChatModel.fromDoc(doc) : null,
        );
  }

  Future<ChatModel?> getChat(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    return doc.exists ? ChatModel.fromDoc(doc) : null;
  }

  /// Gets-or-creates the deterministic 1:1 chat between two users.
  Future<ChatModel> getOrCreatePrivateChat(
    String myUid,
    String otherUid,
  ) async {
    final String chatId = ChatModel.privateChatId(myUid, otherUid);
    final DocumentReference<Map<String, dynamic>> ref = _chats.doc(chatId);
    final DocumentSnapshot<Map<String, dynamic>> existing = await ref.get();

    if (existing.exists) {
      return ChatModel.fromDoc(existing);
    }

    final ChatModel chat = ChatModel(
      id: chatId,
      type: ChatType.private,
      participantIds: [myUid, otherUid],
      createdAt: DateTime.now(),
      createdBy: myUid,
      unreadCounts: {myUid: 0, otherUid: 0},
    );

    try {
      await ref.set(chat.toMap());
      return chat;
    } catch (e) {
      throw const FirestoreException('Could not start the conversation.');
    }
  }

  Future<ChatModel> createGroupChat({
    required String creatorUid,
    required String groupName,
    required List<String> memberUids,
    String? avatarUrl,
  }) async {
    final List<String> participants = {creatorUid, ...memberUids}.toList();
    final DocumentReference<Map<String, dynamic>> ref = _chats.doc();

    final ChatModel chat = ChatModel(
      id: ref.id,
      type: ChatType.group,
      participantIds: participants,
      groupName: groupName,
      groupAvatarUrl: avatarUrl,
      groupAdminIds: [creatorUid],
      createdAt: DateTime.now(),
      createdBy: creatorUid,
      unreadCounts: {for (final id in participants) id: 0},
    );

    try {
      await ref.set(chat.toMap());
      return chat;
    } catch (e) {
      throw const FirestoreException('Could not create the group.');
    }
  }

  Future<void> updateGroupInfo(
    String chatId, {
    String? groupName,
    String? groupAvatarUrl,
  }) async {
    final Map<String, dynamic> updates = {};
    if (groupName != null) updates['groupName'] = groupName;
    if (groupAvatarUrl != null) updates['groupAvatarUrl'] = groupAvatarUrl;
    if (updates.isEmpty) return;
    await _chats.doc(chatId).update(updates);
  }

  Future<void> addGroupMember(String chatId, String uid) async {
    await _chats.doc(chatId).update({
      'participantIds': FieldValue.arrayUnion([uid]),
      'unreadCounts.$uid': 0,
    });
  }

  Future<void> removeGroupMember(String chatId, String uid) async {
    await _chats.doc(chatId).update({
      'participantIds': FieldValue.arrayRemove([uid]),
      'groupAdminIds': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> toggleMute(String chatId, String uid, bool mute) async {
    await _chats.doc(chatId).update({
      'mutedBy': mute
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> togglePin(String chatId, String uid, bool pin) async {
    await _chats.doc(chatId).update({
      'pinnedBy': pin
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> deleteChat(String chatId) async {
    // NOTE: message sub-collection cleanup is handled server-side by a
    // Cloud Function trigger (see docs/FIREBASE_SETUP.md) since client SDKs
    // cannot recursively delete sub-collections.
    await _chats.doc(chatId).delete();
  }

  // ---------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------

  /// Live page of most-recent messages, newest first (index 0 = newest).
  Stream<List<MessageModel>> watchMessages(
    String chatId, {
    int limit = AppConstants.messagePageSize,
  }) {
    return _messages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromDoc(d, chatId)).toList());
  }

  /// Loads an older page of messages for pagination, before [beforeDoc].
  Future<List<MessageModel>> loadMoreMessages(
    String chatId, {
    required DateTime before,
    int limit = AppConstants.messagePageSize,
  }) async {
    final snap = await _messages(chatId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs.map((d) => MessageModel.fromDoc(d, chatId)).toList();
  }

  Future<MessageModel> sendMessage({
    required String chatId,
    required String senderId,
    required MessageType type,
    String text = '',
    String? mediaUrl,
    String? mediaThumbUrl,
    String? fileName,
    int? fileSizeBytes,
    int? voiceDurationMs,
    String? replyToMessageId,
    String? replyToPreview,
    String? replyToSenderName,
    required List<String> participantIds,
  }) async {
    final DocumentReference<Map<String, dynamic>> msgRef = _messages(chatId).doc();

    final MessageModel message = MessageModel(
      id: msgRef.id,
      chatId: chatId,
      senderId: senderId,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      mediaThumbUrl: mediaThumbUrl,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      voiceDurationMs: voiceDurationMs,
      deliveredTo: [senderId],
      readBy: [senderId],
      replyToMessageId: replyToMessageId,
      replyToPreview: replyToPreview,
      replyToSenderName: replyToSenderName,
    );

    final String previewText = _previewFor(type, text, fileName);

    try {
      final WriteBatch batch = _firestore.batch();
      batch.set(msgRef, message.toMap());

      final Map<String, dynamic> chatUpdate = {
        'lastMessage': previewText,
        'lastMessageSenderId': senderId,
        'lastMessageType': type.name,
        'lastMessageAt': FieldValue.serverTimestamp(),
      };
      for (final uid in participantIds) {
        if (uid == senderId) {
          chatUpdate['unreadCounts.$uid'] = 0;
        } else {
          chatUpdate['unreadCounts.$uid'] = FieldValue.increment(1);
        }
      }
      batch.update(_chats.doc(chatId), chatUpdate);
      await batch.commit();

      return message;
    } catch (e) {
      throw const FirestoreException('Message failed to send.');
    }
  }

  String _previewFor(MessageType type, String text, String? fileName) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.file:
        return '📎 ${fileName ?? 'File'}';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.system:
        return text;
      case MessageType.text:
        return text;
    }
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _messages(chatId).doc(messageId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _messages(chatId).doc(messageId).update({
      'isDeleted': true,
      'text': '',
      'mediaUrl': null,
    });
  }

  Future<void> markAsDelivered(String chatId, String messageId, String uid) async {
    await _messages(chatId).doc(messageId).update({
      'deliveredTo': FieldValue.arrayUnion([uid]),
    }).catchError((_) {});
  }

  /// Marks every unread message in [chatId] as read by [uid] and resets
  /// their unread counter. Batches in chunks of 400 to stay under
  /// Firestore's 500-write batch limit.
  ///
  /// Firestore has no server-side "array does not contain" query, so we
  /// fetch the most recent page of messages (bounded by [recentWindow])
  /// and filter the `readBy` membership check client-side. This is O(1)
  /// reads relative to chat length rather than scanning the full history,
  /// which is the right trade-off since users only ever need to catch up
  /// on recent activity.
  Future<void> markChatAsRead(
    String chatId,
    String uid, {
    int recentWindow = 200,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> recent = await _messages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(recentWindow)
        .get();

    final WriteBatch batch = _firestore.batch();
    int pendingWrites = 0;

    for (final doc in recent.docs) {
      final List<dynamic> readBy =
          (doc.data()['readBy'] as List<dynamic>?) ?? const [];
      if (!readBy.contains(uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        });
        pendingWrites++;
        // Stay comfortably under Firestore's 500-operation batch limit
        // even after adding the trailing unreadCounts reset below.
        if (pendingWrites >= 498) break;
      }
    }

    batch.update(_chats.doc(chatId), {'unreadCounts.$uid': 0});

    try {
      await batch.commit();
    } catch (_) {
      // Best-effort: read receipts are not safety-critical, so a failed
      // batch (e.g. transient offline state) should not surface to the UI.
    }
  }

  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required String uid,
    required bool add,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        _messages(chatId).doc(messageId);
    await ref.update({
      'reactions.$emoji': add
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  // ---------------------------------------------------------------------
  // Typing indicators
  // ---------------------------------------------------------------------

  Stream<List<TypingStatusModel>> watchTyping(String chatId, {String? excludeUid}) {
    return _typing(chatId).snapshots().map((snap) {
      return snap.docs
          .map(TypingStatusModel.fromDoc)
          .where((t) => t.uid != excludeUid && t.isTyping && !t.isStale)
          .toList();
    });
  }

  Future<void> setTyping(String chatId, String uid, bool isTyping) async {
    final doc = _typing(chatId).doc(uid);
    if (isTyping) {
      await doc.set({
        'isTyping': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    } else {
      await doc.delete().catchError((_) {});
    }
  }
}
