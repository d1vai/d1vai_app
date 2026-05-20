import 'package:flutter/material.dart';

import 'code_editor_theme_specs.dart';

class CodeEditorThemePreset {
  final String id;
  final String label;
  final Map<String, TextStyle> highlightTheme;
  final bool isDark;
  final Color currentLineColor;
  final Color selectionColor;
  final Color gutterBackground;
  final Color activeLineNumberBackground;
  final Color lineNumberColor;
  final Color activeLineNumberColor;
  final Color indentGuideColor;
  final Color activeIndentGuideColor;
  final Color bracketPairColor;
  final Color rulerColor;
  final Color searchMatchBackgroundColor;
  final Color currentSearchMatchBackgroundColor;
  final Color searchMatchTextColor;

  const CodeEditorThemePreset({
    required this.id,
    required this.label,
    required this.highlightTheme,
    required this.isDark,
    required this.currentLineColor,
    required this.selectionColor,
    required this.gutterBackground,
    required this.activeLineNumberBackground,
    required this.lineNumberColor,
    required this.activeLineNumberColor,
    required this.indentGuideColor,
    required this.activeIndentGuideColor,
    required this.bracketPairColor,
    required this.rulerColor,
    required this.searchMatchBackgroundColor,
    required this.currentSearchMatchBackgroundColor,
    required this.searchMatchTextColor,
  });
}

Map<String, TextStyle> _buildTheme({
  required Color background,
  required Color foreground,
  required Color comment,
  required Color keyword,
  required Color string,
  required Color number,
  required Color variable,
  required Color type,
  required Color title,
  required Color meta,
  Color? attr,
  Color? link,
}) {
  return {
    'root': TextStyle(backgroundColor: background, color: foreground),
    'comment': TextStyle(color: comment, fontStyle: FontStyle.italic),
    'quote': TextStyle(color: comment, fontStyle: FontStyle.italic),
    'keyword': TextStyle(color: keyword),
    'selector-tag': TextStyle(color: keyword),
    'literal': TextStyle(color: number),
    'number': TextStyle(color: number),
    'string': TextStyle(color: string),
    'title': TextStyle(color: title),
    'section': TextStyle(color: title),
    'name': TextStyle(color: title),
    'function': TextStyle(color: title),
    'params': TextStyle(color: foreground),
    'type': TextStyle(color: type),
    'class': TextStyle(color: type),
    'built_in': TextStyle(color: type),
    'builtin-name': TextStyle(color: type),
    'attr': TextStyle(color: attr ?? variable),
    'attribute': TextStyle(color: attr ?? variable),
    'variable': TextStyle(color: variable),
    'template-variable': TextStyle(color: variable),
    'symbol': TextStyle(color: link ?? keyword),
    'bullet': TextStyle(color: link ?? keyword),
    'link': TextStyle(color: link ?? keyword),
    'meta': TextStyle(color: meta),
    'meta-keyword': TextStyle(color: meta),
    'subst': TextStyle(color: foreground),
    'tag': TextStyle(color: keyword),
  };
}

final List<CodeEditorThemePreset> codeEditorThemePresets = kCodeEditorThemeSpecs
    .map(_presetFromSpec)
    .toList(growable: false);

CodeEditorThemePreset _presetFromSpec(Map<String, Object> spec) {
  final tokens = Map<String, Object>.from(spec['tokens'] as Map);
  final ui = Map<String, Object>.from(spec['ui'] as Map);

  return CodeEditorThemePreset(
    id: spec['id']! as String,
    label: spec['label']! as String,
    isDark: spec['isDark']! as bool,
    highlightTheme: _buildTheme(
      background: _color(tokens['background']! as String),
      foreground: _color(tokens['foreground']! as String),
      comment: _color(tokens['comment']! as String),
      keyword: _color(tokens['keyword']! as String),
      string: _color(tokens['string']! as String),
      number: _color(tokens['number']! as String),
      variable: _color(tokens['variable']! as String),
      type: _color(tokens['type']! as String),
      title: _color(tokens['title']! as String),
      meta: _color(tokens['meta']! as String),
      attr: _color(tokens['attr']! as String),
      link: tokens['link'] == null ? null : _color(tokens['link']! as String),
    ),
    currentLineColor: _color(ui['currentLineColor']! as String),
    selectionColor: _color(ui['selectionColor']! as String),
    gutterBackground: _color(ui['gutterBackground']! as String),
    activeLineNumberBackground: _color(
      ui['activeLineNumberBackground']! as String,
    ),
    lineNumberColor: _color(ui['lineNumberColor']! as String),
    activeLineNumberColor: _color(ui['activeLineNumberColor']! as String),
    indentGuideColor: _color(ui['indentGuideColor']! as String),
    activeIndentGuideColor: _color(ui['activeIndentGuideColor']! as String),
    bracketPairColor: _color(ui['bracketPairColor']! as String),
    rulerColor: _color(ui['rulerColor']! as String),
    searchMatchBackgroundColor: _color(
      ui['searchMatchBackgroundColor']! as String,
    ),
    currentSearchMatchBackgroundColor: _color(
      ui['currentSearchMatchBackgroundColor']! as String,
    ),
    searchMatchTextColor: _color(ui['searchMatchTextColor']! as String),
  );
}

Color _color(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final argb = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.parse(argb, radix: 16));
}

CodeEditorThemePreset codeEditorThemePresetById(String id) {
  return codeEditorThemePresets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => codeEditorThemePresets.first,
  );
}

List<CodeEditorThemePreset> get lightCodeEditorThemePresets =>
    codeEditorThemePresets
        .where((preset) => !preset.isDark)
        .toList(growable: false);

List<CodeEditorThemePreset> get darkCodeEditorThemePresets =>
    codeEditorThemePresets
        .where((preset) => preset.isDark)
        .toList(growable: false);

String monacoThemeIdForPreset(String scope, String presetId) {
  // Monaco custom theme registration is more reliable when the runtime theme
  // id is restricted to lowercase slug characters. We keep the user-facing
  // preset id untouched for storage/localization, and only sanitize the id
  // that is passed into defineTheme/setThemeById.
  final safePresetId = presetId
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final safeScope = scope
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return '$safeScope-$safePresetId';
}
