import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/typing_status_model.dart';

/// Handles everything around `public.chats` — conversation metadata, the
/// `public.messages` table, typing indicators, reactions, and
/// read/delivery receipts.
class ChatService {
  ChatService({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  sb.SupabaseQueryBuilder get _chats => _client.from(SupabaseTables.chats);

  sb.SupabaseQueryBuilder get _messages => _client.from(SupabaseTables.messages);

  sb.SupabaseQueryBuilder get _typing => _client.from(SupabaseTables.typingStatus);

  // ---------------------------------------------------------------------
  // Chat list & metadata
  // ---------------------------------------------------------------------

  /// Live list of chats the given user participates in, most-recent first.
  ///
  /// Realtime's `.stream()` can't filter on "array contains", so this
  /// streams every row change and filters/sorts client-side — fine at the
  /// scale a single user's chat list operates at (Firestore's
  /// `arrayContains` query did the equivalent filtering server-side, but
  /// the client-visible result is identical).
  Stream<List<ChatModel>> watchUserChats(String uid) {
    return _client
        .from(SupabaseTables.chats)
        .stream(primaryKey: ['id'])
        .map((rows) {
          final List<ChatModel> chats = rows
              .map(ChatModel.fromMap)
              .where((c) => c.participantIds.contains(uid))
              .toList()
            ..sort((a, b) {
              final DateTime aAt = a.lastMessageAt ?? DateTime(0);
              final DateTime bAt = b.lastMessageAt ?? DateTime(0);
              return bAt.compareTo(aAt);
            });
          return chats;
        });
  }

  Stream<ChatModel?> watchChat(String chatId) {
    return _client
        .from(SupabaseTables.chats)
        .stream(primaryKey: ['id'])
        .eq('id', chatId)
        .map((rows) => rows.isEmpty ? null : ChatModel.fromMap(rows.first));
  }

  Future<ChatModel?> getChat(String chatId) async {
    final Map<String, dynamic>? row =
        await _chats.select().eq('id', chatId).maybeSingle();
    return row != null ? ChatModel.fromMap(row) : null;
  }

  /// Gets-or-creates the deterministic 1:1 chat between two users.
  Future<ChatModel> getOrCreatePrivateChat(
    String myUid,
    String otherUid,
  ) async {
    final String chatId = ChatModel.privateChatId(myUid, otherUid);

    final Map<String, dynamic>? existing =
        await _chats.select().eq('id', chatId).maybeSingle();
    if (existing != null) {
      return ChatModel.fromMap(existing);
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
      // Upsert rather than insert: if two clients race to open the same
      // 1:1 chat at once, the deterministic id means the second write
      // just no-ops onto the same row instead of erroring.
      final Map<String, dynamic> row = await _chats
          .upsert({'id': chatId, ...chat.toMap()}, onConflict: 'id')
          .select()
          .single();
      return ChatModel.fromMap(row);
    } on sb.PostgrestException catch (_) {
      throw const DatabaseException('Could not start the conversation.');
    }
  }

  Future<ChatModel> createGroupChat({
    required String creatorUid,
    required String groupName,
    required List<String> memberUids,
    String? avatarUrl,
  }) async {
    final List<String> participants = {creatorUid, ...memberUids}.toList();

    final ChatModel chat = ChatModel(
      id: '', // assigned by the database default (uuid) below
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
      final Map<String, dynamic> map = chat.toMap()..['id'] = _newGroupId();
      final Map<String, dynamic> row =
          await _chats.insert(map).select().single();
      return ChatModel.fromMap(row);
    } on sb.PostgrestException catch (_) {
      throw const DatabaseException('Could not create the group.');
    }
  }

  /// Generates a unique id for a new group chat. Private chats use the
  /// deterministic `uidA_uidB` scheme instead (see [ChatModel.privateChatId]);
  /// groups just need any collision-free string, so a timestamp + random
  /// suffix is enough without pulling in a uuid package dependency here.
  String _newGroupId() {
    final int rand = DateTime.now().microsecondsSinceEpoch % 1000000;
    return 'grp_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

  Future<void> updateGroupInfo(
    String chatId, {
    String? groupName,
    String? groupAvatarUrl,
  }) async {
    final Map<String, dynamic> updates = {};
    if (groupName != null) updates['group_name'] = groupName;
    if (groupAvatarUrl != null) updates['group_avatar_url'] = groupAvatarUrl;
    if (updates.isEmpty) return;
    await _chats.update(updates).eq('id', chatId);
  }

  /// Adds [uid] to the group and drops a system message into the chat so
  /// existing members see how the new person joined.
  ///
  /// The stored text is a small encoded payload (see
  /// [SystemMessageCodec.encodeMemberAdded]) rather than a single fixed
  /// string, because who gets credited differs by who is reading it:
  /// - The person who was just added sees "{adderName} added you to the
  ///   group".
  /// - Everyone else sees "{addedName} joined the group".
  /// [MessageBubble] decodes and picks the right phrasing per-viewer at
  /// render time; this keeps a single row/event in `public.messages`
  /// instead of writing one differently-worded system message per member.
  Future<void> addGroupMember(
    String chatId,
    String uid, {
    String? addedByUid,
    String? addedByName,
    String? newMemberName,
  }) async {
    final chat = await getChat(chatId);
    if (chat == null) return;
    final participants = {...chat.participantIds, uid}.toList();
    final unread = {...chat.unreadCounts, uid: chat.unreadCounts[uid] ?? 0};
    await _chats.update({
      'participant_ids': participants,
      'unread_counts': unread,
    }).eq('id', chatId);

    if (addedByUid != null && addedByName != null && newMemberName != null) {
      try {
        await sendMessage(
          chatId: chatId,
          senderId: addedByUid,
          type: MessageType.system,
          text: SystemMessageCodec.encodeMemberAdded(
            adderUid: addedByUid,
            adderName: addedByName,
            addedUid: uid,
            addedName: newMemberName,
          ),
          participantIds: participants,
        );
      } catch (_) {
        // A missing system message is not worth failing the add for.
      }
    }
  }

  Future<void> removeGroupMember(String chatId, String uid) async {
    final chat = await getChat(chatId);
    if (chat == null) return;
    final participants = chat.participantIds.where((id) => id != uid).toList();
    final admins = chat.groupAdminIds.where((id) => id != uid).toList();
    await _chats.update({
      'participant_ids': participants,
      'group_admin_ids': admins,
    }).eq('id', chatId);
  }

  Future<void> toggleMute(String chatId, String uid, bool mute) async {
    final chat = await getChat(chatId);
    if (chat == null) return;
    final muted = mute
        ? {...chat.mutedBy, uid}.toList()
        : chat.mutedBy.where((id) => id != uid).toList();
    await _chats.update({'muted_by': muted}).eq('id', chatId);
  }

  Future<void> togglePin(String chatId, String uid, bool pin) async {
    final chat = await getChat(chatId);
    if (chat == null) return;
    final pinned = pin
        ? {...chat.pinnedBy, uid}.toList()
        : chat.pinnedBy.where((id) => id != uid).toList();
    await _chats.update({'pinned_by': pinned}).eq('id', chatId);
  }

  Future<void> deleteChat(String chatId) async {
    // Message cleanup is automatic: `messages.chat_id` has
    // `on delete cascade` against `chats.id` (see supabase_schema.sql), so
    // no separate server-side function/trigger is needed the way
    // Firestore needed a Cloud Function for recursive sub-collection
    // deletes.
    await _chats.delete().eq('id', chatId);
  }

  // ---------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------

  /// Live page of most-recent messages, newest first (index 0 = newest).
  Stream<List<MessageModel>> watchMessages(
    String chatId, {
    int limit = AppConstants.messagePageSize,
  }) {
    return _client
        .from(SupabaseTables.messages)
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map(MessageModel.fromMap).toList());
  }

  /// Loads an older page of messages for pagination, before [before].
  Future<List<MessageModel>> loadMoreMessages(
    String chatId, {
    required DateTime before,
    int limit = AppConstants.messagePageSize,
  }) async {
    final List<Map<String, dynamic>> rows = await _messages
        .select()
        .eq('chat_id', chatId)
        .lt('created_at', before.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(MessageModel.fromMap).toList();
  }

  /// Sends a message and atomically updates the parent chat's preview
  /// fields + per-participant unread counters via the `send_message` RPC
  /// (see `supabase_schema.sql`) — the equivalent of the old Firestore
  /// `WriteBatch` used here.
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
    final String previewText = _previewFor(type, text, fileName);

    try {
      final dynamic row = await _client.rpc(
        SupabaseRpc.sendMessage,
        params: {
          'p_chat_id': chatId,
          'p_sender_id': senderId,
          'p_type': type.name,
          'p_text': text,
          'p_media_url': mediaUrl,
          'p_media_thumb_url': mediaThumbUrl,
          'p_file_name': fileName,
          'p_file_size_bytes': fileSizeBytes,
          'p_voice_duration_ms': voiceDurationMs,
          'p_reply_to_message_id': replyToMessageId,
          'p_reply_to_preview': replyToPreview,
          'p_reply_to_sender_name': replyToSenderName,
          'p_preview_text': previewText,
        },
      );
      return MessageModel.fromMap(row as Map<String, dynamic>);
    } on sb.PostgrestException catch (_) {
      throw const DatabaseException('Message failed to send.');
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
        // `text` may be a SystemMessageCodec-encoded "member added" payload
        // (control-character marker + packed fields), not human-readable.
        // The chat-list preview and notifications are viewer-agnostic (one
        // shared `chats.last_message` value for everyone), so we can't pick
        // the per-viewer phrasing [MessageBubble] uses — fall back to a
        // neutral, always-correct summary instead of leaking the raw
        // encoded bytes into the UI.
        final MemberAddedEvent? event =
            SystemMessageCodec.decodeMemberAdded(text);
        if (event != null) {
          return '${event.addedName} added to the group';
        }
        return text;
      case MessageType.text:
        return text;
    }
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _messages.update({
      'text': newText,
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _messages.update({
      'is_deleted': true,
      'text': '',
      'media_url': null,
    }).eq('id', messageId);
  }

  Future<void> markAsDelivered(String chatId, String messageId, String uid) async {
    try {
      final Map<String, dynamic>? row = await _messages
          .select('delivered_to')
          .eq('id', messageId)
          .maybeSingle();
      if (row == null) return;
      final List<String> delivered =
          List<String>.from((row['delivered_to'] as List<dynamic>?) ?? const []);
      if (delivered.contains(uid)) return;
      await _messages
          .update({'delivered_to': [...delivered, uid]}).eq('id', messageId);
    } catch (_) {
      // Best-effort, same as the old Firestore call.
    }
  }

  /// Marks every unread message in [chatId] as read by [uid] and resets
  /// their unread counter, via the `mark_chat_as_read` RPC (see
  /// `supabase_schema.sql`) — the equivalent of the old batched Firestore
  /// write, done server-side in one round trip instead of N client writes.
  Future<void> markChatAsRead(
    String chatId,
    String uid, {
    int recentWindow = 200,
  }) async {
    try {
      await _client.rpc(
        SupabaseRpc.markChatAsRead,
        params: {
          'p_chat_id': chatId,
          'p_uid': uid,
          'p_recent_window': recentWindow,
        },
      );
    } catch (_) {
      // Best-effort: read receipts are not safety-critical, so a failed
      // call (e.g. transient offline state) should not surface to the UI.
    }
  }

  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required String uid,
    required bool add,
  }) async {
    await _client.rpc(
      SupabaseRpc.toggleReaction,
      params: {
        'p_message_id': messageId,
        'p_emoji': emoji,
        'p_uid': uid,
        'p_add': add,
      },
    );
  }

  // ---------------------------------------------------------------------
  // Typing indicators
  // ---------------------------------------------------------------------

  Stream<List<TypingStatusModel>> watchTyping(String chatId, {String? excludeUid}) {
    return _client
        .from(SupabaseTables.typingStatus)
        .stream(primaryKey: ['chat_id', 'user_id'])
        .eq('chat_id', chatId)
        .map((rows) {
          return rows
              .map(TypingStatusModel.fromMap)
              .where((t) => t.uid != excludeUid && t.isTyping && !t.isStale)
              .toList();
        });
  }

  Future<void> setTyping(String chatId, String uid, bool isTyping) async {
    if (isTyping) {
      await _typing.upsert({
        'chat_id': chatId,
        'user_id': uid,
        'is_typing': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'chat_id,user_id').catchError((_) => <Map<String, dynamic>>[]);
    } else {
      await _typing
          .delete()
          .eq('chat_id', chatId)
          .eq('user_id', uid)
          .catchError((_) => <Map<String, dynamic>>[]);
    }
  }
}
