import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_monaco/flutter_monaco.dart' as monaco;

import '../../../../providers/editor_preferences_provider.dart';
import 'code_editor_theme_presets.dart';
import 'code_tab_editor_language.dart';

class AppCodeEditorStats {
  final int lineCount;
  final int charCount;
  final int cursorLine;
  final int cursorColumn;
  final int selectionLength;
  final int selectedLineCount;
  final bool canFold;

  const AppCodeEditorStats({
    required this.lineCount,
    required this.charCount,
    required this.cursorLine,
    required this.cursorColumn,
    required this.selectionLength,
    required this.selectedLineCount,
    required this.canFold,
  });

  static const empty = AppCodeEditorStats(
    lineCount: 1,
    charCount: 0,
    cursorLine: 1,
    cursorColumn: 1,
    selectionLength: 0,
    selectedLineCount: 0,
    canFold: true,
  );
}

class AppCodeEditorController extends ChangeNotifier {
  AppCodeEditorController._({
    required this.filePath,
    required int tabSize,
    required bool wrapEnabled,
  }) : _tabSize = tabSize,
       _wrapEnabled = wrapEnabled;

  final String filePath;

  monaco.MonacoController? _monacoController;
  monaco.EditorOptions? _monacoOptions;

  String _text = '';
  bool _textStale = false;
  bool _hasUnsavedChanges = false;
  bool _hasFoldedSections = false;
  bool _ready = false;
  int _tabSize;
  bool _wrapEnabled;
  AppCodeEditorStats _stats = AppCodeEditorStats.empty;
  String? _lastMonacoPresentationKey;

  StreamSubscription<bool>? _monacoContentSub;
  StreamSubscription<monaco.Range?>? _monacoSelectionSub;
  VoidCallback? _monacoStatsListener;

  static Future<AppCodeEditorController> create({
    required String filePath,
    required int tabSize,
    required bool wrapEnabled,
  }) async {
    final controller = AppCodeEditorController._(
      filePath: filePath,
      tabSize: tabSize,
      wrapEnabled: wrapEnabled,
    );
    await controller._initialize();
    return controller;
  }

  bool get isReady => _ready;
  bool get isMonaco => true;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  int get tabSize => _tabSize;
  bool get wrapEnabled => _wrapEnabled;
  bool get hasFoldedSections => _hasFoldedSections;
  String get cachedText => _text;
  AppCodeEditorStats get stats => _stats;
  monaco.MonacoController? get monacoController => _monacoController;
  monaco.EditorOptions? get monacoOptions => _monacoOptions;

  bool get supportsSearch => true;
  bool get supportsFoldAll => true;
  bool get supportsFoldImports => false;
  bool get supportsFoldHeader => false;

  Future<void> _initialize() async {
    final language = monacoLanguageForPath(filePath);
    final options = monaco.EditorOptions(
      language: language,
      theme: monaco.MonacoTheme.vsDark,
      fontSize: 12.25,
      fontFamily: 'Menlo, Monaco, Consolas, "Courier New", monospace',
      lineHeight: 1.3,
      wordWrap: _wrapEnabled,
      minimap: false,
      lineNumbers: true,
      rulers: const [],
      tabSize: _tabSize,
      insertSpaces: true,
      automaticLayout: true,
      scrollBeyondLastLine: false,
      formatOnPaste: false,
      formatOnType: false,
      mouseWheelZoom: false,
      quickSuggestions: true,
      roundedSelection: true,
      selectionHighlight: true,
    );
    _monacoOptions = options;
    final controller = await monaco.MonacoController.create(options: options);
    _monacoController = controller;
    _monacoContentSub = controller.onContentChanged.listen((_) {
      _textStale = true;
      _hasUnsavedChanges = true;
      notifyListeners();
    });
    _monacoSelectionSub = controller.onSelectionChanged.listen((_) {
      _applyMonacoStats(controller.getStatistics());
      notifyListeners();
    });
    _monacoStatsListener = () {
      _applyMonacoStats(controller.getStatistics());
      notifyListeners();
    };
    controller.liveStats.addListener(_monacoStatsListener!);
    _applyMonacoStats(controller.getStatistics());
    _ready = true;
  }

