import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Ephemeral typing indicator, stored at `chats/{chatId}/typing/{uid}`.
///
/// Documents are written with a short TTL semantics: the client refreshes
/// [updatedAt] every keystroke (debounced) and clears the doc when the user
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

  factory TypingStatusModel.fromMap(Map<String, dynamic> map, String uid) {
    return TypingStatusModel(
      uid: uid,
      isTyping: (map['isTyping'] as bool?) ?? false,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory TypingStatusModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return TypingStatusModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'isTyping': isTyping,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isStale {
    if (updatedAt == null) return true;
    return DateTime.now().difference(updatedAt!) >
        const Duration(seconds: 6);
  }

  @override
  List<Object?> get props => [uid, isTyping, updatedAt];
}
