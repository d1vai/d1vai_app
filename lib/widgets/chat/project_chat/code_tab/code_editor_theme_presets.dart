import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';
import 'package:flutter_highlight/themes/gruvbox-light.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/night-owl.dart';
import 'package:flutter_highlight/themes/nord.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/vs2015.dart';

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

final List<CodeEditorThemePreset> codeEditorThemePresets = [
  CodeEditorThemePreset(
    id: 'vscode_dark',
    label: 'VS Code Dark+',
    highlightTheme: Map<String, TextStyle>.from(vs2015Theme),
    isDark: true,
    currentLineColor: const Color(0xFF2A2D2E),
    selectionColor: const Color(0xFF264F78),
    gutterBackground: const Color(0xFF1E1E1E),
    activeLineNumberBackground: const Color(0xFF252526),
    lineNumberColor: const Color(0xFF858585),
    activeLineNumberColor: const Color(0xFFC6C6C6),
    indentGuideColor: const Color(0xFF404040),
    activeIndentGuideColor: const Color(0xFF707070),
    bracketPairColor: const Color(0xFF8CDCFE),
    rulerColor: const Color(0xFF333333),
    searchMatchBackgroundColor: const Color(0xFF613214),
    currentSearchMatchBackgroundColor: const Color(0xFF9E6A03),
    searchMatchTextColor: const Color(0xFFF7F7F7),
  ),
  CodeEditorThemePreset(
    id: 'vscode_light',
    label: 'VS Code Light+',
    highlightTheme: Map<String, TextStyle>.from(vsTheme),
    isDark: false,
    currentLineColor: const Color(0xFFEFF3F8),
    selectionColor: const Color(0xFFBBD8FB),
    gutterBackground: const Color(0xFFF7F9FC),
    activeLineNumberBackground: const Color(0xFFE8EEF6),
    lineNumberColor: const Color(0xFF616161),
    activeLineNumberColor: const Color(0xFF1F2328),
    indentGuideColor: const Color(0xFFD6DCE5),
    activeIndentGuideColor: const Color(0xFF9AA4B2),
    bracketPairColor: const Color(0xFF0F6CBD),
    rulerColor: const Color(0xFFE0E6EE),
    searchMatchBackgroundColor: const Color(0xFFFFE59A),
    currentSearchMatchBackgroundColor: const Color(0xFFF8C555),
    searchMatchTextColor: const Color(0xFF1F2328),
  ),
  CodeEditorThemePreset(
    id: 'one_dark',
    label: 'One Dark Pro',
    highlightTheme: Map<String, TextStyle>.from(atomOneDarkTheme),
    isDark: true,
    currentLineColor: const Color(0xFF2C313C),
    selectionColor: const Color(0xFF3E4451),
    gutterBackground: const Color(0xFF21252B),
    activeLineNumberBackground: const Color(0xFF2A2F37),
    lineNumberColor: const Color(0xFF636D83),
    activeLineNumberColor: const Color(0xFFABB2BF),
    indentGuideColor: const Color(0xFF3A404B),
    activeIndentGuideColor: const Color(0xFF59606D),
    bracketPairColor: const Color(0xFF61AFEF),
    rulerColor: const Color(0xFF353B45),
    searchMatchBackgroundColor: const Color(0xFF6B5330),
    currentSearchMatchBackgroundColor: const Color(0xFFC18F2B),
    searchMatchTextColor: const Color(0xFFF3F4F6),
  ),
  CodeEditorThemePreset(
    id: 'one_light',
    label: 'One Light',
    highlightTheme: Map<String, TextStyle>.from(atomOneLightTheme),
    isDark: false,
    currentLineColor: const Color(0xFFF0F4F8),
    selectionColor: const Color(0xFFD9E9FF),
    gutterBackground: const Color(0xFFFAFBFC),
    activeLineNumberBackground: const Color(0xFFECEFF4),
    lineNumberColor: const Color(0xFF6A737D),
    activeLineNumberColor: const Color(0xFF24292E),
    indentGuideColor: const Color(0xFFD4DAE3),
    activeIndentGuideColor: const Color(0xFF97A1AF),
    bracketPairColor: const Color(0xFF4078F2),
    rulerColor: const Color(0xFFE2E7EE),
    searchMatchBackgroundColor: const Color(0xFFFFE8A3),
    currentSearchMatchBackgroundColor: const Color(0xFFF4C95D),
    searchMatchTextColor: const Color(0xFF1B1F24),
  ),
  CodeEditorThemePreset(
    id: 'github_light',
    label: 'GitHub Light',
    highlightTheme: Map<String, TextStyle>.from(githubTheme),
    isDark: false,
    currentLineColor: const Color(0xFFF6F8FA),
    selectionColor: const Color(0xFFDDEBFF),
    gutterBackground: const Color(0xFFF6F8FA),
    activeLineNumberBackground: const Color(0xFFEAEEF2),
    lineNumberColor: const Color(0xFF6E7781),
    activeLineNumberColor: const Color(0xFF24292F),
    indentGuideColor: const Color(0xFFD0D7DE),
    activeIndentGuideColor: const Color(0xFF8C959F),
    bracketPairColor: const Color(0xFF0969DA),
    rulerColor: const Color(0xFFE1E4E8),
    searchMatchBackgroundColor: const Color(0xFFFFE58F),
    currentSearchMatchBackgroundColor: const Color(0xFFF2C94C),
    searchMatchTextColor: const Color(0xFF24292F),
  ),
  CodeEditorThemePreset(
    id: 'a11y_light',
    label: 'A11y Light',
    highlightTheme: Map<String, TextStyle>.from(a11yLightTheme),
    isDark: false,
    currentLineColor: const Color(0xFFF4F6F8),
    selectionColor: const Color(0xFFD6E6FF),
    gutterBackground: const Color(0xFFFCFCFC),
    activeLineNumberBackground: const Color(0xFFF0F3F6),
    lineNumberColor: const Color(0xFF575757),
    activeLineNumberColor: const Color(0xFF111111),
    indentGuideColor: const Color(0xFFD0D7DE),
    activeIndentGuideColor: const Color(0xFF8C959F),
    bracketPairColor: const Color(0xFF0550AE),
    rulerColor: const Color(0xFFE5EAF0),
    searchMatchBackgroundColor: const Color(0xFFFFE8A3),
    currentSearchMatchBackgroundColor: const Color(0xFFF2C94C),
    searchMatchTextColor: const Color(0xFF111827),
  ),
  CodeEditorThemePreset(
    id: 'gruvbox_dark',
    label: 'Gruvbox Dark',
    highlightTheme: Map<String, TextStyle>.from(gruvboxDarkTheme),
    isDark: true,
    currentLineColor: const Color(0xFF3C3836),
    selectionColor: const Color(0xFF504945),
    gutterBackground: const Color(0xFF282828),
    activeLineNumberBackground: const Color(0xFF32302F),
    lineNumberColor: const Color(0xFF928374),
    activeLineNumberColor: const Color(0xFFEBDBB2),
    indentGuideColor: const Color(0xFF504945),
    activeIndentGuideColor: const Color(0xFF7C6F64),
    bracketPairColor: const Color(0xFF83A598),
    rulerColor: const Color(0xFF3A3634),
    searchMatchBackgroundColor: const Color(0xFF665C2D),
    currentSearchMatchBackgroundColor: const Color(0xFFD79921),
    searchMatchTextColor: const Color(0xFF1D2021),
  ),
  CodeEditorThemePreset(
    id: 'gruvbox_light',
    label: 'Gruvbox Light',
    highlightTheme: Map<String, TextStyle>.from(gruvboxLightTheme),
    isDark: false,
    currentLineColor: const Color(0xFFF2E5BC),
    selectionColor: const Color(0xFFE5D5A4),
    gutterBackground: const Color(0xFFF9F5D7),
    activeLineNumberBackground: const Color(0xFFF0E0B4),
    lineNumberColor: const Color(0xFF7C6F64),
    activeLineNumberColor: const Color(0xFF3C3836),
    indentGuideColor: const Color(0xFFD5C4A1),
    activeIndentGuideColor: const Color(0xFFBDAE93),
    bracketPairColor: const Color(0xFF076678),
    rulerColor: const Color(0xFFE8DFC4),
    searchMatchBackgroundColor: const Color(0xFFF1D88A),
    currentSearchMatchBackgroundColor: const Color(0xFFD79921),
    searchMatchTextColor: const Color(0xFF3C3836),
  ),
  CodeEditorThemePreset(
    id: 'monokai',
    label: 'Monokai',
    highlightTheme: Map<String, TextStyle>.from(monokaiSublimeTheme),
    isDark: true,
    currentLineColor: const Color(0xFF2B2C27),
    selectionColor: const Color(0xFF49483E),
    gutterBackground: const Color(0xFF23241F),
    activeLineNumberBackground: const Color(0xFF2F3129),
    lineNumberColor: const Color(0xFF75715E),
    activeLineNumberColor: const Color(0xFFF8F8F2),
    indentGuideColor: const Color(0xFF414339),
    activeIndentGuideColor: const Color(0xFF6B705B),
    bracketPairColor: const Color(0xFF66D9EF),
    rulerColor: const Color(0xFF3A3C34),
    searchMatchBackgroundColor: const Color(0xFF665B2C),
    currentSearchMatchBackgroundColor: const Color(0xFFE6DB74),
    searchMatchTextColor: const Color(0xFF1E1F1C),
  ),
  CodeEditorThemePreset(
    id: 'dracula',
    label: 'Dracula',
    highlightTheme: Map<String, TextStyle>.from(draculaTheme),
    isDark: true,
    currentLineColor: const Color(0xFF343746),
    selectionColor: const Color(0xFF44475A),
    gutterBackground: const Color(0xFF282A36),
    activeLineNumberBackground: const Color(0xFF303341),
    lineNumberColor: const Color(0xFF6272A4),
    activeLineNumberColor: const Color(0xFFF8F8F2),
    indentGuideColor: const Color(0xFF44475A),
    activeIndentGuideColor: const Color(0xFF6272A4),
    bracketPairColor: const Color(0xFFBD93F9),
    rulerColor: const Color(0xFF3A3D4D),
    searchMatchBackgroundColor: const Color(0xFF5C4B1B),
    currentSearchMatchBackgroundColor: const Color(0xFFF1FA8C),
    searchMatchTextColor: const Color(0xFF1E1F29),
  ),
  CodeEditorThemePreset(
    id: 'nord',
    label: 'Nord',
    highlightTheme: Map<String, TextStyle>.from(nordTheme),
    isDark: true,
    currentLineColor: const Color(0xFF3B4252),
    selectionColor: const Color(0xFF434C5E),
    gutterBackground: const Color(0xFF2E3440),
    activeLineNumberBackground: const Color(0xFF3A4150),
    lineNumberColor: const Color(0xFF7D8796),
    activeLineNumberColor: const Color(0xFFE5E9F0),
    indentGuideColor: const Color(0xFF4C566A),
    activeIndentGuideColor: const Color(0xFF81A1C1),
    bracketPairColor: const Color(0xFF88C0D0),
    rulerColor: const Color(0xFF434C5E),
    searchMatchBackgroundColor: const Color(0xFF5E5A2F),
    currentSearchMatchBackgroundColor: const Color(0xFFEBCB8B),
    searchMatchTextColor: const Color(0xFF1F2937),
  ),
  CodeEditorThemePreset(
    id: 'night_owl',
    label: 'Night Owl',
    highlightTheme: Map<String, TextStyle>.from(nightOwlTheme),
    isDark: true,
    currentLineColor: const Color(0xFF102338),
    selectionColor: const Color(0xFF1D3B53),
    gutterBackground: const Color(0xFF011627),
    activeLineNumberBackground: const Color(0xFF0B2137),
    lineNumberColor: const Color(0xFF5F7E97),
    activeLineNumberColor: const Color(0xFFD6DEEB),
    indentGuideColor: const Color(0xFF1D3B53),
    activeIndentGuideColor: const Color(0xFF82AAFF),
    bracketPairColor: const Color(0xFF7FDBCA),
    rulerColor: const Color(0xFF16314B),
    searchMatchBackgroundColor: const Color(0xFF5E5324),
    currentSearchMatchBackgroundColor: const Color(0xFFECC48D),
    searchMatchTextColor: const Color(0xFF0B1320),
  ),
  CodeEditorThemePreset(
    id: 'a11y_dark',
    label: 'A11y Dark',
    highlightTheme: Map<String, TextStyle>.from(a11yDarkTheme),
    isDark: true,
    currentLineColor: const Color(0xFF1F1F24),
    selectionColor: const Color(0xFF2F333A),
    gutterBackground: const Color(0xFF1B1B1B),
    activeLineNumberBackground: const Color(0xFF252525),
    lineNumberColor: const Color(0xFFCAC59D),
    activeLineNumberColor: const Color(0xFFFFF4BF),
    indentGuideColor: const Color(0xFF4C4C4C),
    activeIndentGuideColor: const Color(0xFFFFD700),
    bracketPairColor: const Color(0xFFFFA07A),
    rulerColor: const Color(0xFF343434),
    searchMatchBackgroundColor: const Color(0xFF6C5A21),
    currentSearchMatchBackgroundColor: const Color(0xFFF5AB35),
    searchMatchTextColor: const Color(0xFF111111),
  ),
];

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
