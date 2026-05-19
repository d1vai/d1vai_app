import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_monaco/flutter_monaco.dart' as monaco;
import 'package:provider/provider.dart';

import '../../providers/editor_preferences_provider.dart';
import 'project_chat/code_tab/app_code_editor_controller.dart';
import 'project_chat/code_tab/code_editor_theme_presets.dart';

class MonacoCodePreview extends StatefulWidget {
  final String path;
  final String content;

  const MonacoCodePreview({
    super.key,
    required this.path,
    required this.content,
  });

  @override
  State<MonacoCodePreview> createState() => _MonacoCodePreviewState();
}

class _MonacoCodePreviewState extends State<MonacoCodePreview> {
  monaco.MonacoController? _controller;
  monaco.EditorOptions? _options;
  Object? _error;
  String? _lastPresentationKey;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant MonacoCodePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.content != widget.content) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final old = _controller;
    final prefs = context.read<EditorPreferencesProvider>();
    final controller = await monaco.MonacoController.create(
      options: monaco.EditorOptions(
        language: monacoLanguageForPath(widget.path),
        theme: monaco.MonacoTheme.vs,
        fontSize: prefs.fontSize,
        fontFamily: 'Menlo, Monaco, Consolas, "Courier New", monospace',
        lineHeight: 1.3,
        wordWrap: prefs.defaultWrap,
        minimap: false,
        lineNumbers: true,
        rulers: prefs.showRulers ? const [80, 120] : const [],
        tabSize: prefs.tabSize,
        insertSpaces: true,
        readOnly: true,
        automaticLayout: true,
        scrollBeyondLastLine: false,
        formatOnPaste: false,
        formatOnType: false,
        quickSuggestions: false,
        mouseWheelZoom: false,
        roundedSelection: true,
        selectionHighlight: true,
        bracketPairColorization: true,
      ),
    );

    try {
      await controller.setValue(widget.content);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _options = monaco.EditorOptions(
          language: monacoLanguageForPath(widget.path),
          theme: monaco.MonacoTheme.vs,
          fontSize: prefs.fontSize,
          fontFamily: 'Menlo, Monaco, Consolas, "Courier New", monospace',
          lineHeight: 1.3,
          wordWrap: prefs.defaultWrap,
          minimap: false,
          lineNumbers: true,
          rulers: prefs.showRulers ? const [80, 120] : const [],
          tabSize: prefs.tabSize,
          insertSpaces: true,
          readOnly: true,
          automaticLayout: true,
          scrollBeyondLastLine: false,
          formatOnPaste: false,
          formatOnType: false,
          quickSuggestions: false,
          mouseWheelZoom: false,
          roundedSelection: true,
          selectionHighlight: true,
          bracketPairColorization: true,
        );
        _error = null;
        _lastPresentationKey = null;
      });
      old?.dispose();
      _syncPresentation();
    } catch (e) {
      controller.dispose();
      if (!mounted) return;
      setState(() {
        _error = e;
      });
      old?.dispose();
    }
  }

  Future<void> _syncPresentation() async {
    final controller = _controller;
    final options = _options;
    if (controller == null || options == null || !mounted) return;

    final prefs = context.read<EditorPreferencesProvider>();
    final appBrightness = Theme.of(context).brightness;
    final prefersDark = switch (prefs.appearanceMode) {
      EditorAppearanceMode.forceDark => true,
      EditorAppearanceMode.forceLight => false,
      EditorAppearanceMode.followApp => appBrightness == Brightness.dark,
    };
    final preset = codeEditorThemePresetById(
      prefersDark ? prefs.darkThemePresetId : prefs.lightThemePresetId,
    );

    final nextOptions = options.copyWith(
      language: monacoLanguageForPath(widget.path),
      fontSize: prefs.fontSize,
      wordWrap: prefs.defaultWrap,
      rulers: prefs.showRulers ? const [80, 120] : const [],
      tabSize: prefs.tabSize,
      readOnly: true,
      quickSuggestions: false,
      hover: true,
      contextMenu: true,
      minimap: false,
    );

    final key = [
      widget.path,
      widget.content.length,
      prefs.fontSize.toStringAsFixed(2),
      prefs.defaultWrap,
      prefs.showRulers,
      prefs.tabSize,
      prefersDark,
      preset.id,
    ].join('|');
    if (_lastPresentationKey == key) return;
    _lastPresentationKey = key;
    _options = nextOptions;

    final themeId = 'd1vai-preview-${preset.id}';
    final didRegisterTheme = await controller.tryDefineTheme(
      themeId,
      buildMonacoThemeDataForPreset(
        preset,
        baseTheme: prefersDark ? 'vs-dark' : 'vs',
      ),
    );
    await controller.updateOptions(nextOptions);
    await controller.setThemeById(
      didRegisterTheme ? themeId : (prefersDark ? 'vs-dark' : 'vs'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final options = _options;

    if (_error != null) {
      return Center(
        child: Text(
          'Monaco preview unavailable.\n$_error',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (controller == null || options == null) {
      return const Center(child: CircularProgressIndicator());
    }

    unawaited(_syncPresentation());

    final prefs = context.watch<EditorPreferencesProvider>();
    final appBrightness = Theme.of(context).brightness;
    final prefersDark = switch (prefs.appearanceMode) {
      EditorAppearanceMode.forceDark => true,
      EditorAppearanceMode.forceLight => false,
      EditorAppearanceMode.followApp => appBrightness == Brightness.dark,
    };
    final preset = codeEditorThemePresetById(
      prefersDark ? prefs.darkThemePresetId : prefs.lightThemePresetId,
    );

    return Container(
      color: preset.gutterBackground,
      child: monaco.MonacoEditor(
        key: ValueKey('preview-${widget.path}'),
        controller: controller,
        options: options,
        backgroundColor: preset.gutterBackground,
        showStatusBar: false,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
