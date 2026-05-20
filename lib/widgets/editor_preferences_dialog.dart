import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_monaco/flutter_monaco.dart' as monaco;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/editor_preferences_provider.dart';
import 'adaptive_modal.dart';
import 'button.dart';
import 'card.dart';
import 'snackbar_helper.dart';
import 'chat/project_chat/code_tab/app_code_editor_controller.dart';
import 'chat/project_chat/code_tab/code_editor_theme_presets.dart';

class EditorPreferencesDialogBody extends StatelessWidget {
  const EditorPreferencesDialogBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorPreferencesProvider>(
      builder: (context, editorPrefs, child) {
        final loc = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return AdaptiveModalContainer(
          maxWidth: 720,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveModalHeader(
                  title:
                      loc?.translate('settings_editor_title') ?? 'Code Editor',
                  subtitle:
                      loc?.translate('settings_editor_subtitle') ??
                      'Tune editor visuals toward a VS Code-style workbench.',
                  onClose: () => Navigator.of(context).pop(),
                ),
                Text(
                  loc?.translate('settings_editor_appearance_mode') ??
                      'Appearance Mode',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final mode in EditorAppearanceMode.values)
                      ChoiceChip(
                        label: Text(switch (mode) {
                          EditorAppearanceMode.followApp =>
                            loc?.translate(
                                  'settings_editor_appearance_follow_app',
                                ) ??
                                'Follow App',
                          EditorAppearanceMode.forceLight =>
                            loc?.translate(
                                  'settings_editor_appearance_light',
                                ) ??
                                'Light',
                          EditorAppearanceMode.forceDark =>
                            loc?.translate('settings_editor_appearance_dark') ??
                                'Dark',
                        }),
                        selected: editorPrefs.appearanceMode == mode,
                        onSelected: (_) => editorPrefs.setAppearanceMode(mode),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _ThemeSection(
                  title:
                      loc?.translate('settings_editor_light_theme') ??
                      'Light Theme',
                  titleText:
                      loc?.translate('settings_editor_light_preview') ??
                      'Light Preview',
                  presets: lightCodeEditorThemePresets,
                  selectedPresetId: editorPrefs.lightThemePresetId,
                  onPresetSelected: editorPrefs.setLightThemePreset,
                ),
                const SizedBox(height: 18),
                _ThemeSection(
                  title:
                      loc?.translate('settings_editor_dark_theme') ??
                      'Dark Theme',
                  titleText:
                      loc?.translate('settings_editor_dark_preview') ??
                      'Dark Preview',
                  presets: darkCodeEditorThemePresets,
                  selectedPresetId: editorPrefs.darkThemePresetId,
                  onPresetSelected: editorPrefs.setDarkThemePreset,
                ),
                const SizedBox(height: 18),
                CustomCard(
                  embedded: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc?.translate('settings_editor_font_size') ??
                            'Font Size',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              min: 11,
                              max: 16,
                              divisions: 10,
                              value: editorPrefs.fontSize,
                              onChanged: editorPrefs.setFontSize,
                            ),
                          ),
                          Container(
                            width: 56,
                            alignment: Alignment.centerRight,
                            child: Text(
                              editorPrefs.fontSize.toStringAsFixed(1),
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            loc?.translate('settings_editor_tab_size') ??
                                'Tab Size',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final size in [2, 4, 8])
                                ChoiceChip(
                                  label: Text('$size'),
                                  selected: editorPrefs.tabSize == size,
                                  onSelected: (_) =>
                                      editorPrefs.setTabSize(size),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          loc?.translate('settings_editor_show_rulers') ??
                              'Show Rulers',
                        ),
                        subtitle: Text(
                          loc?.translate('settings_editor_show_rulers_hint') ??
                              'Display vertical rulers at columns 80 and 120.',
                        ),
                        value: editorPrefs.showRulers,
                        onChanged: editorPrefs.setShowRulers,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          loc?.translate('settings_editor_default_wrap') ??
                              'Default Wrap',
                        ),
                        subtitle: Text(
                          loc?.translate('settings_editor_default_wrap_hint') ??
                              'Open editors with word wrap enabled by default.',
                        ),
                        value: editorPrefs.defaultWrap,
                        onChanged: editorPrefs.setDefaultWrap,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Button(
                      variant: ButtonVariant.ghost,
                      text: loc?.translate('close') ?? 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    Button(
                      text: loc?.translate('apply') ?? 'Apply',
                      onPressed: () {
                        Navigator.of(context).pop();
                        SnackBarHelper.showSuccess(
                          context,
                          title:
                              loc?.translate('settings_editor_updated') ??
                              'Editor Updated',
                          message:
                              loc?.translate('settings_editor_saved_message') ??
                              'Light theme, dark theme, appearance mode, and editor preferences saved.',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  loc?.translate('settings_editor_footer') ??
                      'Pick separate light and dark editor themes, then decide whether the editor follows the app appearance or stays fixed.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final String number;
  final List<InlineSpan> spans;
  final Color numberColor;

  const _PreviewLine({
    required this.number,
    required this.spans,
    required this.numberColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Text(
              number,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: numberColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(text: TextSpan(children: spans)),
          ),
        ],
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  final String title;
  final String titleText;
  final List<CodeEditorThemePreset> presets;
  final String selectedPresetId;
  final Future<void> Function(String) onPresetSelected;

  const _ThemeSection({
    required this.title,
    required this.titleText,
    required this.presets,
    required this.selectedPresetId,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<EditorPreferencesProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final preset in presets)
              EditorThemePresetCard(
                preset: preset,
                selected: selectedPresetId == preset.id,
                onTap: () => onPresetSelected(preset.id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        EditorMonacoThemePreview(
          key: ValueKey(
            'monaco-preview-$selectedPresetId-${prefs.fontSize.toStringAsFixed(2)}-${prefs.tabSize}-${prefs.showRulers}-${prefs.defaultWrap}',
          ),
          title: titleText,
          preset: codeEditorThemePresetById(selectedPresetId),
          fontSize: prefs.fontSize,
          showRulers: prefs.showRulers,
          wrapEnabled: prefs.defaultWrap,
          tabSize: prefs.tabSize,
        ),
      ],
    );
  }
}

class EditorThemePresetCard extends StatelessWidget {
  final CodeEditorThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const EditorThemePresetCard({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final root = preset.highlightTheme['root'] ?? const TextStyle();
    final bg = root.backgroundColor ?? colorScheme.surface;
    final fg = root.color ?? colorScheme.onSurface;
    final presetLabel = _localizedEditorThemeLabel(
      loc,
      preset.id,
      preset.label,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              presetLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 108,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.8,
                  color: fg,
                  height: 1.24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PreviewLine(
                      number: '1',
                      spans: [
                        TextSpan(
                          text: 'const ',
                          style: preset.highlightTheme['keyword'],
                        ),
                        TextSpan(
                          text: 'theme',
                          style: preset.highlightTheme['variable'],
                        ),
                        const TextSpan(text: ' = '),
                        TextSpan(
                          text: '"$presetLabel"',
                          style: preset.highlightTheme['string'],
                        ),
                        const TextSpan(text: ';'),
                      ],
                      numberColor: fg.withValues(alpha: 0.45),
                    ),
                    _PreviewLine(
                      number: '2',
                      spans: [
                        TextSpan(
                          text:
                              '// ${loc?.translate('settings_editor_preview_comment') ?? 'VS Code-style preview'}',
                          style: preset.highlightTheme['comment'],
                        ),
                      ],
                      numberColor: fg.withValues(alpha: 0.45),
                    ),
                    _PreviewLine(
                      number: '3',
                      spans: [
                        TextSpan(
                          text: 'return ',
                          style: preset.highlightTheme['keyword'],
                        ),
                        TextSpan(
                          text: 'editor',
                          style: preset.highlightTheme['title'],
                        ),
                        const TextSpan(text: ';'),
                      ],
                      numberColor: fg.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditorMonacoThemePreview extends StatelessWidget {
  final String title;
  final CodeEditorThemePreset preset;
  final double fontSize;
  final bool showRulers;
  final bool wrapEnabled;
  final int tabSize;

  const EditorMonacoThemePreview({
    super.key,
    required this.title,
    required this.preset,
    required this.fontSize,
    required this.showRulers,
    required this.wrapEnabled,
    required this.tabSize,
  });

  static const _sample = '''const theme = "d1vai";
// Monaco preview for settings
return editor;
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final root = preset.highlightTheme['root'] ?? const TextStyle();
    final bg = root.backgroundColor ?? theme.colorScheme.surface;
    final baseTheme = preset.isDark
        ? monaco.MonacoTheme.vsDark
        : monaco.MonacoTheme.vs;
    final themeId = 'settings-preview-${preset.id}';
    final options = monaco.EditorOptions(
      language: monaco.MonacoLanguage.dart,
      theme: baseTheme,
      fontSize: fontSize,
      fontFamily: 'Menlo, Monaco, Consolas, "Courier New", monospace',
      lineHeight: 1.35,
      readOnly: true,
      minimap: false,
      lineNumbers: true,
      wordWrap: wrapEnabled,
      automaticLayout: true,
      scrollBeyondLastLine: false,
      quickSuggestions: false,
      tabSize: tabSize,
      rulers: showRulers ? const [80, 120] : const [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: monaco.MonacoEditor(
              key: ValueKey(
                'settings-preview-${preset.id}-${fontSize.toStringAsFixed(2)}-$tabSize-$showRulers-$wrapEnabled',
              ),
              initialValue: _sample,
              options: options,
              onReady: (controller) {
                unawaited(() async {
                  final didRegisterTheme = await controller.tryDefineTheme(
                    themeId,
                    buildMonacoThemeDataForPreset(
                      preset,
                      baseTheme: preset.isDark ? 'vs-dark' : 'vs',
                    ),
                  );
                  await controller.setThemeById(
                    didRegisterTheme ? themeId : baseTheme.id,
                  );
                }());
              },
              backgroundColor: bg,
              showStatusBar: false,
              loadingBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }
}

String _localizedEditorThemeLabel(
  AppLocalizations? loc,
  String presetId,
  String fallback,
) {
  final key = switch (presetId) {
    'vscode_dark' => 'settings_editor_theme_vscode_dark',
    'vscode_light' => 'settings_editor_theme_vscode_light',
    'one_dark' => 'settings_editor_theme_one_dark',
    'one_light' => 'settings_editor_theme_one_light',
    'github_light' => 'settings_editor_theme_github_light',
    'a11y_light' => 'settings_editor_theme_a11y_light',
    'gruvbox_dark' => 'settings_editor_theme_gruvbox_dark',
    'gruvbox_light' => 'settings_editor_theme_gruvbox_light',
    'monokai' => 'settings_editor_theme_monokai',
    'dracula' => 'settings_editor_theme_dracula',
    'nord' => 'settings_editor_theme_nord',
    'night_owl' => 'settings_editor_theme_night_owl',
    _ => null,
  };
  if (key == null) return fallback;
  final value = loc?.translate(key);
  if (value == null || value == key) return fallback;
  return value;
}
