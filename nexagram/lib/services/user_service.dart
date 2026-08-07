import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/user_model.dart';

/// Handles reading/writing `users/{uid}` documents: profile edits,
/// presence (online/offline/lastSeen), and username-based search.
class UserService {
  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? UserModel.fromDoc(doc) : null,
        );
  }

  Future<UserModel?> getUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _users.doc(uid).get();
    return doc.exists ? UserModel.fromDoc(doc) : null;
  }

  Future<List<UserModel>> getUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    // Firestore whereIn caps at 30 values; chunk defensively.
    final List<UserModel> results = [];
    for (int i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30);
      final snap =
          await _users.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map(UserModel.fromDoc));
    }
    return results;
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? bio,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) {
      updates['name'] = name;
      updates['nameLower'] = name.toLowerCase();
    }
    if (bio != null) updates['bio'] = bio;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

    if (updates.isEmpty) return;

    try {
      await _users.doc(uid).update(updates);
    } catch (e) {
      throw const FirestoreException('Could not update your profile.');
    }
  }

  /// Case-insensitive prefix search across username and display name.
  ///
  /// Firestore doesn't support full-text search natively, so we rely on a
  /// classic range-query trick over lowercase-indexed fields
  /// (`usernameLower`, `nameLower`). For production-scale search, swap this
  /// for Algolia/Typesense via a Cloud Function-triggered index.
  Future<List<UserModel>> searchUsers(String query, {String? excludeUid}) async {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final List<QuerySnapshot<Map<String, dynamic>>> results = await Future.wait([
      _users
          .orderBy('usernameLower')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(AppConstants.searchResultLimit)
          .get(),
      _users
          .orderBy('nameLower')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(AppConstants.searchResultLimit)
          .get(),
    ]);

    final Map<String, UserModel> merged = {};
    for (final snap in results) {
      for (final doc in snap.docs) {
        if (doc.id == excludeUid) continue;
        merged[doc.id] = UserModel.fromDoc(doc);
      }
    }
    return merged.values.toList();
  }

  Future<void> setOnline(String uid) async {
    await _users.doc(uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Future<void> setOffline(String uid) async {
    await _users.doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Future<void> addFcmToken(String uid, String token) async {
    await _users.doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }).catchError((_) {});
  }

  Future<void> removeFcmToken(String uid, String token) async {
    await _users.doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }).catchError((_) {});
  }

  Future<void> blockUser(String uid, String blockedUid) async {
    await _users.doc(uid).update({
      'blockedUserIds': FieldValue.arrayUnion([blockedUid]),
    });
  }

  Future<void> unblockUser(String uid, String blockedUid) async {
    await _users.doc(uid).update({
      'blockedUserIds': FieldValue.arrayRemove([blockedUid]),
    });
  }
}
