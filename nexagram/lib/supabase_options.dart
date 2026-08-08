/// Supabase project credentials, supplied at build/run time via
/// `--dart-define` so nothing sensitive needs to be hand-edited or
/// committed to source control.
///
/// See docs/SUPABASE_SETUP.md for how to obtain these values and
/// `.github/workflows/build.yml` for how CI supplies them from repository
/// secrets.
///
/// Usage:
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Name of the public Storage bucket created by
  /// `supabase_storage_policy.sql`. Kept here (rather than only in
  /// [AppConstants]) since it's part of the same "how the app talks to
  /// Supabase" configuration surface as [url] and [anonKey].
  static const String bucket = 'nexagram';

  /// True once both [url] and [anonKey] have been supplied via
  /// `--dart-define`. `main.dart` doesn't currently gate on this, but
  /// screens/services can check it to fail fast with a clear message
  /// instead of a confusing network error when someone forgets the
  /// `--dart-define` flags.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