  Future<void> setLanguageForPath(String path) async {
    final monacoController = _monacoController;
    if (monacoController == null) return;
    final nextLanguage = monacoLanguageForPath(path);
    _monacoOptions = _monacoOptions?.copyWith(language: nextLanguage);
    await monacoController.setLanguage(nextLanguage);
  }

  Future<void> setText(String text, {bool markSaved = false}) async {
    _text = text;
    _textStale = false;
    _hasUnsavedChanges = !markSaved;
    _hasFoldedSections = false;

    final monacoController = _monacoController;
    if (monacoController == null) return;
    await monacoController.setValue(text);
    if (markSaved) {
      await monacoController.markSaved();
      _hasUnsavedChanges = false;
    }
    _applyMonacoStats(monacoController.getStatistics());
    notifyListeners();
  }

  Future<void> markSaved() async {
    _hasUnsavedChanges = false;
    _textStale = false;
    await _monacoController?.markSaved();
    notifyListeners();
  }

  Future<String> readText({bool refresh = false}) async {
    final monacoController = _monacoController;
    if (monacoController == null) {
      return _text;
    }

    if (refresh || _textStale) {
      _text = await monacoController.getValue(defaultValue: _text);
      _textStale = false;
    }
    return _text;
  }

  Future<void> setTabSpaces(int value) async {
    final normalized = value.clamp(1, 8);
    _tabSize = normalized;

    final current = _monacoOptions;
    final monacoController = _monacoController;
    if (current == null || monacoController == null) return;
    _monacoOptions = current.copyWith(tabSize: normalized);
    await monacoController.updateOptions(_monacoOptions!);
  }

  Future<void> setWrapEnabled(bool enabled) async {
    _wrapEnabled = enabled;

    final current = _monacoOptions;
    final monacoController = _monacoController;
    if (current == null || monacoController == null) return;
    _monacoOptions = current.copyWith(wordWrap: enabled);
    await monacoController.updateOptions(_monacoOptions!);
    notifyListeners();
  }

  Future<void> applyMonacoPresentation({
    required EditorPreferencesProvider preferences,
    required CodeEditorThemePreset preset,
    required bool prefersDark,
    required bool readOnly,
  }) async {
    final monacoController = _monacoController;
    final current = _monacoOptions;
    if (monacoController == null || current == null) return;

    final themeId = 'd1vai-${preset.id}';
    final rulers = preferences.showRulers ? const [80, 120] : const <int>[];
    final nextOptions = current.copyWith(
      language: monacoLanguageForPath(filePath),
      fontSize: preferences.fontSize,
      fontFamily: 'Menlo, Monaco, Consolas, "Courier New", monospace',
      lineHeight: 1.3,
      wordWrap: _wrapEnabled,
      rulers: rulers,
      tabSize: preferences.tabSize,
      readOnly: readOnly,
      theme: prefersDark ? monaco.MonacoTheme.vsDark : monaco.MonacoTheme.vs,
    );
    final presentationKey = [
      themeId,
      preferences.fontSize.toStringAsFixed(2),
      preferences.tabSize,
      preferences.showRulers,
      _wrapEnabled,
      readOnly,
      filePath,
    ].join('|');

    if (_lastMonacoPresentationKey == presentationKey &&
        _monacoOptions == nextOptions) {
      return;
    }

    _monacoOptions = nextOptions;
    _lastMonacoPresentationKey = presentationKey;
    final didRegisterTheme = await monacoController.tryDefineTheme(
      themeId,
      buildMonacoThemeDataForPreset(
        preset,
        baseTheme: prefersDark ? 'vs-dark' : 'vs',
      ),
    );
    await monacoController.updateOptions(nextOptions);
    await monacoController.setThemeById(
      didRegisterTheme ? themeId : (prefersDark ? 'vs-dark' : 'vs'),
    );
  }

