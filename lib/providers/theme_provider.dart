import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用主题模式枚举
enum AppThemeMode { light, dark, system }

/// 主题提供者
class ThemeProvider with ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  static const String _themeModeKey = 'theme_mode';

  AppThemeMode get themeMode => _themeMode;

  /// 获取当前主题模式的名称
  String get themeModeName {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  ThemeProvider() {
    _loadThemeMode();
  }

  /// 从本地存储加载主题模式
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(_themeModeKey);
      if (themeModeString != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (e) => e.toString() == themeModeString,
          orElse: () => AppThemeMode.system,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.toString());
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  /// 获取 Flutter 的 ThemeMode
  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
