import 'package:equatable/equatable.dart';

/// A NexaGram user profile, stored at `public.users` in Supabase Postgres.
class UserModel extends Equatable {
  const UserModel({
    required this.uid,
    required this.username,
    required this.name,
    required this.email,
    this.bio = '',
    this.phoneNumber = '',
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.fcmTokens = const [],
    this.blockedUserIds = const [],
  });

  final String uid;
  final String username; // unique, lowercase-indexed, used for search / @mentions
  final String name; // display name
  final String email;
  final String bio;
  final String phoneNumber;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final List<String> fcmTokens;
  final List<String> blockedUserIds;

  /// Builds a [UserModel] from a Supabase row (a `Map<String, dynamic>`
  /// as returned by `postgrest`/Realtime, using the table's snake_case
  /// column names).
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['id'] as String,
      username: (map['username'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      bio: (map['bio'] as String?) ?? '',
      phoneNumber: (map['phone_number'] as String?) ?? '',
      avatarUrl: map['avatar_url'] as String?,
      isOnline: (map['is_online'] as bool?) ?? false,
      lastSeen: map['last_seen'] != null
          ? DateTime.parse(map['last_seen'] as String).toLocal()
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : null,
      fcmTokens: List<String>.from(
        (map['fcm_tokens'] as List<dynamic>?) ?? const [],
      ),
      blockedUserIds: List<String>.from(
        (map['blocked_user_ids'] as List<dynamic>?) ?? const [],
      ),
    );
  }

  /// Fields for an insert/upsert into `public.users`. `id` is supplied
  /// separately by the caller (it's the Supabase Auth uid, set once at
  /// sign-up and never re-sent on updates).
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'name': name,
      'email': email,
      'bio': bio,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
      'last_seen': lastSeen?.toUtc().toIso8601String(),
      'fcm_tokens': fcmTokens,
      'blocked_user_ids': blockedUserIds,
    };
  }

  UserModel copyWith({
    String? username,
    String? name,
    String? email,
    String? bio,
    String? phoneNumber,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    List<String>? fcmTokens,
    List<String>? blockedUserIds,
  }) {
    return UserModel(
      uid: uid,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }

  String get initials {
    final String source = name.trim().isNotEmpty ? name : username;
    if (source.isEmpty) return '?';
    final List<String> parts = source.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  List<Object?> get props => [
        uid,
        username,
        name,
        email,
        bio,
        phoneNumber,
        avatarUrl,
        isOnline,
        lastSeen,
        createdAt,
        fcmTokens,
        blockedUserIds,
      ];
}
