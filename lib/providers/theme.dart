import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's light/dark theme and notifies listeners (via
/// ChangeNotifier + Provider) so every screen rebuilds instantly when
/// the user toggles dark mode in Settings.
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'dark_mode';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_prefKey) ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  Future<void> toggle() => setDarkMode(!_isDarkMode);

  // ── Brand colors shared by both themes ──────────────────────────
  static const Color primary = Color(0xFF7F77DD);
  static const Color secondary = Color(0xFF378ADD);

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F5FB),
    cardColor: Colors.white,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFEEEDFE),
      foregroundColor: Color(0xFF3C3489),
      elevation: 0,
    ),
    dividerColor: const Color(0xFFEEEDFE),
  );

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF15131F),
    cardColor: const Color(0xFF221F30),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF221F30),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    dividerColor: const Color(0xFF332E45),
  );
}

/// Theme-aware color helpers so existing screens (which use hardcoded
/// hex colors like Color(0xFFF4F5FB) for backgrounds and Colors.white
/// for cards) can be adapted to dark mode with minimal changes.
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgColor =>
      isDark ? const Color(0xFF15131F) : const Color(0xFFF4F5FB);
  Color get cardColor => isDark ? const Color(0xFF221F30) : Colors.white;
  Color get headerColor =>
      isDark ? const Color(0xFF221F30) : const Color(0xFFEEEDFE);
  Color get borderColor =>
      isDark ? const Color(0xFF332E45) : const Color(0xFFEEEDFE);
  Color get primaryTextColor => isDark ? Colors.white : const Color(0xFF2C2C2A);
  Color get secondaryTextColor => isDark ? Colors.grey.shade400 : Colors.grey;
  Color get titleColor => isDark ? Colors.white : const Color(0xFF3C3489);
}
