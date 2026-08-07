import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

/// Owns the app's [ThemeMode] and persists the user's choice locally so it
/// survives app restarts without needing a network round-trip.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({LocalStorageService? localStorage})
      : _localStorage = localStorage ?? LocalStorageService() {
    _restore();
  }

  final LocalStorageService _localStorage;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _restore() async {
    final String? stored = await _localStorage.getThemeMode();
    if (stored != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _localStorage.setThemeMode(mode.name);
  }

  Future<void> toggle() {
    return setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }
}
