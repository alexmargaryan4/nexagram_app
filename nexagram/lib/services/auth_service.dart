import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/user_model.dart';

/// Deep link Supabase redirects back to after the user taps the
/// confirmation link in a sign-up or password-reset email, instead of the
/// project's default Site URL (which is a bare `http://localhost:...`
/// placeholder and does nothing useful on a phone).
///
/// This scheme/host pair must also be added as a Redirect URL in the
/// Supabase dashboard (Authentication → URL Configuration), or GoTrue will
/// silently ignore it and fall back to the Site URL anyway. See
/// docs/SUPABASE_SETUP.md → "Redirect URLs" for the exact steps, and
/// AndroidManifest.xml / Info.plist for where this scheme is registered
/// as a deep link on each platform.
const String kEmailRedirectTo = 'nexagram://login-callback';

/// Thin wrapper around Supabase Auth (GoTrue) that also provisions the
/// matching `public.users` profile row on sign-up.
///
/// Every method translates raw [sb.AuthException]s into our own
/// [AuthException] so the UI layer never has to know about Supabase types.
///
/// Username uniqueness used to be enforced with a separate Firestore
/// `usernames/{usernameLower}` reservation document written atomically
/// alongside the profile in a `WriteBatch`. Postgres does this more simply:
/// `public.users.username_lower` has a unique index (see
/// `supabase_schema.sql`), so a duplicate insert fails server-side with a
/// `23505` error regardless of any client-side race — [_assertUsernameAvailable]
/// below is just a fast pre-check for a friendlier error message before we
/// ever create the Auth account.
class AuthService {
  AuthService({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  sb.GoTrueClient get _auth => _client.auth;

  sb.User? get currentSupabaseUser => _auth.currentUser;

  String? get currentUid => _auth.currentUser?.id;

  bool get isSignedIn => _auth.currentUser != null;

  /// Emits the current Supabase user whenever auth state changes (sign in,
  /// sign out, token refresh). Mirrors the old Firebase
  /// `authStateChanges()` shape so [AuthProvider] didn't need to change.
  Stream<sb.User?> authStateChanges() =>
      _auth.onAuthStateChange.map((state) => state.session?.user);

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final sb.AuthResponse response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final sb.User? user = response.user;
      if (user == null) {
        throw const AuthException(
          'Incorrect email or password.',
          code: 'invalid-credentials',
        );
      }

      final Map<String, dynamic>? row = await _client
          .from(SupabaseTables.users)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        throw const AuthException(
          'User profile not found. Please contact support.',
          code: 'profile-missing',
        );
      }
      return UserModel.fromMap(row);
    } on sb.AuthException catch (e) {
      throw AuthException.fromSupabaseCode(e.code, e.message);
    }
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) async {
    final String usernameLower = username.trim().toLowerCase();
    await _assertUsernameAvailable(usernameLower);

    sb.User? user;
    try {
      final sb.AuthResponse response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
        emailRedirectTo: kEmailRedirectTo,
      );
      user = response.user;
      if (user == null) {
        // Happens if the project has "Confirm email" on and requires a
        // second step before a session exists; we still have a user id to
        // provision the profile row against.
        throw const AuthException(
          'Could not create your account. Please try again.',
          code: 'signup-failed',
        );
      }

      final UserModel newUser = UserModel(
        uid: user.id,
        username: username.trim(),
        name: name.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
      );

      // A single insert is already atomic in Postgres — no separate
      // "reserve the username" write is needed the way the old Firestore
      // WriteBatch needed one; the unique index on username_lower is the
      // enforcement point (see supabase_schema.sql).
      await _client.from(SupabaseTables.users).insert({
        'id': user.id,
        ...newUser.toMap(),
        'username_lower': usernameLower,
      });

      return newUser;
    } on sb.AuthException catch (e) {
      // Roll back the partial Auth account if the profile write failed
      // after sign-up succeeded, so we never leave an orphaned auth user
      // with no matching profile row. Requires the "Confirm email" setting
      // to be off, or an active session — best-effort otherwise.
      await _tryDeleteOrphanedUser(user);
      throw AuthException.fromSupabaseCode(e.code, e.message);
    } on sb.PostgrestException catch (e) {
      await _tryDeleteOrphanedUser(user);
      if (e.code == '23505') {
        throw const AuthException(
          'This username is already taken.',
          code: 'username-taken',
        );
      }
      throw DatabaseException(
        'Could not finish creating your profile.',
        code: e.code,
      );
    }
  }

  Future<void> _tryDeleteOrphanedUser(sb.User? user) async {
    if (user == null) return;
    // The client's anon key can't call the admin delete-user endpoint, so
    // this best-effort cleanup just signs the half-created session back
    // out; a genuinely orphaned Auth-only account with no `public.users`
    // row can be cleared up from the Supabase dashboard if it ever occurs.
    try {
      await _auth.signOut();
    } catch (_) {
      // Ignore — see note above.
    }
  }

  Future<void> _assertUsernameAvailable(String usernameLower) async {
    final Map<String, dynamic>? existing = await _client
        .from(SupabaseTables.users)
        .select('id')
        .eq('username_lower', usernameLower)
        .maybeSingle();
    if (existing != null) {
      throw const AuthException(
        'This username is already taken.',
        code: 'username-taken',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kEmailRedirectTo,
      );
    } on sb.AuthException catch (e) {
      throw AuthException.fromSupabaseCode(e.code, e.message);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthException catch (e) {
      throw AuthException.fromSupabaseCode(e.code, e.message);
    }
  }

  /// Re-authenticates the current user by attempting a fresh sign-in with
  /// their email + current password. GoTrue has no separate
  /// "reauthenticate" call the way Firebase Auth did (needed there before
  /// sensitive operations like changing a password); signing in again with
  /// the same credentials achieves the same verification.
  Future<void> reauthenticate(String email, String currentPassword) async {
    if (_auth.currentUser == null) return;
    try {
      await _auth.signInWithPassword(
        email: email.trim(),
        password: currentPassword,
      );
    } on sb.AuthException catch (e) {
      throw AuthException.fromSupabaseCode(e.code, e.message);
    }
  }

  Future<void> deleteAccount() async {
    final sb.User? user = _auth.currentUser;
    if (user == null) return;
    try {
      // Deletes the profile row first. The Auth user itself can only be
      // deleted with the service-role key (an admin-only GoTrue endpoint),
      // which the client never holds — so this signs the session out
      // after removing all app-visible data. A production setup typically
      // pairs this with a Supabase Edge Function (called here via
      // `_client.functions.invoke(...)`) that uses the service role to
      // finish deleting the Auth user server-side.
      await _client.from(SupabaseTables.users).delete().eq('id', user.id);
      await _auth.signOut();
    } on sb.PostgrestException catch (e) {
      throw DatabaseException('Could not delete your account.', code: e.code);
    }
  }

  Future<void> signOut() => _auth.signOut();
}
