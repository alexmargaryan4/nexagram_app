import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NexaGramApp());
}

/// Root widget: installs the app-wide [AuthProvider] and [ThemeProvider],
/// then builds a [GoRouter]-backed [MaterialApp] on top of them.
///
/// [AuthProvider] and the [GoRouter] instance are both created once, at
/// the very top of the tree, and the router is handed a reference to the
/// auth provider (`refreshListenable`) so a sign-in/sign-out anywhere in
/// the app automatically re-evaluates route redirects without every
/// screen needing to poll auth state manually.
class NexaGramApp extends StatelessWidget {
  const NexaGramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildAppRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
