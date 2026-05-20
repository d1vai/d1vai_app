import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_monaco/flutter_monaco.dart' as monaco;
import 'package:provider/provider.dart';

import '../../../../providers/editor_preferences_provider.dart';
import 'app_code_editor_controller.dart';
import 'code_editor_theme_presets.dart';

class CodeTabEditor extends StatefulWidget {
  final AppCodeEditorController controller;
  final String originalText;
  final String languageLabel;
  final bool wrapEnabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onToggleWrap;
  final bool compact;

  const CodeTabEditor({
    super.key,
    required this.controller,
    required this.originalText,
    required this.languageLabel,
    required this.wrapEnabled,
    required this.onChanged,
    required this.onCancel,
    required this.onToggleWrap,
    this.compact = false,
  });

  @override
  State<CodeTabEditor> createState() => _CodeTabEditorState();
}

class _CodeTabEditorState extends State<CodeTabEditor> {
  String? _lastMonacoSyncKey;

  @override
  Widget build(BuildContext context) {
    final editorPrefs = context.watch<EditorPreferencesProvider>();
    final brightness = Theme.of(context).brightness;
    final prefersDark = switch (editorPrefs.appearanceMode) {
      EditorAppearanceMode.forceDark => true,
      EditorAppearanceMode.forceLight => false,
      EditorAppearanceMode.followApp => brightness == Brightness.dark,
    };
    final preset = codeEditorThemePresetById(
      prefersDark
          ? editorPrefs.darkThemePresetId
          : editorPrefs.lightThemePresetId,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final root = (preset.highlightTheme['root'] ?? const TextStyle()).copyWith(
      backgroundColor:
          (preset.highlightTheme['root']?.backgroundColor) ??
          (preset.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF)),
      fontFamily: 'monospace',
      fontSize: editorPrefs.fontSize,
      height: 1.3,
    );

    _syncMonacoPresentationIfNeeded(
      preferences: editorPrefs,
      preset: preset,
      prefersDark: prefersDark,
    );

    return Column(
      children: [
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final dirty = widget.controller.hasUnsavedChanges;
            final tint = dirty ? colorScheme.tertiary : colorScheme.primary;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 12,
                vertical: widget.compact ? 5 : 7,
              ),
              decoration: BoxDecoration(
                color: root.backgroundColor ?? colorScheme.surface,
              ),
              child: Row(
                children: [
                  Icon(
                    dirty ? Icons.circle : Icons.check_circle,
                    size: 14,
                    color: tint.withValues(alpha: dirty ? 0.9 : 0.95),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dirty ? 'Unsaved changes' : 'Editing',
                      style: TextStyle(
                        fontSize: widget.compact ? 11 : 11.5,
                        color: (root.color ?? colorScheme.onSurface).withValues(
                          alpha: preset.isDark ? 0.72 : 0.84,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: widget.onCancel,
                    child: const Text('Revert'),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: _MonacoEditorSurface(
            controller: widget.controller,
            preset: preset,
            fontSize: editorPrefs.fontSize,
            preferences: editorPrefs,
            prefersDark: prefersDark,
          ),
        ),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final stats = widget.controller.stats;
            final dirty = widget.controller.hasUnsavedChanges;
            final tint = dirty ? colorScheme.tertiary : colorScheme.primary;
            return Column(
              children: [
                Container(
                  height: widget.compact ? 24 : 26,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 10 : 12,
                  ),
                  decoration: BoxDecoration(color: preset.gutterBackground),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                dirty ? 'LOCAL CHANGES' : 'EDITOR',
                                style: TextStyle(
                                  fontSize: widget.compact ? 10 : 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: tint,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Ln ${stats.cursorLine}, Col ${stats.cursorColumn}',
                                style: TextStyle(
                                  fontSize: widget.compact ? 10 : 10.5,
                                  color: preset.activeLineNumberColor
                                      .withValues(
                                        alpha: preset.isDark ? 0.82 : 0.88,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.languageLabel,
                                style: TextStyle(
                                  fontSize: widget.compact ? 10 : 10.5,
                                  color: preset.activeLineNumberColor
                                      .withValues(
                                        alpha: preset.isDark ? 0.78 : 0.84,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Spaces: ${widget.controller.tabSize}',
                                style: TextStyle(
                                  fontSize: widget.compact ? 10 : 10.5,
                                  color: preset.activeLineNumberColor
                                      .withValues(
                                        alpha: preset.isDark ? 0.78 : 0.84,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _StatusAction(
                                label: widget.wrapEnabled
                                    ? 'Wrap On'
                                    : 'Wrap Off',
                                onTap: widget.onToggleWrap ?? () {},
                              ),
                              if (stats.selectionLength > 0) ...[
                                const SizedBox(width: 12),
                                Text(
                                  'Sel ${stats.selectionLength}',
                                  style: TextStyle(
                                    fontSize: widget.compact ? 10 : 10.5,
                                    color: preset.activeLineNumberColor
                                        .withValues(
                                          alpha: preset.isDark ? 0.78 : 0.84,
                                        ),
                                  ),
                                ),
                                if (stats.selectedLineCount > 1) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${stats.selectedLineCount} lines',
                                    style: TextStyle(
                                      fontSize: widget.compact ? 10 : 10.5,
                                      color: preset.activeLineNumberColor
                                          .withValues(
                                            alpha: preset.isDark ? 0.78 : 0.84,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                              if (widget.controller.supportsFoldAll) ...[
                                const SizedBox(width: 12),
                                _StatusAction(
                                  label: 'Fold All',
                                  onTap: widget.controller.foldAll,
                                ),
                                const SizedBox(width: 8),
                                _StatusAction(
                                  label: 'Unfold All',
                                  onTap: widget.controller.unfoldAll,
                                ),
                              ],
                              if (widget.controller.supportsFoldImports) ...[
                                const SizedBox(width: 8),
                                _StatusAction(
                                  label: 'Fold Imports',
                                  onTap: widget.controller.foldImports,
                                ),
                              ],
                              if (widget.controller.supportsFoldHeader) ...[
                                const SizedBox(width: 8),
                                _StatusAction(
                                  label: 'Fold Header',
                                  onTap: widget.controller.foldHeader,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${stats.lineCount} lines',
                        style: TextStyle(
                          fontSize: widget.compact ? 10 : 10.5,
                          color: preset.activeLineNumberColor.withValues(
                            alpha: preset.isDark ? 0.78 : 0.84,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${stats.charCount} chars',
                        style: TextStyle(
                          fontSize: widget.compact ? 10 : 10.5,
                          color: preset.activeLineNumberColor.withValues(
                            alpha: preset.isDark ? 0.78 : 0.84,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 2,
                  color: dirty
                      ? tint.withValues(alpha: 0.85)
                      : colorScheme.primary.withValues(alpha: 0.28),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _syncMonacoPresentationIfNeeded({
    required EditorPreferencesProvider preferences,
    required CodeEditorThemePreset preset,
    required bool prefersDark,
  }) {
    if (!widget.controller.isMonaco) {
      _lastMonacoSyncKey = null;
      return;
    }

    final key = [
      widget.controller.filePath,
      preferences.fontSize.toStringAsFixed(2),
      preferences.showRulers,
      preferences.tabSize,
      widget.wrapEnabled,
      prefersDark,
      preset.id,
    ].join('|');
    if (_lastMonacoSyncKey == key) return;
    _lastMonacoSyncKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        widget.controller.applyMonacoPresentation(
          preferences: preferences,
          preset: preset,
          prefersDark: prefersDark,
          readOnly: false,
        ),
      );
    });
  }
}

class _MonacoEditorSurface extends StatelessWidget {
  final AppCodeEditorController controller;
  final CodeEditorThemePreset preset;
  final double fontSize;
  final EditorPreferencesProvider preferences;
  final bool prefersDark;

  const _MonacoEditorSurface({
    required this.controller,
    required this.preset,
    required this.fontSize,
    required this.preferences,
    required this.prefersDark,
  });

  @override
  Widget build(BuildContext context) {
    final monacoController = controller.monacoController;
    final options = controller.monacoOptions;
    if (monacoController == null || options == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: preset.gutterBackground,
      child: monaco.MonacoEditor(
        controller: monacoController,
        options: options,
        onReady: (_) {
          unawaited(
            controller.applyMonacoPresentation(
              preferences: preferences,
              preset: preset,
              prefersDark: prefersDark,
              readOnly: false,
            ),
          );
        },
        backgroundColor: preset.gutterBackground,
        showStatusBar: false,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StatusAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
