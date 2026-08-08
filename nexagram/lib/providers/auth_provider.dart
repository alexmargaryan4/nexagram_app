import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Single source of truth for "who is signed in" across the app.
///
/// Listens to Supabase's auth-state stream and mirrors the corresponding
/// `public.users` profile row, so any widget can watch [currentUser]
/// instead of re-fetching it. Also owns presence (online/offline) and the
/// Realtime message-notification subscription lifecycle, since both are
/// tied 1:1 to the signed-in session.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    UserService? userService,
    NotificationService? notificationService,
    LocalStorageService? localStorage,
  })  : _authService = authService ?? AuthService(),
        _userService = userService ?? UserService(),
        _notificationService = notificationService ?? NotificationService(),
        _localStorage = localStorage ?? LocalStorageService() {
    _init();
  }

  final AuthService _authService;
  final UserService _userService;
  final NotificationService _notificationService;
  final LocalStorageService _localStorage;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  StreamSubscription<UserModel?>? _profileSub;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _init() {
    _authService.authStateChanges().listen((supabaseUser) async {
      await _profileSub?.cancel();

      if (supabaseUser == null) {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _profileSub = _userService.watchUser(supabaseUser.id).listen((user) {
        _currentUser = user;
        _status =
            user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
        notifyListeners();
      });

      await _localStorage.setLastUserId(supabaseUser.id);
      await _userService.setOnline(supabaseUser.id);
      unawaited(_notificationService.registerToken(supabaseUser.id));
    });
  }

  Future<bool> signIn({required String email, required String password}) {
    return _runGuarded(() async {
      await _authService.signIn(email: email, password: password);
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) {
    return _runGuarded(() async {
      await _authService.register(
        email: email,
        password: password,
        username: username,
        name: name,
      );
    });
  }

  Future<bool> sendPasswordResetEmail(String email) {
    return _runGuarded(() async {
      await _authService.sendPasswordResetEmail(email);
    });
  }

  Future<void> signOut() async {
    final String? uid = _currentUser?.uid;
    if (uid != null) {
      await _userService.setOffline(uid);
      await _notificationService.unregisterToken(uid);
    }
    await _localStorage.setLastUserId(null);
    await _authService.signOut();
  }

  Future<bool> deleteAccount() {
    return _runGuarded(() async {
      await _authService.deleteAccount();
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Runs [action], translating any [AppException] into [errorMessage] and
  /// managing [isLoading], so screens only need to check a boolean result.
  Future<bool> _runGuarded(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }
}
