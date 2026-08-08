import 'package:equatable/equatable.dart';

/// The kind of payload a [MessageModel] carries.
enum MessageType { text, image, file, voice, system }

/// Per-recipient delivery lifecycle. For group chats, a message is
/// considered "read" once every member has read it; the raw per-user
/// read/delivered lists live in [MessageModel.readBy] / [MessageModel.deliveredTo].
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

/// Encodes/decodes the small structured payload stored in
/// [MessageModel.text] for [MessageType.system] "member added" events.
///
/// Who gets credited in a "so-and-so added so-and-so" system message
/// depends on who's reading it (the person just added sees "{adder} added
/// you", everyone else sees "{added} joined"), but `public.messages` only
/// stores one row per event. Rather than adding a dedicated column (which
/// would need a schema migration this app can't safely run for the user),
/// the four pieces of data the two phrasings need — both uids and both
/// display names — are packed into `text` behind a private-use marker
/// that ordinary message text will never contain, and unpacked again by
/// [MessageBubble] at render time. If a text can't be decoded (e.g. an
/// older/plain system message), callers should just display it as-is.
class SystemMessageCodec {
  SystemMessageCodec._();

  static const String _marker = '\u0002MEMBER_ADDED\u0002';
  static const String _sep = '\u0003';

  static String encodeMemberAdded({
    required String adderUid,
    required String adderName,
    required String addedUid,
    required String addedName,
  }) {
    return '$_marker$adderUid$_sep$adderName$_sep$addedUid$_sep$addedName';
  }

  /// Returns the decoded payload, or null if [text] isn't one of these
  /// encoded "member added" events.
  static MemberAddedEvent? decodeMemberAdded(String text) {
    if (!text.startsWith(_marker)) return null;
    final List<String> parts = text.substring(_marker.length).split(_sep);
    if (parts.length != 4) return null;
    return MemberAddedEvent(
      adderUid: parts[0],
      adderName: parts[1],
      addedUid: parts[2],
      addedName: parts[3],
    );
  }

  /// Renders the correct phrasing for [viewerUid]. Falls back to a generic
  /// join message if the event can't be decoded.
  static String displayTextFor(String text, String viewerUid) {
    final MemberAddedEvent? event = decodeMemberAdded(text);
    if (event == null) return text;
    if (viewerUid == event.addedUid) {
      return '${event.adderName} added you to the group';
    }
    return '${event.addedName} joined the group';
  }
}

class MemberAddedEvent {
  const MemberAddedEvent({
    required this.adderUid,
    required this.adderName,
    required this.addedUid,
    required this.addedName,
  });

  final String adderUid;
  final String adderName;
  final String addedUid;
  final String addedName;
}

/// A single emoji reaction summary, e.g. {"❤️": ["uid1", "uid2"]}.
typedef ReactionMap = Map<String, List<String>>;

/// A chat message, stored at `public.messages` in Supabase Postgres
/// (`chat_id` foreign key replaces the old `chats/{chatId}/messages`
/// sub-collection).
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

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      senderId: (map['sender_id'] as String?) ?? '',
      type: messageTypeFromString(map['type'] as String?),
      text: (map['text'] as String?) ?? '',
      mediaUrl: map['media_url'] as String?,
      mediaThumbUrl: map['media_thumb_url'] as String?,
      fileName: map['file_name'] as String?,
      fileSizeBytes: map['file_size_bytes'] as int?,
      voiceDurationMs: map['voice_duration_ms'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : null,
      editedAt: map['edited_at'] != null
          ? DateTime.parse(map['edited_at'] as String).toLocal()
          : null,
      readBy: List<String>.from((map['read_by'] as List<dynamic>?) ?? const []),
      deliveredTo:
          List<String>.from((map['delivered_to'] as List<dynamic>?) ?? const []),
      reactions: _decodeReactions(map['reactions']),
      replyToMessageId: map['reply_to_message_id'] as String?,
      replyToPreview: map['reply_to_preview'] as String?,
      replyToSenderName: map['reply_to_sender_name'] as String?,
      isDeleted: (map['is_deleted'] as bool?) ?? false,
      status: MessageStatus.sent,
    );
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
