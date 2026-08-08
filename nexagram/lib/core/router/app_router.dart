import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/chat/group_info_screen.dart';
import '../../screens/contacts/new_group_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/user_profile_screen.dart';
import '../../screens/settings/blocked_users_screen.dart';
import '../../screens/settings/notification_settings_screen.dart';
import '../../screens/settings/privacy_settings_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash/splash_screen.dart';
import 'app_routes.dart';

/// Builds the app's [GoRouter], gated by [authProvider]'s sign-in state.
///
/// The splash screen owns its own minimum-display-time + first auth-check
/// logic internally, so the router's `redirect` only needs to handle the
/// steady-state case (post-splash) of bouncing signed-out users to /login
/// and signed-in users away from the auth screens.
GoRouter buildAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final String location = state.matchedLocation;
      final bool onSplash = location == AppRoutes.splash;
      if (onSplash) return null; // splash handles its own navigation

      final bool onAuthScreen =
          location == AppRoutes.login || location == AppRoutes.register;

      switch (authProvider.status) {
        case AuthStatus.unknown:
          return null;
        case AuthStatus.unauthenticated:
          return onAuthScreen ? null : AppRoutes.login;
        case AuthStatus.authenticated:
          return onAuthScreen ? AppRoutes.chats : null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.chats,
        name: AppRoutes.chatsName,
        builder: (context, state) => const MainShell(),
        routes: [
          GoRoute(
            path: ':chatId',
            name: AppRoutes.chatName,
            builder: (context, state) => ChatScreen(
              chatId: state.pathParameters['chatId']!,
            ),
            routes: [
              GoRoute(
                path: 'info',
                name: AppRoutes.groupInfoName,
                builder: (context, state) => GroupInfoScreen(
                  chatId: state.pathParameters['chatId']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.contacts,
        name: AppRoutes.contactsName,
        builder: (context, state) => const MainShell(),
        routes: [
          GoRoute(
            path: 'new-group',
            name: AppRoutes.newGroupName,
            builder: (context, state) => const NewGroupScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const MainShell(),
        routes: [
          GoRoute(
            path: 'privacy',
            name: AppRoutes.privacySettingsName,
            builder: (context, state) => const PrivacySettingsScreen(),
            routes: [
              GoRoute(
                path: 'blocked',
                name: AppRoutes.blockedUsersName,
                builder: (context, state) => const BlockedUsersScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'notifications',
            name: AppRoutes.notificationSettingsName,
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: AppRoutes.profileName,
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            name: AppRoutes.editProfileName,
            builder: (context, state) => const EditProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        name: AppRoutes.userProfileName,
        builder: (context, state) => UserProfileScreen(
          uid: state.pathParameters['uid']!,
        ),
      ),
    ],
  );
}
