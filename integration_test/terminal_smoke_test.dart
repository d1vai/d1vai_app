import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:d1vai_app/controllers/terminal_session_controller.dart';
import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/screens/terminal_screen.dart';
import 'package:d1vai_app/services/shell_session_api.dart';
import 'package:d1vai_app/services/terminal_protocol.dart';
import 'package:d1vai_app/services/terminal_transport.dart';
import 'package:d1vai_app/services/workspace_service.dart';
import 'package:d1vai_app/widgets/terminal/terminal_mobile_keys.dart';
import 'package:d1vai_app/widgets/terminal/terminal_surface.dart';
import 'package:d1vai_app/widgets/terminal/terminal_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

class _Workspace implements WorkspaceReadinessService {
  @override
  Future<WorkspaceConnection> ensureWorkspaceReady({Duration? timeout}) async =>
      const WorkspaceConnection(ip: '10.0.0.1', port: 8080);

  @override
  void setScope({int? organizationId, String? projectId}) {}
}

class _Gateway implements ShellSessionGateway {
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
      sessionId: 'device-session-$creates',
      workspaceScope: 'user:7',
      projectId: projectId,
      runtimeProvider: 'fabric',
      nodeId: 'node-1',
      cwd: '/workspace',
      transport: ShellSessionTransport.direct,
      websocketUri: Uri.parse(
        'wss://node.d1v.dev/ws/terminal/device-session-$creates',
      ),
      connectionTicket: 'device-test-ticket',
      ticketExpiresAt: DateTime.utc(2026, 8, 24),
    );
  }

  @override
  Future<ShellSessionMetadata> close(String sessionId) async =>
      _metadata(sessionId);

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
    terminationReason: 'device-test',
  );
}

class _Transport implements TerminalTransportClient {
  final outputController = StreamController<Uint8List>.broadcast(sync: true);
  final controlController = StreamController<TerminalServerControl>.broadcast(
    sync: true,
  );
  final failureController =
      StreamController<TerminalTransportFailure>.broadcast(sync: true);
  final inputs = <List<int>>[];
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
  Future<void> close({bool detach = true}) async {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  void sendInput(List<int> payload) => inputs.add(List<int>.from(payload));

  @override
  void signal(String signal) {}

  void ready() {
    controlController.add(
      TerminalReady(sessionId: connection!.sessionId, cwd: '/workspace'),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs the terminal journey on a real Flutter device', (
    tester,
  ) async {
    final gateway = _Gateway();
    final transport = _Transport();
    final session = TerminalSessionController(
      workspace: _Workspace(),
      api: gateway,
      transportFactory: () => transport,
    );
    var dark = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => OrganizationProvider()),
              ChangeNotifierProvider(create: (_) => ProjectProvider()),
            ],
            child: MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeAnimationDuration: Duration.zero,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: TerminalScreen(controller: session, bootstrapScope: false),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TerminalMobileKeys), findsOneWidget);
    expect(
      find.byKey(const ValueKey('terminal-open-button')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('terminal-open-button')));
    await tester.pump();
    transport.ready();
    await tester.pump();

    expect(session.phase, TerminalSessionPhase.ready);
    final surface = tester.state<TerminalSurfaceState>(
      find.byType(TerminalSurface),
    );
    final originalTerminal = surface.terminal;
    transport.outputController.add(
      Uint8List.fromList(
        utf8.encode('\u001b[32msuccess\u001b[0m\r\n中文 output\r\n'),
      ),
    );
    await tester.pump();
    expect(originalTerminal.buffer.getText(), contains('中文 output'));

    await tester.tap(find.byKey(const ValueKey('terminal-key-ctrl')));
    await tester.pump();
    surface.terminal.textInput('c');
    await tester.tap(find.byKey(const ValueKey('terminal-key-right')));
    await tester.pump();
    expect(transport.inputs.first, <int>[3]);
    expect(transport.inputs.last, <int>[27, 91, 67]);

    setHostState(() => dark = true);
    await tester.pumpAndSettle();
    expect(gateway.creates, 1);
    expect(
      tester.state<TerminalSurfaceState>(find.byType(TerminalSurface)).terminal,
      same(originalTerminal),
    );
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).theme.background,
      d1vTerminalDarkTheme.background,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
