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
                  presets: lightCodeEditorThemePresets,
                  selectedPresetId: editorPrefs.lightThemePresetId,
                  onPresetSelected: editorPrefs.setLightThemePreset,
                ),
                const SizedBox(height: 18),
                _ThemeSection(
                  title:
                      loc?.translate('settings_editor_dark_theme') ??
                      'Dark Theme',
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

class _ThemeSection extends StatelessWidget {
  final String title;
  final List<CodeEditorThemePreset> presets;
  final String selectedPresetId;
  final Future<void> Function(String) onPresetSelected;

  const _ThemeSection({
    required this.title,
    required this.presets,
    required this.selectedPresetId,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<EditorPreferencesProvider>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final useSideBySide = constraints.maxWidth >= 620;
            final selectorPane = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final preset in presets)
                  EditorThemePresetCard(
                    preset: preset,
                    selected: selectedPresetId == preset.id,
                    onTap: () => onPresetSelected(preset.id),
                  ),
              ],
            );
            final previewPane = EditorMonacoThemePreview(
              key: ValueKey(
                'monaco-preview-$selectedPresetId-${prefs.fontSize.toStringAsFixed(2)}-${prefs.tabSize}-${prefs.showRulers}-${prefs.defaultWrap}',
              ),
              preset: codeEditorThemePresetById(selectedPresetId),
              fontSize: prefs.fontSize,
              showRulers: prefs.showRulers,
              wrapEnabled: prefs.defaultWrap,
              tabSize: prefs.tabSize,
            );

            if (!useSideBySide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  selectorPane,
                  const SizedBox(height: 12),
                  previewPane,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 220, child: selectorPane),
                const SizedBox(width: 16),
                Expanded(child: previewPane),
              ],
            );
          },
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
    final background = root.backgroundColor ?? colorScheme.surface;
    final foreground = preset.isDark ? Colors.white : Colors.black;
    final accent = preset.isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.82);
    final presetLabel = _localizedEditorThemeLabel(
      loc,
      preset.id,
      preset.label,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                presetLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: selected
                  ? Container(
                      key: const ValueKey('selected'),
                      margin: const EdgeInsets.only(left: 10),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Icon(Icons.check_rounded, size: 14, color: accent),
                    )
                  : const SizedBox(
                      key: ValueKey('unselected'),
                      width: 20,
                      height: 20,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditorMonacoThemePreview extends StatefulWidget {
  final CodeEditorThemePreset preset;
  final double fontSize;
  final bool showRulers;
  final bool wrapEnabled;
  final int tabSize;

  const EditorMonacoThemePreview({
    super.key,
    required this.preset,
    required this.fontSize,
    required this.showRulers,
    required this.wrapEnabled,
    required this.tabSize,
  });

  static const _sample = r'''const theme = "d1vai";
interface ThemeConfig {
  accent: string;
  spacing: number;
}

export class PreviewPanel {
  constructor(private readonly config: ThemeConfig) {}

  render(count: number = 3): string {
    const title = `tokens:${count}`;
    return `${title}:${this.config.accent}`;
  }
}
''';

  @override
  State<EditorMonacoThemePreview> createState() =>
      _EditorMonacoThemePreviewState();
}

class _EditorMonacoThemePreviewState extends State<EditorMonacoThemePreview> {
  String? _activeThemeId;

  Future<void> _refreshThemeId(monaco.MonacoController controller) async {
    final themeId = await controller.getThemeId();
    if (!mounted) return;
    setState(() {
      _activeThemeId = themeId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final root = widget.preset.highlightTheme['root'] ?? const TextStyle();
    final bg = root.backgroundColor ?? theme.colorScheme.surface;
    final baseTheme = widget.preset.isDark
        ? monaco.MonacoTheme.vsDark
        : monaco.MonacoTheme.vs;
    final themeId = monacoThemeIdForPreset(
      'settings-preview',
      widget.preset.id,
    );
    final options = monaco.EditorOptions(
      language: monaco.MonacoLanguage.typescript,
      theme: baseTheme,
      fontSize: widget.fontSize,
      fontFamily: 'Menlo, Monaco, Consolas, "Courier New", monospace',
      lineHeight: 1.35,
      readOnly: true,
      minimap: false,
      lineNumbers: true,
      wordWrap: widget.wrapEnabled,
      automaticLayout: true,
      scrollBeyondLastLine: false,
      quickSuggestions: false,
      tabSize: widget.tabSize,
      rulers: widget.showRulers ? const [80, 120] : const [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                'settings-preview-${widget.preset.id}-${widget.fontSize.toStringAsFixed(2)}-${widget.tabSize}-${widget.showRulers}-${widget.wrapEnabled}',
              ),
              initialValue: EditorMonacoThemePreview._sample,
              options: options,
              themeId: themeId,
              onReady: (controller) {
                unawaited(() async {
                  final didRegisterTheme = await controller.tryDefineTheme(
                    themeId,
                    buildMonacoThemeDataForPreset(
                      widget.preset,
                      baseTheme: widget.preset.isDark ? 'vs-dark' : 'vs',
                    ),
                  );
                  await controller.setThemeById(
                    didRegisterTheme ? themeId : baseTheme.id,
                  );
                  await _refreshThemeId(controller);
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
