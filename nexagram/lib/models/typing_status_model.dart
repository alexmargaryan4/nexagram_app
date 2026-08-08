import 'package:equatable/equatable.dart';

/// Ephemeral typing indicator, stored at `public.typing_status` in
/// Supabase Postgres (composite key `(chat_id, user_id)`, replacing the
/// old `chats/{chatId}/typing/{uid}` sub-collection).
///
/// Rows are written with a short TTL semantics: the client refreshes
/// [updatedAt] every keystroke (debounced) and clears the row when the user
/// stops typing or sends the message. Readers additionally treat any
/// timestamp older than [AppConstants.typingTimeout] as stale, guarding
/// against a client that disconnected mid-type.
class TypingStatusModel extends Equatable {
  const TypingStatusModel({
    required this.uid,
    required this.isTyping,
    this.updatedAt,
  });

  final String uid;
  final bool isTyping;
  final DateTime? updatedAt;

  factory TypingStatusModel.fromMap(Map<String, dynamic> map) {
    return TypingStatusModel(
      uid: map['user_id'] as String,
      isTyping: (map['is_typing'] as bool?) ?? false,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String).toLocal()
          : null,
    );
  }

  bool get isStale {
    if (updatedAt == null) return true;
    return DateTime.now().difference(updatedAt!) >
        const Duration(seconds: 6);
  }

  @override
  List<Object?> get props => [uid, isTyping, updatedAt];
}
