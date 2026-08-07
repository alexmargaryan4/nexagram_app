import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// The kind of payload a [MessageModel] carries.
enum MessageType { text, image, file, voice, system }

/// Per-recipient delivery lifecycle. For group chats, a message is
/// considered "read" once every member has read it; the raw per-user
/// read/delivered maps live in [MessageModel.readBy] / [MessageModel.deliveredTo].
enum MessageStatus { sending, sent, delivered, read, failed }

MessageType messageTypeFromString(String? value) {
  switch (value) {
    case 'image':
      return MessageType.image;
    case 'file':
      return MessageType.file;
    case 'voice':
      return MessageType.voice;
    case 'system':
      return MessageType.system;
    case 'text':
    default:
      return MessageType.text;
  }
}

/// A single emoji reaction summary, e.g. {"❤️": ["uid1", "uid2"]}.
typedef ReactionMap = Map<String, List<String>>;

/// A chat message, stored at `chats/{chatId}/messages/{messageId}`.
class MessageModel extends Equatable {
  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.text = '',
    this.mediaUrl,
    this.mediaThumbUrl,
    this.fileName,
    this.fileSizeBytes,
    this.voiceDurationMs,
    this.createdAt,
    this.editedAt,
    this.readBy = const [],
    this.deliveredTo = const [],
    this.reactions = const {},
    this.replyToMessageId,
    this.replyToPreview,
    this.replyToSenderName,
    this.isDeleted = false,
    this.status = MessageStatus.sent,
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String text;
  final String? mediaUrl;
  final String? mediaThumbUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final int? voiceDurationMs;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final List<String> readBy;
  final List<String> deliveredTo;
  final ReactionMap reactions;
  final String? replyToMessageId;
  final String? replyToPreview;
  final String? replyToSenderName;
  final bool isDeleted;
  final MessageStatus status;

  factory MessageModel.fromMap(
    Map<String, dynamic> map,
    String id,
    String chatId,
  ) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: (map['senderId'] as String?) ?? '',
      type: messageTypeFromString(map['type'] as String?),
      text: (map['text'] as String?) ?? '',
      mediaUrl: map['mediaUrl'] as String?,
      mediaThumbUrl: map['mediaThumbUrl'] as String?,
      fileName: map['fileName'] as String?,
      fileSizeBytes: map['fileSizeBytes'] as int?,
      voiceDurationMs: map['voiceDurationMs'] as int?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      editedAt: (map['editedAt'] as Timestamp?)?.toDate(),
      readBy: List<String>.from((map['readBy'] as List<dynamic>?) ?? const []),
      deliveredTo:
          List<String>.from((map['deliveredTo'] as List<dynamic>?) ?? const []),
      reactions: _decodeReactions(map['reactions']),
      replyToMessageId: map['replyToMessageId'] as String?,
      replyToPreview: map['replyToPreview'] as String?,
      replyToSenderName: map['replyToSenderName'] as String?,
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      status: MessageStatus.sent,
    );
  }

  factory MessageModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String chatId,
  ) {
    return MessageModel.fromMap(doc.data() ?? {}, doc.id, chatId);
  }

  static ReactionMap _decodeReactions(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(
        key as String,
        List<String>.from((value as List<dynamic>?) ?? const []),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'type': type.name,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaThumbUrl': mediaThumbUrl,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'voiceDurationMs': voiceDurationMs,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'readBy': readBy,
      'deliveredTo': deliveredTo,
      'reactions': reactions,
      'replyToMessageId': replyToMessageId,
      'replyToPreview': replyToPreview,
      'replyToSenderName': replyToSenderName,
      'isDeleted': isDeleted,
    };
  }

  bool isReadBy(String uid) => readBy.contains(uid);

  bool get hasReactions => reactions.values.any((u) => u.isNotEmpty);

  int get totalReactionCount =>
      reactions.values.fold(0, (sum, users) => sum + users.length);

  MessageModel copyWith({
    String? text,
    List<String>? readBy,
    List<String>? deliveredTo,
    ReactionMap? reactions,
    bool? isDeleted,
    MessageStatus? status,
    DateTime? editedAt,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      type: type,
      text: text ?? this.text,
      mediaUrl: mediaUrl,
      mediaThumbUrl: mediaThumbUrl,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      voiceDurationMs: voiceDurationMs,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      readBy: readBy ?? this.readBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      reactions: reactions ?? this.reactions,
      replyToMessageId: replyToMessageId,
      replyToPreview: replyToPreview,
      replyToSenderName: replyToSenderName,
      isDeleted: isDeleted ?? this.isDeleted,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        type,
        text,
        mediaUrl,
        mediaThumbUrl,
        fileName,
        fileSizeBytes,
        voiceDurationMs,
        createdAt,
        editedAt,
        readBy,
        deliveredTo,
        reactions,
        replyToMessageId,
        isDeleted,
        status,
      ];
}
