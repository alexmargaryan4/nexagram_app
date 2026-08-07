import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A NexaGram user profile, stored at `users/{uid}` in Firestore.
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
  final String username; // unique, lowercase, used for search / @mentions
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

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      username: (map['username'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      bio: (map['bio'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      fcmTokens: List<String>.from(
        (map['fcmTokens'] as List<dynamic>?) ?? const [],
      ),
      blockedUserIds: List<String>.from(
        (map['blockedUserIds'] as List<dynamic>?) ?? const [],
      ),
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'usernameLower': username.toLowerCase(),
      'name': name,
      'nameLower': name.toLowerCase(),
      'email': email,
      'bio': bio,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'fcmTokens': fcmTokens,
      'blockedUserIds': blockedUserIds,
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
