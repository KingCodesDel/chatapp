import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single, app-wide source of truth for light/dark mode. main.dart
/// listens to this; SettingsScreen writes to it.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDark(bool isDark) async {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);
  }
}
