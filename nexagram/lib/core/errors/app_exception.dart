/// Base class for all app-level exceptions.
///
/// Services throw these instead of leaking raw platform/Firebase
/// exceptions into the UI layer. Providers catch them and expose a
/// human-readable [message] to widgets.
abstract class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});

  factory AuthException.fromFirebaseCode(String code) {
    switch (code) {
      case 'user-not-found':
        return const AuthException(
          'No account found with this email.',
          code: 'user-not-found',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthException(
          'Incorrect email or password.',
          code: 'wrong-password',
        );
      case 'email-already-in-use':
        return const AuthException(
          'An account already exists with this email.',
          code: 'email-already-in-use',
        );
      case 'weak-password':
        return const AuthException(
          'Password should be at least 6 characters.',
          code: 'weak-password',
        );
      case 'invalid-email':
        return const AuthException(
          'That email address looks invalid.',
          code: 'invalid-email',
        );
      case 'too-many-requests':
        return const AuthException(
          'Too many attempts. Please try again later.',
          code: 'too-many-requests',
        );
      case 'network-request-failed':
        return const AuthException(
          'Network error. Check your connection and try again.',
          code: 'network-request-failed',
        );
      case 'user-disabled':
        return const AuthException(
          'This account has been disabled.',
          code: 'user-disabled',
        );
      default:
        return AuthException('Authentication failed ($code).', code: code);
    }
  }
}

class FirestoreException extends AppException {
  const FirestoreException(super.message, {super.code});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code = 'network-unavailable',
  });
}
