import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A saved contact relationship, stored at
/// `users/{ownerUid}/contacts/{contactUid}`.
///
/// We keep this as a thin pointer + denormalized display fields rather than
/// duplicating the full [UserModel], so contact list rendering doesn't
/// require a join, but the source of truth for profile edits stays on the
/// `users/{uid}` document.
class ContactModel extends Equatable {
  const ContactModel({
    required this.contactUid,
    required this.username,
    required this.name,
    this.avatarUrl,
    this.addedAt,
  });

  final String contactUid;
  final String username;
  final String name;
  final String? avatarUrl;
  final DateTime? addedAt;

  factory ContactModel.fromMap(Map<String, dynamic> map, String contactUid) {
    return ContactModel(
      contactUid: contactUid,
      username: (map['username'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      addedAt: (map['addedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ContactModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ContactModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'name': name,
      'avatarUrl': avatarUrl,
      'addedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [contactUid, username, name, avatarUrl, addedAt];
}