  void showSearch() {
    unawaited(_monacoController?.find() ?? Future<void>.value());
  }

  void foldAll() {
    _hasFoldedSections = true;
    notifyListeners();
    unawaited(
      _monacoController?.executeAction(monaco.MonacoAction.foldAll) ??
          Future<void>.value(),
    );
  }

  void unfoldAll() {
    _hasFoldedSections = false;
    notifyListeners();
    unawaited(
      _monacoController?.executeAction(monaco.MonacoAction.unfoldAll) ??
          Future<void>.value(),
    );
  }

  void foldImports() {}

  void foldHeader() {}

  void _applyMonacoStats(monaco.LiveStats stats) {
    final cursorParts = stats.cursorPosition?.label.split(':');
    final cursorLine = cursorParts != null && cursorParts.length == 2
        ? int.tryParse(cursorParts.first) ?? 1
        : 1;
    final cursorColumn = cursorParts != null && cursorParts.length == 2
        ? int.tryParse(cursorParts.last) ?? 1
        : 1;
    _stats = AppCodeEditorStats(
      lineCount: stats.lineCount.value,
      charCount: stats.charCount.value,
      cursorLine: cursorLine,
      cursorColumn: cursorColumn,
      selectionLength: stats.selectedCharacters.value,
      selectedLineCount: stats.selectedLines.value,
      canFold: true,
    );
  }

  @override
  void dispose() {
    _monacoContentSub?.cancel();
    _monacoSelectionSub?.cancel();
    final monacoStatsListener = _monacoStatsListener;
    if (monacoStatsListener != null) {
      _monacoController?.liveStats.removeListener(monacoStatsListener);
    }
    _monacoController?.dispose();
    super.dispose();
  }
}

monaco.MonacoLanguage monacoLanguageForPath(String? path) {
  final highlightName = highlightLanguageForPath(path);
  return switch (highlightName) {
    'dart' => monaco.MonacoLanguage.dart,
    'kotlin' => monaco.MonacoLanguage.kotlin,
    'swift' => monaco.MonacoLanguage.swift,
    'typescript' => monaco.MonacoLanguage.typescript,
    'javascript' => monaco.MonacoLanguage.javascript,
    'java' => monaco.MonacoLanguage.java,
    'go' => monaco.MonacoLanguage.go,
    'cpp' => monaco.MonacoLanguage.cpp,
    'json' => monaco.MonacoLanguage.json,
    'ini' => monaco.MonacoLanguage.ini,
    'markdown' => monaco.MonacoLanguage.markdown,
    'graphql' => monaco.MonacoLanguage.graphql,
    'xml' => monaco.MonacoLanguage.xml,
    'yaml' => monaco.MonacoLanguage.yaml,
    'python' => monaco.MonacoLanguage.python,
    'rust' => monaco.MonacoLanguage.rust,
    'sql' => monaco.MonacoLanguage.sql,
    'bash' => monaco.MonacoLanguage.shell,
    'shell' => monaco.MonacoLanguage.shell,
    'php' => monaco.MonacoLanguage.php,
    'diff' => monaco.MonacoLanguage.plaintext,
    'dockerfile' => monaco.MonacoLanguage.dockerfile,
    'makefile' => monaco.MonacoLanguage.plaintext,
    'nginx' => monaco.MonacoLanguage.plaintext,
    'gradle' => monaco.MonacoLanguage.kotlin,
    'ruby' => monaco.MonacoLanguage.ruby,
    'plaintext' => monaco.MonacoLanguage.plaintext,
    null => monaco.MonacoLanguage.plaintext,
    _ => monaco.MonacoLanguage.plaintext,
  };
}

