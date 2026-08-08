/// Base class for all app-level exceptions.
///
/// Services throw these instead of leaking raw platform/Supabase
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

  /// Translates a Supabase GoTrue `AuthException.code` (or, for a couple
  /// of cases GoTrue doesn't give a stable code for, a fallback match on
  /// the raw message) into a user-facing message.
  factory AuthException.fromSupabaseCode(String? code, String rawMessage) {
    switch (code) {
      case 'invalid_credentials':
        return const AuthException(
          'Incorrect email or password.',
          code: 'invalid-credentials',
        );
      case 'user_not_found':
        return const AuthException(
          'No account found with this email.',
          code: 'user-not-found',
        );
      case 'user_already_exists':
      case 'email_exists':
        return const AuthException(
          'An account already exists with this email.',
          code: 'email-already-in-use',
        );
      case 'weak_password':
        return const AuthException(
          'Password should be at least 6 characters.',
          code: 'weak-password',
        );
      case 'email_address_invalid':
      case 'validation_failed':
        return const AuthException(
          'That email address looks invalid.',
          code: 'invalid-email',
        );
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return const AuthException(
          'Too many attempts. Please try again later.',
          code: 'too-many-requests',
        );
      case 'user_banned':
        return const AuthException(
          'This account has been disabled.',
          code: 'user-disabled',
        );
      default:
        // GoTrue doesn't always set a machine-readable `code`; fall back
        // to matching the raw message for the couple of cases that matter
        // most to a user (bad login, no network).
        final String lower = rawMessage.toLowerCase();
        if (lower.contains('invalid login credentials')) {
          return const AuthException(
            'Incorrect email or password.',
            code: 'invalid-credentials',
          );
        }
        if (lower.contains('network')) {
          return const AuthException(
            'Network error. Check your connection and try again.',
            code: 'network-request-failed',
          );
        }
        return AuthException(rawMessage, code: code);
    }
  }
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code});
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
