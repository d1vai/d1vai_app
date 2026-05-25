import 'package:d1vai_app/providers/macos_menu_controller.dart';
import 'package:d1vai_app/screens/desktop_workspace_welcome_screen.dart';
import 'package:d1vai_app/services/macos_open_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recent workspace tap uses workspace window opener', (
    WidgetTester tester,
  ) async {
    String? openedPath;
    MacosOpenRequestSource? openedSource;

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWorkspaceWelcomeScreen(
          recentWorkspacesOverride: <MacosRecentWorkspaceEntry>[
            MacosRecentWorkspaceEntry(
              path: '/tmp/demo-project',
              label: 'demo-project',
              seenAt: DateTime(2026, 5, 25, 10, 0),
            ),
          ],
          openInWorkspaceWindow: (String path, MacosOpenRequestSource source) {
            openedPath = path;
            openedSource = source;
            return Future<bool>.value(true);
          },
        ),
      ),
    );

    final recentTile = find.byKey(
      const ValueKey('recent-workspace-/tmp/demo-project'),
    );
    await tester.ensureVisible(recentTile);
    await tester.tap(recentTile);
    await tester.pump();

    expect(openedPath, '/tmp/demo-project');
    expect(openedSource, MacosOpenRequestSource.recentWorkspace);
  });

  testWidgets('open folder action uses picker output', (
    WidgetTester tester,
  ) async {
    String? openedPath;
    MacosOpenRequestSource? openedSource;

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWorkspaceWelcomeScreen(
          recentWorkspacesOverride: const <MacosRecentWorkspaceEntry>[],
          pickPath: (bool pickDirectory) {
            expect(pickDirectory, isTrue);
            return Future<String?>.value('/tmp/folder-project');
          },
          openInWorkspaceWindow: (String path, MacosOpenRequestSource source) {
            openedPath = path;
            openedSource = source;
            return Future<bool>.value(true);
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Folder'));
    await tester.pump();

    expect(openedPath, '/tmp/folder-project');
    expect(openedSource, MacosOpenRequestSource.picker);
  });
}
