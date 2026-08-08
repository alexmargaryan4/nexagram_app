import 'package:equatable/equatable.dart';
import 'message_model.dart';

enum ChatType { private, group }

ChatType chatTypeFromString(String? value) =>
    value == 'group' ? ChatType.group : ChatType.private;

/// A chat/conversation, stored at `public.chats` in Supabase Postgres.
///
/// For [ChatType.private] chats, `participantIds` always has exactly two
/// entries and `id` is deterministically derived from the sorted UIDs so a
/// duplicate 1:1 chat can never be created (see ChatService).
class ChatModel extends Equatable {
  const ChatModel({
    required this.id,
    required this.type,
    required this.participantIds,
    this.groupName,
    this.groupAvatarUrl,
    this.groupAdminIds = const [],
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageType,
    this.lastMessageAt,
    this.unreadCounts = const {},
    this.createdAt,
    this.createdBy,
    this.mutedBy = const [],
    this.pinnedBy = const [],
  });

  final String id;
  final ChatType type;
  final List<String> participantIds;
  final String? groupName;
  final String? groupAvatarUrl;
  final List<String> groupAdminIds;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final MessageType? lastMessageType;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts;
  final DateTime? createdAt;
  final String? createdBy;
  final List<String> mutedBy;
  final List<String> pinnedBy;

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] as String,
      type: chatTypeFromString(map['type'] as String?),
      participantIds:
          List<String>.from((map['participant_ids'] as List<dynamic>?) ?? const []),
      groupName: map['group_name'] as String?,
      groupAvatarUrl: map['group_avatar_url'] as String?,
      groupAdminIds:
          List<String>.from((map['group_admin_ids'] as List<dynamic>?) ?? const []),
      lastMessage: map['last_message'] as String?,
      lastMessageSenderId: map['last_message_sender_id'] as String?,
      lastMessageType: map['last_message_type'] != null
          ? messageTypeFromString(map['last_message_type'] as String?)
          : null,
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.parse(map['last_message_at'] as String).toLocal()
          : null,
      unreadCounts: (map['unread_counts'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ??
          const {},
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : null,
      createdBy: map['created_by'] as String?,
      mutedBy: List<String>.from((map['muted_by'] as List<dynamic>?) ?? const []),
      pinnedBy: List<String>.from((map['pinned_by'] as List<dynamic>?) ?? const []),
    );
  }

  /// Fields for inserting a new row into `public.chats`. `id` is supplied
  /// separately by the caller.
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'participant_ids': participantIds,
      'group_name': groupName,
      'group_avatar_url': groupAvatarUrl,
      'group_admin_ids': groupAdminIds,
      'last_message': lastMessage,
      'last_message_sender_id': lastMessageSenderId,
      'last_message_type': lastMessageType?.name,
      'unread_counts': unreadCounts,
      'created_by': createdBy,
      'muted_by': mutedBy,
      'pinned_by': pinnedBy,
    };
  }

  int unreadCountFor(String uid) => unreadCounts[uid] ?? 0;

  bool isMutedBy(String uid) => mutedBy.contains(uid);

  bool isPinnedBy(String uid) => pinnedBy.contains(uid);

  /// For private chats, returns the UID of "the other person".
  String? otherParticipantId(String myUid) {
    if (type != ChatType.private) return null;
    return participantIds.firstWhere(
      (id) => id != myUid,
      orElse: () => '',
    );
  }

  /// Deterministic chat id for a 1:1 conversation between two users, so
  /// creating a chat is idempotent regardless of who initiates it.
  static String privateChatId(String uidA, String uidB) {
    final List<String> sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  ChatModel copyWith({
    String? groupName,
    String? groupAvatarUrl,
    List<String>? groupAdminIds,
    String? lastMessage,
    String? lastMessageSenderId,
    MessageType? lastMessageType,
    DateTime? lastMessageAt,
    Map<String, int>? unreadCounts,
    List<String>? mutedBy,
    List<String>? pinnedBy,
  }) {
    return ChatModel(
      id: id,
      type: type,
      participantIds: participantIds,
      groupName: groupName ?? this.groupName,
      groupAvatarUrl: groupAvatarUrl ?? this.groupAvatarUrl,
      groupAdminIds: groupAdminIds ?? this.groupAdminIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      createdAt: createdAt,
      createdBy: createdBy,
      mutedBy: mutedBy ?? this.mutedBy,
      pinnedBy: pinnedBy ?? this.pinnedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        participantIds,
        groupName,
        groupAvatarUrl,
        groupAdminIds,
        lastMessage,
        lastMessageSenderId,
        lastMessageType,
        lastMessageAt,
        unreadCounts,
        mutedBy,
        pinnedBy,
      ];
}
