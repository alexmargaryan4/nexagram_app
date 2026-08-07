import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/user_model.dart';

/// Thin wrapper around [FirebaseAuth] that also provisions the matching
/// Firestore `users/{uid}` profile document on sign-up.
///
/// Every method translates raw [FirebaseAuthException]s into our own
/// [AuthException] so the UI layer never has to know about Firebase types.
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentFirebaseUser => _auth.currentUser;

  String? get currentUid => _auth.currentUser?.uid;

  bool get isSignedIn => _auth.currentUser != null;

  /// Emits whenever the Firebase auth state changes (sign in / sign out).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User user = credential.user!;
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        throw const AuthException(
          'User profile not found. Please contact support.',
          code: 'profile-missing',
        );
      }
      return UserModel.fromDoc(doc);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
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

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User user = credential.user!;
      await user.updateDisplayName(name.trim());

      final UserModel newUser = UserModel(
        uid: user.uid,
        username: username.trim(),
        name: name.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
      );

      // Write the profile and reserve the username atomically.
      final WriteBatch batch = _firestore.batch();
      batch.set(
        _firestore.collection(FirestoreCollections.users).doc(user.uid),
        newUser.toMap(),
      );
      batch.set(
        _firestore.collection(FirestoreCollections.usernames).doc(usernameLower),
        {'uid': user.uid},
      );
      await batch.commit();

      return newUser;
    } on FirebaseAuthException catch (e) {
      // Roll back partial user creation if profile writes failed after auth
      // succeeded, so we never leave an orphaned Firebase Auth account.
      await credential?.user?.delete().catchError((_) {});
      throw AuthException.fromFirebaseCode(e.code);
    }
  }

  Future<void> _assertUsernameAvailable(String usernameLower) async {
    final DocumentSnapshot<Map<String, dynamic>> reserved = await _firestore
        .collection(FirestoreCollections.usernames)
        .doc(usernameLower)
        .get();
    if (reserved.exists) {
      throw const AuthException(
        'This username is already taken.',
        code: 'username-taken',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    }
  }

  Future<void> reauthenticate(String email, String currentPassword) async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    try {
      final AuthCredential cred = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    }
  }

  Future<void> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    }
  }

  Future<void> signOut() => _auth.signOut();
}
