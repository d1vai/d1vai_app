import 'package:d1vai_app/models/desktop_window_launch_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopWindowLaunchConfiguration', () {
    test('defaults to main window without args', () {
      final config = DesktopWindowLaunchConfiguration.fromArgs(const []);

      expect(config.kind, DesktopWindowKind.main);
      expect(config.opensWorkspaceWindow, isFalse);
      expect(config.workspaceRequest, isNull);
    });

    test('opens workspace window from explicit flags', () {
      final config = DesktopWindowLaunchConfiguration.fromArgs(const [
        '--desktop-window=workspace',
        '--open-path=/tmp/demo',
        '--open-source=picker',
      ]);

      expect(config.kind, DesktopWindowKind.workspace);
      expect(config.opensWorkspaceWindow, isTrue);
      expect(config.workspaceRequest?.path, '/tmp/demo');
      expect(config.workspaceRequest?.source, 'picker');
    });

    test('treats a raw path argument as workspace request', () {
      final config = DesktopWindowLaunchConfiguration.fromArgs(const [
        r'C:\work\demo',
      ]);

      expect(config.kind, DesktopWindowKind.workspace);
      expect(config.workspaceRequest?.path, r'C:\work\demo');
      expect(config.workspaceRequest?.source, 'commandLine');
    });

    test('builds workspace launch arguments', () {
      final args = DesktopWindowLaunchConfiguration.workspaceArguments(
        path: '/tmp/app',
        source: 'menu',
      );

      expect(
        args,
        equals(const [
          '--desktop-window=workspace',
          '--open-path=/tmp/app',
          '--open-source=menu',
        ]),
      );
    });
  });
}
