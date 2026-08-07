import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Thin wrapper around [SharedPreferences] for the handful of local,
/// device-scoped settings the app needs (theme choice, privacy toggles).
///
/// Everything else (profile, chats, messages) lives in Firestore — this is
/// intentionally only for preferences that should persist even when
/// offline and don't need to sync across devices.
class LocalStorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> getThemeMode() async {
    final prefs = await _instance;
    return prefs.getString(AppConstants.prefThemeMode);
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.prefThemeMode, mode);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.prefNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.prefNotificationsEnabled, enabled);
  }

  Future<bool> getReadReceiptsEnabled() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.prefReadReceiptsEnabled) ?? true;
  }

  Future<void> setReadReceiptsEnabled(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.prefReadReceiptsEnabled, enabled);
  }

  Future<bool> getLastSeenEnabled() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.prefLastSeenEnabled) ?? true;
  }

  Future<void> setLastSeenEnabled(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.prefLastSeenEnabled, enabled);
  }

  Future<String?> getLastUserId() async {
    final prefs = await _instance;
    return prefs.getString(AppConstants.prefLastUserId);
  }

  Future<void> setLastUserId(String? uid) async {
    final prefs = await _instance;
    if (uid == null) {
      await prefs.remove(AppConstants.prefLastUserId);
    } else {
      await prefs.setString(AppConstants.prefLastUserId, uid);
    }
  }

  Future<void> clear() async {
    final prefs = await _instance;
    await prefs.remove(AppConstants.prefLastUserId);
  }
}
