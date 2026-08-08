/// Global, non-secret constants used across the app.
///
/// Keep this file free of environment-specific secrets — those belong in
/// `lib/supabase_options.dart`, populated via `--dart-define` at build
/// time and excluded from anything that would leak a service-role key.
class AppConstants {
  AppConstants._();

  static const String appName = 'NexaGram';
  static const String appTagline = 'Fast. Private. Beautiful.';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int messagePageSize = 30;
  static const int chatPageSize = 25;
  static const int contactPageSize = 40;
  static const int searchResultLimit = 20;

  // Media constraints
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB
  static const int imageCompressQuality = 82;
  static const int avatarCompressQuality = 90;
  static const int maxVoiceMessageSeconds = 120;

  // Typing indicator
  static const Duration typingTimeout = Duration(seconds: 4);
  static const Duration typingDebounce = Duration(milliseconds: 400);

  // Presence
  static const Duration onlineHeartbeat = Duration(seconds: 30);
  static const Duration presenceStaleAfter = Duration(seconds: 45);

  // Animations
  static const Duration animFast = Duration(milliseconds: 180);
  static const Duration animMedium = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 450);
  static const Duration splashMinDuration = Duration(milliseconds: 1800);

  // Glassmorphism defaults
  static const double glassBlurSigma = 18.0;
  static const double glassBorderOpacityLight = 0.35;
  static const double glassBorderOpacityDark = 0.12;

  // Layout
  static const double defaultRadius = 20.0;
  static const double bubbleRadius = 18.0;
  static const double avatarRadiusSmall = 18.0;
  static const double avatarRadiusMedium = 24.0;
  static const double avatarRadiusLarge = 44.0;

  // Local storage keys
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefLastUserId = 'pref_last_user_id';
  static const String prefNotificationsEnabled = 'pref_notifications_enabled';
  static const String prefReadReceiptsEnabled = 'pref_read_receipts_enabled';
  static const String prefLastSeenEnabled = 'pref_last_seen_enabled';
}

/// Supabase Postgres table names, centralised so a rename never requires
/// a project-wide find/replace across business logic.
class SupabaseTables {
  SupabaseTables._();

  static const String users = 'users';
  static const String chats = 'chats';
  static const String messages = 'messages'; // fk: chat_id -> chats.id
  static const String contacts = 'contacts'; // fk: owner_uid -> users.id
  static const String typingStatus = 'typing_status'; // fk: chat_id -> chats.id
  static const String reports = 'reports';
}

/// Names of the Postgres RPC functions (`supabase_schema.sql`) used for
/// operations that need atomic/elevated semantics beyond a plain
/// RLS-scoped table call — the equivalents of the old Firestore
/// WriteBatch / FieldValue.increment / FieldValue.arrayUnion calls.
class SupabaseRpc {
  SupabaseRpc._();

  static const String sendMessage = 'send_message';
  static const String markChatAsRead = 'mark_chat_as_read';
  static const String toggleReaction = 'toggle_reaction';
  static const String searchUsers = 'search_users';
}

/// Supabase Storage path helpers.
class StoragePaths {
  StoragePaths._();

  static String avatar(String userId) => 'avatars/$userId.jpg';
  static String chatImage(String chatId, String fileName) =>
      'chats/$chatId/images/$fileName';
  static String chatFile(String chatId, String fileName) =>
      'chats/$chatId/files/$fileName';
  static String chatVoice(String chatId, String fileName) =>
      'chats/$chatId/voice/$fileName';
}
