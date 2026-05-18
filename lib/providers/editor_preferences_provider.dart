import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditorPreferencesProvider with ChangeNotifier {
  static const _lightThemePresetKey = 'editor_light_theme_preset';
  static const _darkThemePresetKey = 'editor_dark_theme_preset';
  static const _appearanceModeKey = 'editor_appearance_mode';
  static const _fontSizeKey = 'editor_font_size';
  static const _showRulersKey = 'editor_show_rulers';
  static const _defaultWrapKey = 'editor_default_wrap';
  static const _tabSizeKey = 'editor_tab_size';
  static const _engineKey = 'editor_engine';

  String _lightThemePresetId = 'vscode_light';
  String _darkThemePresetId = 'vscode_dark';
  double _fontSize = 12.25;
  bool _showRulers = true;
  bool _defaultWrap = false;
  int _tabSize = 2;
  EditorAppearanceMode _appearanceMode = EditorAppearanceMode.followApp;
  EditorEngine _engine = EditorEngine.flutterCodeEditor;

  String get lightThemePresetId => _lightThemePresetId;
  String get darkThemePresetId => _darkThemePresetId;
  double get fontSize => _fontSize;
  bool get showRulers => _showRulers;
  bool get defaultWrap => _defaultWrap;
  int get tabSize => _tabSize;
  EditorAppearanceMode get appearanceMode => _appearanceMode;
  EditorEngine get engine => _engine;

  EditorPreferencesProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyPreset = prefs.getString('editor_theme_preset');
      _lightThemePresetId =
          prefs.getString(_lightThemePresetKey) ??
          (legacyPreset == 'vscode_dark'
              ? 'vscode_light'
              : _lightThemePresetId);
      _darkThemePresetId =
          prefs.getString(_darkThemePresetKey) ??
          legacyPreset ??
          _darkThemePresetId;
      _fontSize = prefs.getDouble(_fontSizeKey) ?? _fontSize;
      _showRulers = prefs.getBool(_showRulersKey) ?? _showRulers;
      _defaultWrap = prefs.getBool(_defaultWrapKey) ?? _defaultWrap;
      _tabSize = prefs.getInt(_tabSizeKey) ?? _tabSize;
      final engine = prefs.getString(_engineKey);
      if (engine != null) {
        _engine = EditorEngine.values.firstWhere(
          (value) => value.name == engine,
          orElse: () => EditorEngine.flutterCodeEditor,
        );
      }
      final appearance = prefs.getString(_appearanceModeKey);
      if (appearance != null) {
        _appearanceMode = EditorAppearanceMode.values.firstWhere(
          (value) => value.name == appearance,
          orElse: () => EditorAppearanceMode.followApp,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLightThemePreset(String value) async {
    if (_lightThemePresetId == value) return;
    _lightThemePresetId = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lightThemePresetKey, value);
    } catch (_) {}
  }

  Future<void> setDarkThemePreset(String value) async {
    if (_darkThemePresetId == value) return;
    _darkThemePresetId = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_darkThemePresetKey, value);
    } catch (_) {}
  }

  Future<void> setFontSize(double value) async {
    final normalized = value.clamp(11.0, 16.0);
    if ((_fontSize - normalized).abs() < 0.01) return;
    _fontSize = normalized;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, normalized);
    } catch (_) {}
  }

  Future<void> setShowRulers(bool value) async {
    if (_showRulers == value) return;
    _showRulers = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showRulersKey, value);
    } catch (_) {}
  }

  Future<void> setDefaultWrap(bool value) async {
    if (_defaultWrap == value) return;
    _defaultWrap = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_defaultWrapKey, value);
    } catch (_) {}
  }

  Future<void> setTabSize(int value) async {
    final normalized = value.clamp(1, 8);
    if (_tabSize == normalized) return;
    _tabSize = normalized;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_tabSizeKey, normalized);
    } catch (_) {}
  }

  Future<void> setAppearanceMode(EditorAppearanceMode value) async {
    if (_appearanceMode == value) return;
    _appearanceMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appearanceModeKey, value.name);
    } catch (_) {}
  }

  Future<void> setEngine(EditorEngine value) async {
    if (_engine == value) return;
    _engine = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_engineKey, value.name);
    } catch (_) {}
  }
}

enum EditorAppearanceMode { followApp, forceLight, forceDark }

enum EditorEngine {
  flutterCodeEditor,
  flutterMonaco;

  String get label => switch (this) {
    EditorEngine.flutterCodeEditor => 'Flutter Code Editor',
    EditorEngine.flutterMonaco => 'Flutter Monaco',
  };

  String get shortLabel => switch (this) {
    EditorEngine.flutterCodeEditor => 'Native',
    EditorEngine.flutterMonaco => 'Monaco',
  };
}
