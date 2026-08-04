/// Theme Provider
///
/// Manages dark/light theme mode with SharedPreferences persistence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'civic_link_theme_mode';

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.system; // default: follow OS (dual-theme ready)
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey);
    if (value == 'light') {
      state = ThemeMode.light;
    } else if (value == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      await prefs.setString(_themeKey, 'light');
    } else {
      state = ThemeMode.dark;
      await prefs.setString(_themeKey, 'dark');
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = mode;
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_themeKey, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_themeKey, 'dark');
        break;
      case ThemeMode.system:
        await prefs.remove(_themeKey);
        break;
    }
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
