import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  static const String _keyTheme = "captain_theme_mode";
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyTheme);
      if (saved == "light") {
        themeModeNotifier.value = ThemeMode.light;
      } else {
        themeModeNotifier.value = ThemeMode.dark;
      }
    } catch (_) {
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTheme, mode == ThemeMode.light ? "light" : "dark");
    } catch (_) {}
  }

  bool get isDark => themeModeNotifier.value == ThemeMode.dark;
}
