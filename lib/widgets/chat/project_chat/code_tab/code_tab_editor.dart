import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:provider/provider.dart';

import '../../../../providers/editor_preferences_provider.dart';
import 'code_editor_theme_presets.dart';

class CodeTabEditor extends StatelessWidget {
  final CodeController controller;
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
    final codeTheme = Map<String, TextStyle>.from(preset.highlightTheme);
    final root = codeTheme['root'] ?? const TextStyle();
    codeTheme['root'] = root.copyWith(
      backgroundColor:
          root.backgroundColor ??
          (preset.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF)),
      fontFamily: 'monospace',
      fontSize: editorPrefs.fontSize,
      height: 1.3,
    );
    final codeThemeData = CodeThemeData(
      styles: codeTheme,
      searchMatchBackgroundColor: preset.searchMatchBackgroundColor,
      currentSearchMatchBackgroundColor:
          preset.currentSearchMatchBackgroundColor,
      searchMatchTextColor: preset.searchMatchTextColor,
    );

    return Column(
      children: [
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final dirty = controller.fullText != originalText;
            final tint = dirty ? colorScheme.tertiary : colorScheme.primary;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 5 : 7,
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
                        fontSize: compact ? 11 : 11.5,
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
                    onPressed: onCancel,
                    child: const Text('Revert'),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: CodeTheme(
            data: codeThemeData,
            child: CodeField(
              controller: controller,
              onChanged: onChanged,
              expands: true,
              wrap: wrapEnabled,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.25,
                height: 1.3,
              ).copyWith(fontSize: editorPrefs.fontSize),
              gutterStyle: GutterStyle(
                width: compact ? 60 : 68,
                margin: compact ? 8 : 10,
                background: preset.gutterBackground,
                activeLineBackground: preset.activeLineNumberBackground,
                textStyle: TextStyle(
                  color: preset.lineNumberColor,
                  fontFamily: 'monospace',
                  fontSize: editorPrefs.fontSize,
                  height: 1.3,
                ),
                activeLineTextStyle: TextStyle(
                  color: preset.activeLineNumberColor,
                  fontFamily: 'monospace',
                  fontSize: editorPrefs.fontSize,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
                showErrors: false,
                showFoldingHandles: true,
                showLineNumbers: true,
              ),
              decoration: BoxDecoration(
                color: root.backgroundColor ?? colorScheme.surface,
              ),
              currentLineColor: preset.currentLineColor,
              highlightCurrentLine: true,
              showIndentGuides: true,
              indentGuideColor: preset.indentGuideColor,
              activeIndentGuideColor: preset.activeIndentGuideColor,
              highlightBracketPairs: true,
              bracketPairColor: preset.bracketPairColor,
              rulers: editorPrefs.showRulers ? const [80, 120] : const [],
              rulerColor: preset.rulerColor,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 9 : 11,
              ),
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textSelectionTheme: TextSelectionThemeData(
                selectionColor: preset.selectionColor,
                selectionHandleColor: colorScheme.primary,
                cursorColor: colorScheme.primary,
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final text = controller.fullText;
            final dirty = text != originalText;
            final lineCount = '\n'.allMatches(text).length + 1;
            final charCount = text.characters.length;
            final tint = dirty ? colorScheme.tertiary : colorScheme.primary;
            final selection = controller.selection;
            final visibleOffset =
                selection.isValid && selection.extentOffset >= 0
                ? selection.extentOffset.clamp(0, controller.text.length)
                : 0;
            final fullOffset = controller.code.hiddenRanges.recoverPosition(
              visibleOffset,
              placeHiddenRanges: TextAffinity.downstream,
            );
            final lineIndex = controller.code.lines.characterIndexToLineIndex(
              fullOffset,
            );
            final lineStart =
                controller.code.lines.lines[lineIndex].textRange.start;
            final column = (fullOffset - lineStart) + 1;
            final canFold = controller.code.foldableBlocks.isNotEmpty;
            final selectionLength = selection.isValid && !selection.isCollapsed
                ? (selection.end - selection.start).abs()
                : 0;
            final selectedLineRange = selectionLength > 0
                ? controller.getSelectedLineRange()
                : null;
            final selectedLineCount = selectedLineRange == null
                ? 0
                : selectedLineRange.end - selectedLineRange.start;
            return Column(
              children: [
                Container(
                  height: compact ? 24 : 26,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
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
                                  fontSize: compact ? 10 : 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: tint,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Ln ${lineIndex + 1}, Col $column',
                                style: TextStyle(
                                  fontSize: compact ? 10 : 10.5,
                                  color: preset.activeLineNumberColor
                                      .withValues(
                                        alpha: preset.isDark ? 0.82 : 0.88,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                languageLabel,
                                style: TextStyle(
                                  fontSize: compact ? 10 : 10.5,
                                  color: preset.activeLineNumberColor
                                      .withValues(
                                        alpha: preset.isDark ? 0.78 : 0.84,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Spaces: ${controller.params.tabSpaces}',
                                style: TextStyle(
                                  fontSize: compact ? 10 : 10.5,
                                  color: preset.activeLineNumberColor
                                      .withValues(
                                        alpha: preset.isDark ? 0.78 : 0.84,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _StatusAction(
                                label: wrapEnabled ? 'Wrap On' : 'Wrap Off',
                                onTap: onToggleWrap ?? () {},
                              ),
                              if (selectionLength > 0) ...[
                                const SizedBox(width: 12),
                                Text(
                                  'Sel $selectionLength',
                                  style: TextStyle(
                                    fontSize: compact ? 10 : 10.5,
                                    color: preset.activeLineNumberColor
                                        .withValues(
                                          alpha: preset.isDark ? 0.78 : 0.84,
                                        ),
                                  ),
                                ),
                                if (selectedLineCount > 1) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '$selectedLineCount lines',
                                    style: TextStyle(
                                      fontSize: compact ? 10 : 10.5,
                                      color: preset.activeLineNumberColor
                                          .withValues(
                                            alpha: preset.isDark ? 0.78 : 0.84,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                              if (canFold) ...[
                                const SizedBox(width: 12),
                                _StatusAction(
                                  label: 'Fold All',
                                  onTap: controller.foldAll,
                                ),
                                const SizedBox(width: 8),
                                _StatusAction(
                                  label: 'Unfold All',
                                  onTap: controller.unfoldAll,
                                ),
                                const SizedBox(width: 8),
                                _StatusAction(
                                  label: 'Fold Imports',
                                  onTap: controller.foldImports,
                                ),
                                const SizedBox(width: 8),
                                _StatusAction(
                                  label: 'Fold Header',
                                  onTap: controller.foldCommentAtLineZero,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$lineCount lines',
                        style: TextStyle(
                          fontSize: compact ? 10 : 10.5,
                          color: preset.activeLineNumberColor.withValues(
                            alpha: preset.isDark ? 0.78 : 0.84,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$charCount chars',
                        style: TextStyle(
                          fontSize: compact ? 10 : 10.5,
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
}

class _StatusAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StatusAction({required this.label, required this.onTap});

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
    final color = preset.isDark
        ? preset.bracketPairColor
        : preset.activeLineNumberColor;
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
