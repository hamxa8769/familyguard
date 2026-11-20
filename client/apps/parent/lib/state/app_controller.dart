import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifications/alert_watcher.dart';
import 'parent_state.dart';

/// App-wide settings and session: theme mode, signed-in state, sign-out.
class AppController extends ChangeNotifier {
  AppController._();
  static final AppController instance = AppController._();

  static const _themeKey = 'theme_mode';

  ThemeMode themeMode = ThemeMode.dark;
  bool ready = false;

  bool get signedIn => AuthService.instance.isSignedIn;

  Future<void> load() async {
    await AuthService.instance.load();
    try {
      final prefs = await SharedPreferences.getInstance();
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_themeKey),
        orElse: () => ThemeMode.dark,
      );
    } catch (_) {}
    ready = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
    } catch (_) {}
  }

  void signedInChanged() => notifyListeners();

  Future<void> signOut() async {
    await AlertWatcher.instance.stop().catchError((_) {});
    await AuthService.instance.logout();
    ParentState.instance.clear();
    notifyListeners();
  }
}
