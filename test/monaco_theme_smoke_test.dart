import 'dart:convert';

import 'package:d1vai_app/widgets/chat/project_chat/code_tab/app_code_editor_controller.dart';
import 'package:d1vai_app/widgets/chat/project_chat/code_tab/code_editor_theme_presets.dart';
import 'package:flutter_monaco/flutter_monaco.dart';
import 'package:flutter_test/flutter_test.dart';

import '../third_party/flutter_monaco/test/fakes/fake_platform_webview_controller.dart';

void main() {
  test('all app editor presets produce json-encodable monaco themes', () {
    for (final preset in codeEditorThemePresets) {
      final theme = buildMonacoThemeDataForPreset(
        preset,
        baseTheme: preset.isDark ? 'vs-dark' : 'vs',
      );
      expect(theme['base'], isNotEmpty, reason: preset.id);
      expect(theme['colors'], isA<Map<String, dynamic>>(), reason: preset.id);
      expect(theme['rules'], isA<List<dynamic>>(), reason: preset.id);
      expect(() => jsonEncode(theme), returnsNormally, reason: preset.id);
    }
  });

  test(
    'all app editor presets can be registered through monaco controller',
    () async {
      final webview = FakePlatformWebViewController();
      final controller = await MonacoController.createForTesting(
        webViewController: webview,
        markReady: true,
      );

      for (final preset in codeEditorThemePresets) {
        final themeName = 'smoke-${preset.id}';
        final didRegister = await controller.tryDefineTheme(
          themeName,
          buildMonacoThemeDataForPreset(
            preset,
            baseTheme: preset.isDark ? 'vs-dark' : 'vs',
          ),
        );
        expect(didRegister, isTrue, reason: preset.id);
        expect(
          webview.executed.any(
            (script) =>
                script.contains('defineTheme') && script.contains(themeName),
          ),
          isTrue,
          reason: preset.id,
        );
      }
    },
  );
}
