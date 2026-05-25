import 'package:d1vai_app/services/macos_open_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MacosOpenRequest', () {
    test('parses structured channel arguments', () {
      final request = MacosOpenRequest.fromChannelArguments({
        'path': '/tmp/demo',
        'isDirectory': true,
        'openInNewWindow': true,
        'source': 'windowDrop',
      });

      expect(request.path, '/tmp/demo');
      expect(request.isDirectory, isTrue);
      expect(request.openInNewWindow, isTrue);
      expect(request.source, MacosOpenRequestSource.windowDrop);
    });

    test('falls back to legacy string payloads', () {
      final request = MacosOpenRequest.fromChannelArguments('/tmp/file.txt');

      expect(request.path, '/tmp/file.txt');
      expect(request.isDirectory, isTrue);
      expect(request.openInNewWindow, isFalse);
      expect(request.source, MacosOpenRequestSource.unknown);
    });

    test('parses menu and recent-workspace sources', () {
      final menuRequest = MacosOpenRequest.fromChannelArguments({
        'path': '/tmp/workspace',
        'isDirectory': true,
        'openInNewWindow': true,
        'source': 'menu',
      });
      final recentRequest = MacosOpenRequest.fromChannelArguments({
        'path': '/tmp/project',
        'isDirectory': true,
        'openInNewWindow': true,
        'source': 'recent_workspace',
      });

      expect(menuRequest.source, MacosOpenRequestSource.menu);
      expect(recentRequest.source, MacosOpenRequestSource.recentWorkspace);
    });
  });

  group('MacosWorkspaceWindowInfo', () {
    test('parses structured window payloads', () {
      final window = MacosWorkspaceWindowInfo.fromChannelArguments({
        'hostIdentifier': 'main',
        'workspacePath': '/tmp/demo',
        'entryPath': '/tmp/demo/lib/main.dart',
        'title': 'demo',
        'focused': true,
        'visible': true,
      });

      expect(window.hostIdentifier, 'main');
      expect(window.workspacePath, '/tmp/demo');
      expect(window.entryPath, '/tmp/demo/lib/main.dart');
      expect(window.displayTitle, 'demo');
      expect(window.focused, isTrue);
      expect(window.visible, isTrue);
    });

    test('falls back to workspace basename when title is missing', () {
      final window = MacosWorkspaceWindowInfo.fromChannelArguments({
        'hostIdentifier': 'secondary',
        'workspacePath': '/tmp/d1v-mock/',
      });

      expect(window.displayTitle, 'd1v-mock');
      expect(window.focused, isFalse);
      expect(window.visible, isTrue);
    });
  });

  group('MacosOpenService', () {
    final service = MacosOpenService.instance;

    tearDown(() {
      while (service.consumePendingRequest() != null) {}
      while (service.consumePendingRoute() != null) {}
    });

    test('queues and consumes requests in order', () {
      service.enqueueRequest(
        const MacosOpenRequest(
          path: '/tmp/first',
          isDirectory: true,
          openInNewWindow: false,
          source: MacosOpenRequestSource.windowDrop,
        ),
      );
      service.enqueueRequest(
        const MacosOpenRequest(
          path: '/tmp/second.dart',
          isDirectory: false,
          openInNewWindow: true,
          source: MacosOpenRequestSource.dock,
        ),
      );

      expect(service.pendingRequest?.path, '/tmp/first');
      expect(service.consumePendingRequest()?.path, '/tmp/first');
      expect(service.consumePendingRequest()?.path, '/tmp/second.dart');
      expect(service.consumePendingRequest(), isNull);
    });

    test('queues and consumes routes in order', () {
      service.enqueueRoute('/projects/project-a?tab=environment');
      service.enqueueRoute('/projects/project-a/chat?autoprompt=hello');

      expect(service.pendingRoute, '/projects/project-a?tab=environment');
      expect(
        service.consumePendingRoute(),
        '/projects/project-a?tab=environment',
      );
      expect(
        service.consumePendingRoute(),
        '/projects/project-a/chat?autoprompt=hello',
      );
      expect(service.consumePendingRoute(), isNull);
    });
  });
}
