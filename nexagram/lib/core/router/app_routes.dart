/// Centralised route paths & names.
///
/// Screens navigate with `context.push(AppRoutes.chat(chatId))` /
/// `context.goNamed(AppRoutes.chatsName)` instead of hand-typed path
/// strings scattered across the codebase, so a path change is a one-line
/// edit here rather than a project-wide find/replace.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';

  static const String chats = '/chats';
  static const String chat = '/chats/:chatId';
  static const String contacts = '/contacts';
  static const String profile = '/profile';
  static const String settings = '/settings';

  static const String editProfile = '/profile/edit';
  static const String userProfile = '/user/:uid';
  static const String newGroup = '/contacts/new-group';
  static const String privacySettings = '/settings/privacy';
  static const String notificationSettings = '/settings/notifications';
  static const String blockedUsers = '/settings/privacy/blocked';

  static const String splashName = 'splash';
  static const String loginName = 'login';
  static const String registerName = 'register';
  static const String chatsName = 'chats';
  static const String chatName = 'chat';
  static const String contactsName = 'contacts';
  static const String profileName = 'profile';
  static const String settingsName = 'settings';
  static const String editProfileName = 'editProfile';
  static const String userProfileName = 'userProfile';
  static const String newGroupName = 'newGroup';
  static const String privacySettingsName = 'privacySettings';
  static const String notificationSettingsName = 'notificationSettings';
  static const String blockedUsersName = 'blockedUsers';

  static String chatPath(String chatId) => '/chats/$chatId';
  static String userProfilePath(String uid) => '/user/$uid';
}