Map<String, dynamic> buildMonacoThemeDataForPreset(
  CodeEditorThemePreset preset, {
  required String baseTheme,
}) {
  final root = preset.highlightTheme['root'] ?? const TextStyle();
  final colors = <String, String>{
    'editor.background': _hex(root.backgroundColor ?? preset.gutterBackground),
    'editor.foreground': _hex(root.color ?? preset.activeLineNumberColor),
    'editorLineNumber.foreground': _hex(preset.lineNumberColor),
    'editorLineNumber.activeForeground': _hex(preset.activeLineNumberColor),
    'editor.lineHighlightBackground': _hex(preset.currentLineColor),
    'editor.selectionBackground': _hex(preset.selectionColor),
    'editorCursor.foreground': _hex(preset.activeLineNumberColor),
    'editorIndentGuide.background1': _hex(preset.indentGuideColor),
    'editorIndentGuide.activeBackground1': _hex(preset.activeIndentGuideColor),
    'editorRuler.foreground': _hex(preset.rulerColor),
    'editorBracketMatch.border': _hex(preset.bracketPairColor),
    'editorBracketHighlight.foreground1': _hex(preset.bracketPairColor),
    'editorBracketHighlight.foreground2': _hex(preset.bracketPairColor),
    'editorBracketHighlight.foreground3': _hex(preset.bracketPairColor),
    'editorBracketHighlight.foreground4': _hex(preset.bracketPairColor),
    'editorBracketHighlight.foreground5': _hex(preset.bracketPairColor),
    'editorBracketHighlight.foreground6': _hex(preset.bracketPairColor),
    'editor.findMatchBackground': _hex(preset.searchMatchBackgroundColor),
    'editor.findMatchHighlightBackground': _hex(
      preset.currentSearchMatchBackgroundColor,
    ),
    'editor.findRangeHighlightBackground': _hex(
      preset.searchMatchBackgroundColor.withValues(alpha: 0.35),
    ),
    'editorGutter.background': _hex(preset.gutterBackground),
    'editorWidget.background': _hex(preset.gutterBackground),
    'minimap.background': _hex(preset.gutterBackground),
  };

  final rules = <Map<String, dynamic>>[];

  void addRule(String? key, List<String> monacoTokens) {
    if (key == null) return;
    final style = preset.highlightTheme[key];
    final color = style?.color;
    if (style == null || color == null) return;
    final isBold =
        style.fontWeight != null &&
        style.fontWeight != FontWeight.normal &&
        style.fontWeight != FontWeight.w400;
    final fontStyle = [
      if (style.fontStyle == FontStyle.italic) 'italic',
      if (isBold) 'bold',
      if (style.decoration == TextDecoration.underline) 'underline',
    ].join(' ');
    for (final token in monacoTokens) {
      rules.add({
        'token': token,
        'foreground': _hex(color, includeHash: false),
        if (fontStyle.isNotEmpty) 'fontStyle': fontStyle,
      });
    }
  }

  addRule('comment', ['comment']);
  addRule('quote', ['string']);
  addRule('string', ['string']);
  addRule('keyword', ['keyword', 'keyword.control']);
  addRule('number', ['number']);
  addRule('literal', ['number', 'constant']);
  addRule('built_in', ['type.identifier', 'support.type']);
  addRule('type', ['type', 'type.identifier']);
  addRule('class', ['type', 'type.identifier']);
  addRule('title', ['entity.name.function', 'entity.name.type']);
  addRule('function', ['entity.name.function']);
  addRule('params', ['variable.parameter']);
  addRule('meta', ['meta']);
  addRule('attr', ['attribute.name']);
  addRule('attribute', ['attribute.name']);
  addRule('variable', ['variable']);
  addRule('template-variable', ['variable']);
  addRule('symbol', ['constant.other.symbol']);
  addRule('bullet', ['markup.list']);
  addRule('link', ['string.link']);
  addRule('tag', ['tag']);
  addRule('name', ['identifier']);

  return {'base': baseTheme, 'inherit': true, 'rules': rules, 'colors': colors};
}

String _hex(Color color, {bool includeHash = true}) {
  final value = color.toARGB32() & 0x00FFFFFF;
  final hex = value.toRadixString(16).padLeft(6, '0').toUpperCase();
  return includeHash ? '#$hex' : hex;
}
