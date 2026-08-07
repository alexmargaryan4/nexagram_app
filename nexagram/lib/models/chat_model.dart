import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'message_model.dart';

enum ChatType { private, group }

ChatType chatTypeFromString(String? value) =>
    value == 'group' ? ChatType.group : ChatType.private;

/// A chat/conversation, stored at `chats/{chatId}`.
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

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      id: id,
      type: chatTypeFromString(map['type'] as String?),
      participantIds:
          List<String>.from((map['participantIds'] as List<dynamic>?) ?? const []),
      groupName: map['groupName'] as String?,
      groupAvatarUrl: map['groupAvatarUrl'] as String?,
      groupAdminIds:
          List<String>.from((map['groupAdminIds'] as List<dynamic>?) ?? const []),
      lastMessage: map['lastMessage'] as String?,
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
      lastMessageType: map['lastMessageType'] != null
          ? messageTypeFromString(map['lastMessageType'] as String?)
          : null,
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCounts: Map<String, int>.from(
        (map['unreadCounts'] as Map<dynamic, dynamic>?) ?? const {},
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
      mutedBy: List<String>.from((map['mutedBy'] as List<dynamic>?) ?? const []),
      pinnedBy: List<String>.from((map['pinnedBy'] as List<dynamic>?) ?? const []),
    );
  }

  factory ChatModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ChatModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'participantIds': participantIds,
      'groupName': groupName,
      'groupAvatarUrl': groupAvatarUrl,
      'groupAdminIds': groupAdminIds,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageType': lastMessageType?.name,
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : FieldValue.serverTimestamp(),
      'unreadCounts': unreadCounts,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'mutedBy': mutedBy,
      'pinnedBy': pinnedBy,
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
