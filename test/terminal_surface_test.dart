import 'dart:async';

import 'package:d1vai_app/controllers/terminal_session_controller.dart';
import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/screens/terminal_screen.dart';
import 'package:d1vai_app/services/shell_session_api.dart';
import 'package:d1vai_app/services/terminal_protocol.dart';
import 'package:d1vai_app/services/terminal_transport.dart';
import 'package:d1vai_app/services/workspace_service.dart';
import 'package:d1vai_app/widgets/terminal/terminal_surface.dart';
import 'package:d1vai_app/widgets/terminal/terminal_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

class _FakeWorkspace implements WorkspaceReadinessService {
  @override
  Future<WorkspaceConnection> ensureWorkspaceReady({Duration? timeout}) async =>
      const WorkspaceConnection(ip: '10.0.0.1', port: 8080);

  @override
  void setScope({int? organizationId, String? projectId}) {}
}

class _FakeGateway implements ShellSessionGateway {
  int creates = 0;

  @override
  Future<ShellConnection> create({
    String? projectId,
    int? organizationId,
    required int columns,
    required int rows,
  }) async {
    creates += 1;
    return ShellConnection(
      sessionId: 'session-$creates',
      workspaceScope: 'user:7',
      projectId: projectId,
      runtimeProvider: 'fabric',
      nodeId: 'node-1',
      cwd: '/workspace',
      transport: ShellSessionTransport.direct,
      websocketUri: Uri.parse(
        'wss://node.d1v.dev/ws/terminal/session-$creates',
      ),
      connectionTicket: 'secret',
      ticketExpiresAt: DateTime.utc(2026, 8, 24),
    );
  }

  @override
  Future<ShellSessionMetadata> close(String sessionId) =>
      SynchronousFuture(_metadata(sessionId));

  @override
  Future<ShellSessionMetadata> get(String sessionId) async =>
      _metadata(sessionId);

  @override
  Future<ShellConnection> refreshTicket(String sessionId) =>
      throw UnimplementedError();

  ShellSessionMetadata _metadata(String sessionId) => ShellSessionMetadata(
    sessionId: sessionId,
    workspaceScope: 'user:7',
    projectId: null,
    cwd: '/workspace',
    status: ShellSessionStatus.terminated,
    exitCode: null,
    terminationReason: 'test',
  );
}

class _FakeTransport implements TerminalTransportClient {
  final outputController = StreamController<Uint8List>.broadcast(sync: true);
  final controlController = StreamController<TerminalServerControl>.broadcast(
    sync: true,
  );
  final failureController =
      StreamController<TerminalTransportFailure>.broadcast(sync: true);
  ShellConnection? connection;

  @override
  Stream<TerminalServerControl> get controls => controlController.stream;
  @override
  Stream<TerminalTransportFailure> get failures => failureController.stream;
  @override
  bool get isReady => connection != null;
  @override
  Stream<Uint8List> get output => outputController.stream;

  @override
  Future<void> connect(
    ShellConnection connection, {
    required int columns,
    required int rows,
  }) async {
    this.connection = connection;
  }

  @override
  Future<void> close({bool detach = true}) {
    return SynchronousFuture<void>(null);
  }

  @override
  void resize({required int columns, required int rows}) {}
  @override
  void sendInput(List<int> payload) {}
  @override
  void signal(String signal) {}

  void ready() {
    controlController.add(
      TerminalReady(sessionId: connection!.sessionId, cwd: '/workspace'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preserves split UTF-8 output and follows app theme in place', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    final transport = _FakeTransport();
    final session = TerminalSessionController(
      workspace: _FakeWorkspace(),
      api: gateway,
      transportFactory: () => transport,
    );
    final terminal = Terminal(maxLines: 5000);
    var dark = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return MaterialApp(
            home: Theme(
              data: dark ? ThemeData.dark() : ThemeData.light(),
              child: Scaffold(
                body: TerminalSurface(
                  session: session,
                  targetKey: 'personal:workspace',
                  terminal: terminal,
                ),
              ),
            ),
          );
        },
      ),
    );
    await session.start();
    transport.ready();
    await tester.pump();

    transport.outputController.add(Uint8List.fromList(const [0xE4, 0xB8]));
    transport.outputController.add(Uint8List.fromList(const [0xAD, 0x0A]));
    await tester.pump();

    expect(terminal.buffer.getText(), contains('中'));
    expect(terminal.buffer.getText(), isNot(contains('\uFFFD')));
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).theme,
      same(d1vTerminalLightTheme),
    );

    setHostState(() => dark = true);
    await tester.pump();

    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).terminal,
      same(terminal),
    );
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).theme.background,
      d1vTerminalDarkTheme.background,
    );
    expect(gateway.creates, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });

  testWidgets('terminal screen toolbar fits a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = TerminalSessionController(
      workspace: _FakeWorkspace(),
      api: _FakeGateway(),
      transportFactory: _FakeTransport.new,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OrganizationProvider()),
          ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ],
        child: MaterialApp(
          home: TerminalScreen(controller: session, bootstrapScope: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('terminal-project-picker')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
