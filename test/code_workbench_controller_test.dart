import 'package:d1vai_app/services/d1vai_service.dart';
import 'package:d1vai_app/widgets/chat/project_chat/code_tab/code_tab_models.dart';
import 'package:d1vai_app/widgets/chat/project_chat/code_tab/code_workbench_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodeWorkbenchController tree selection', () {
    late CodeWorkbenchController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      controller = CodeWorkbenchController(service: D1vaiService());
    });

    tearDown(() {
      controller.dispose();
    });

    test(
      'selectTreePath updates the tree listenable without rebuilding workbench listeners',
      () {
        var workbenchNotifications = 0;
        final selectedPathUpdates = <String?>[];

        controller.addListener(() {
          workbenchNotifications += 1;
        });
        controller.selectedTreePathListenable.addListener(() {
          selectedPathUpdates.add(controller.selectedTreePath);
        });

        controller.selectTreePath('lib/main.dart');

        expect(controller.selectedTreePath, 'lib/main.dart');
        expect(selectedPathUpdates, <String?>['lib/main.dart']);
        expect(workbenchNotifications, 0);
      },
    );

    test('renamePathPrefix keeps the selected tree path in sync', () {
      final selectedPathUpdates = <String?>[];
      var workbenchNotifications = 0;

      controller.selectTreePath('src/legacy/file.dart');
      controller.selectedTreePathListenable.addListener(() {
        selectedPathUpdates.add(controller.selectedTreePath);
      });
      controller.addListener(() {
        workbenchNotifications += 1;
      });

      controller.renamePathPrefix('src/legacy', 'src/current');

      expect(controller.selectedTreePath, 'src/current/file.dart');
      expect(selectedPathUpdates, <String?>['src/current/file.dart']);
      expect(workbenchNotifications, 1);
    });

    test('preview open keeps controller lazy until edit mode', () async {
      await controller.openLocalFile(
        'lib/main.dart',
        content: const CodeTabFileContent(
          path: 'lib/main.dart',
          content: 'void main() {}',
          size: 14,
          isBinary: false,
        ),
        preview: true,
        wrapEnabled: true,
        tabSize: 2,
      );

      final editor = controller.editorForPath('lib/main.dart');

      expect(editor, isNotNull);
      expect(editor!.controller, isNull);
      expect(editor.isEditing, isFalse);
      expect(editor.content?.content, 'void main() {}');
    });
  });
}
