import 'package:equatable/equatable.dart';

/// A saved contact relationship, stored at `public.contacts` in Supabase
/// Postgres (`owner_uid` + `contact_uid` composite primary key, replacing
/// the old `users/{ownerUid}/contacts/{contactUid}` sub-collection).
///
/// We keep this as a thin pointer + denormalized display fields rather than
/// duplicating the full [UserModel], so contact list rendering doesn't
/// require a join, but the source of truth for profile edits stays on the
/// `public.users` row.
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

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      contactUid: map['contact_uid'] as String,
      username: (map['username'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      avatarUrl: map['avatar_url'] as String?,
      addedAt: map['added_at'] != null
          ? DateTime.parse(map['added_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contact_uid': contactUid,
      'username': username,
      'name': name,
      'avatar_url': avatarUrl,
    };
  }

  @override
  List<Object?> get props => [contactUid, username, name, avatarUrl, addedAt];
}
