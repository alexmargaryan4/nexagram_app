/// Form-field validators shared by auth and profile-editing screens.
///
/// Each returns `null` when valid, or a human-readable error string
/// suitable for direct use as a [TextFormField.validator] result.
class Validators {
  Validators._();

  static final RegExp _emailPattern =
      RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[\w\-]{2,}$');
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static String? email(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? username(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Username is required';
    if (!_usernamePattern.hasMatch(v)) {
      return '3-20 characters: letters, numbers, underscore only';
    }
    return null;
  }

  static String? name(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Name is required';
    if (v.length > 50) return 'Name is too long';
    return null;
  }

  static String? bio(String? value) {
    final String v = value ?? '';
    if (v.length > 150) return 'Bio must be 150 characters or fewer';
    return null;
  }

  static String? notEmpty(String? value, {String label = 'This field'}) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  static String? phoneNumber(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return null; // optional field
    final RegExp phonePattern = RegExp(r'^\+?[0-9\s\-\(\)]{7,20}$');
    if (!phonePattern.hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }
}
