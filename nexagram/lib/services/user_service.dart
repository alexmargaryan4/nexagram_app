import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/user_model.dart';

/// Handles reading/writing `public.users` rows: profile edits, presence
/// (online/offline/lastSeen), and username-based search.
class UserService {
  UserService({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  sb.SupabaseQueryBuilder get _users => _client.from(SupabaseTables.users);

  /// Live updates for a single user's profile row. Mirrors the old
  /// Firestore `.doc(uid).snapshots()` behaviour: emits the current row
  /// immediately, then again on every change, and `null` if the row is
  /// deleted (e.g. account deletion).
  Stream<UserModel?> watchUser(String uid) {
    return _client
        .from(SupabaseTables.users)
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : UserModel.fromMap(rows.first));
  }

  Future<UserModel?> getUser(String uid) async {
    final Map<String, dynamic>? row =
        await _users.select().eq('id', uid).maybeSingle();
    return row != null ? UserModel.fromMap(row) : null;
  }

  Future<List<UserModel>> getUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    final List<Map<String, dynamic>> rows =
        await _users.select().inFilter('id', uids);
    return rows.map(UserModel.fromMap).toList();
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? bio,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (bio != null) updates['bio'] = bio;
    if (phoneNumber != null) updates['phone_number'] = phoneNumber;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isEmpty) return;

    try {
      await _users.update(updates).eq('id', uid);
    } on sb.PostgrestException catch (e) {
      throw DatabaseException('Could not update your profile.', code: e.code);
    }
  }

  /// Case-insensitive prefix search across username and display name, via
  /// the `search_users` RPC (see `supabase_schema.sql`) — replaces the old
  /// two-query Firestore range-scan trick.
  Future<List<UserModel>> searchUsers(String query, {String? excludeUid}) async {
    final String q = query.trim();
    if (q.isEmpty) return [];

    final List<dynamic> rows = await _client.rpc(
      SupabaseRpc.searchUsers,
      params: {
        'p_query': q,
        'p_exclude_uid': excludeUid,
        'p_limit': AppConstants.searchResultLimit,
      },
    );
    return rows.map((row) => UserModel.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<void> setOnline(String uid) async {
    await _users.update({
      'is_online': true,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid).catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> setOffline(String uid) async {
    await _users.update({
      'is_online': false,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid).catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> addFcmToken(String uid, String token) async {
    // Best-effort read-modify-write: push-token bookkeeping is not
    // safety-critical, and a lost race here just means a token gets
    // re-added on the next app launch.
    try {
      final user = await getUser(uid);
      if (user == null) return;
      final tokens = {...user.fcmTokens, token}.toList();
      await _users.update({'fcm_tokens': tokens}).eq('id', uid);
    } catch (_) {
      // Ignore — see note above.
    }
  }

  Future<void> removeFcmToken(String uid, String token) async {
    final user = await getUser(uid);
    if (user == null) return;
    final tokens = user.fcmTokens.where((t) => t != token).toList();
    await _users
        .update({'fcm_tokens': tokens})
        .eq('id', uid)
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> blockUser(String uid, String blockedUid) async {
    final user = await getUser(uid);
    if (user == null) return;
    final blocked = {...user.blockedUserIds, blockedUid}.toList();
    try {
      await _users.update({'blocked_user_ids': blocked}).eq('id', uid);
    } on sb.PostgrestException catch (e) {
      throw DatabaseException('Could not block user.', code: e.code);
    }
  }

  Future<void> unblockUser(String uid, String blockedUid) async {
    final user = await getUser(uid);
    if (user == null) return;
    final blocked = user.blockedUserIds.where((id) => id != blockedUid).toList();
    try {
      await _users.update({'blocked_user_ids': blocked}).eq('id', uid);
    } on sb.PostgrestException catch (e) {
      throw DatabaseException('Could not unblock user.', code: e.code);
    }
  }
}
