import 'dart:async';
import 'dart:typed_data';

import 'package:d1vai_app/controllers/terminal_session_controller.dart';
import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/services/shell_session_api.dart';
import 'package:d1vai_app/services/terminal_protocol.dart';
import 'package:d1vai_app/services/terminal_transport.dart';
import 'package:d1vai_app/services/workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';

ShellConnection connection(String sessionId, {String? projectId}) =>
    ShellConnection(
      sessionId: sessionId,
      workspaceScope: 'user:7',
      projectId: projectId,
      runtimeProvider: 'fabric',
      nodeId: 'node-1',
      cwd: projectId == null ? '/workspace' : '/workspace/projects/$projectId',
      transport: ShellSessionTransport.direct,
      websocketUri: Uri.parse('wss://node.d1v.dev/ws/terminal/$sessionId'),
      connectionTicket: 'ticket',
      ticketExpiresAt: DateTime.utc(2026, 8, 24, 12),
    );

ShellSessionMetadata metadata(String sessionId) => ShellSessionMetadata(
  sessionId: sessionId,
  workspaceScope: 'user:7',
  projectId: null,
  cwd: '/workspace',
  status: ShellSessionStatus.terminated,
  exitCode: null,
  terminationReason: 'test',
);

class FakeWorkspace implements WorkspaceReadinessService {
  int? organizationId;
  String? projectId;
  int ensureCalls = 0;
  final List<Completer<WorkspaceConnection>?> ensurePlan;

  FakeWorkspace({this.ensurePlan = const []});

  @override
  void setScope({int? organizationId, String? projectId}) {
    this.organizationId = organizationId;
    this.projectId = projectId;
  }

  @override
  Future<WorkspaceConnection> ensureWorkspaceReady({Duration? timeout}) {
    final index = ensureCalls++;
    if (index < ensurePlan.length && ensurePlan[index] != null) {
      return ensurePlan[index]!.future;
    }
    return Future<WorkspaceConnection>.value(
      const WorkspaceConnection(ip: '10.0.0.1', port: 8080),
    );
  }
}

class FakeGateway implements ShellSessionGateway {
  int creates = 0;
  int refreshCalls = 0;
  bool failRefresh = false;
  final List<String> closed = <String>[];
  final List<String?> createdProjects = <String?>[];

  @override
  Future<ShellConnection> create({
    String? projectId,
    int? organizationId,
    required int columns,
    required int rows,
  }) async {
    creates += 1;
    createdProjects.add(projectId);
    return connection('sh_$creates', projectId: projectId);
  }

  @override
  Future<ShellSessionMetadata> close(String sessionId) async {
    closed.add(sessionId);
    return metadata(sessionId);
  }

  @override
  Future<ShellSessionMetadata> get(String sessionId) async =>
      metadata(sessionId);

  @override
  Future<ShellConnection> refreshTicket(String sessionId) async {
    refreshCalls += 1;
    if (failRefresh) {
      throw const TerminalTransportFailure(
        'ticket_refresh_failed',
        retryable: true,
      );
    }
    return connection(sessionId);
  }
}

class FakeTransport implements TerminalTransportClient {
  final StreamController<Uint8List> outputController =
      StreamController<Uint8List>.broadcast(sync: true);
  final StreamController<TerminalServerControl> controlController =
      StreamController<TerminalServerControl>.broadcast(sync: true);
  final StreamController<TerminalTransportFailure> failureController =
      StreamController<TerminalTransportFailure>.broadcast(sync: true);
  final List<List<int>> inputs = <List<int>>[];
  final List<(int, int)> resizes = <(int, int)>[];
  final List<String> signals = <String>[];
  ShellConnection? connectionValue;
  bool connected = false;
  bool closed = false;

  @override
  Stream<Uint8List> get output => outputController.stream;
  @override
  Stream<TerminalServerControl> get controls => controlController.stream;
  @override
  Stream<TerminalTransportFailure> get failures => failureController.stream;
  @override
  bool get isReady => connected && !closed;

  @override
  Future<void> connect(
    ShellConnection connection, {
    required int columns,
    required int rows,
  }) async {
    connectionValue = connection;
    connected = true;
  }

  @override
  void sendInput(List<int> payload) => inputs.add(List<int>.from(payload));

  @override
  void resize({required int columns, required int rows}) {
    resizes.add((columns, rows));
  }

  @override
  void signal(String signal) => signals.add(signal);

  @override
  Future<void> close({bool detach = true}) async {
    closed = true;
  }

  void ready({String? sessionId, String cwd = '/workspace'}) {
    controlController.add(
      TerminalReady(
        sessionId: sessionId ?? connectionValue!.sessionId,
        cwd: cwd,
      ),
    );
  }
}

void main() {
  test(
    'moves through lifecycle and relays output, input, resize, and signal',
    () async {
      final workspace = FakeWorkspace();
      final gateway = FakeGateway();
      final transport = FakeTransport();
      final controller = TerminalSessionController(
        workspace: workspace,
        api: gateway,
        transportFactory: () => transport,
        resizeDebounce: const Duration(milliseconds: 5),
      );
      final phases = <TerminalSessionPhase>[];
      final outputs = <Uint8List>[];
      controller.addListener(() => phases.add(controller.phase));
      final outputSubscription = controller.output.listen(outputs.add);

      await controller.start(
        projectId: ' project-1 ',
        organizationId: 42,
        columns: 100,
        rows: 30,
      );

      expect(phases, [
        TerminalSessionPhase.checking,
        TerminalSessionPhase.waking,
        TerminalSessionPhase.creating,
        TerminalSessionPhase.connecting,
      ]);
      expect(workspace.projectId, 'project-1');
      expect(workspace.organizationId, 42);
      expect(controller.acceptsInput, isFalse);

      transport.ready(cwd: '/workspace/projects/project-1');
      expect(controller.phase, TerminalSessionPhase.ready);
      expect(controller.cwd, '/workspace/projects/project-1');
      transport.outputController.add(Uint8List.fromList(<int>[65, 0, 255]));
      controller.sendInput(<int>[66, 0]);
      controller.sendSignal('SIGINT');
      controller.updateSize(80, 24);
      controller.updateSize(90, 28);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(outputs.single, <int>[65, 0, 255]);
      expect(transport.inputs, [
        <int>[66, 0],
      ]);
      expect(transport.signals, ['SIGINT']);
      expect(transport.resizes, [(90, 28)]);

      await controller.shutdown();
      expect(controller.phase, TerminalSessionPhase.idle);
      expect(transport.closed, isTrue);
      expect(gateway.closed, ['sh_1']);
      await outputSubscription.cancel();
      controller.dispose();
    },
  );

  test('ignores a stale wake-up when the target changes', () async {
    final firstWake = Completer<WorkspaceConnection>();
    final workspace = FakeWorkspace(ensurePlan: [firstWake, null]);
    final gateway = FakeGateway();
    final transports = <FakeTransport>[];
    final controller = TerminalSessionController(
      workspace: workspace,
      api: gateway,
      transportFactory: () {
        final transport = FakeTransport();
        transports.add(transport);
        return transport;
      },
    );

    final firstStart = controller.start(projectId: 'project-old');
    await Future<void>.delayed(Duration.zero);
    await controller.start(projectId: 'project-new');
    firstWake.complete(const WorkspaceConnection(ip: '10.0.0.1', port: 8080));
    await firstStart;

    expect(gateway.creates, 1);
    expect(gateway.createdProjects, ['project-new']);
    expect(transports.single.connectionValue?.projectId, 'project-new');
    await controller.shutdown();
    controller.dispose();
  });

  test('maps server denial, capacity, and transport failure states', () async {
    Future<void> verifyControl(
      String code,
      TerminalSessionPhase expected,
    ) async {
      final gateway = FakeGateway();
      final transport = FakeTransport();
      final controller = TerminalSessionController(
        workspace: FakeWorkspace(),
        api: gateway,
        transportFactory: () => transport,
      );
      await controller.start();
      transport.controlController.add(
        TerminalServerError(code: code, retryable: false),
      );
      expect(controller.phase, expected);
      expect(controller.errorCode, code);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.closed, ['sh_1']);
      controller.dispose();
    }

    await verifyControl('shell_role_denied', TerminalSessionPhase.denied);
    await verifyControl(
      'workspace_session_limit',
      TerminalSessionPhase.capacity,
    );

    final gateway = FakeGateway();
    final transport = FakeTransport();
    final controller = TerminalSessionController(
      workspace: FakeWorkspace(),
      api: gateway,
      transportFactory: () => transport,
    );
    await controller.start();
    transport.failureController.add(
      const TerminalTransportFailure('websocket_closed', retryable: true),
    );
    expect(controller.phase, TerminalSessionPhase.error);
    expect(controller.retryable, isTrue);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
  });

  test(
    'rejects mismatched ready sessions and records clean server exits',
    () async {
      final gateway = FakeGateway();
      final first = FakeTransport();
      final second = FakeTransport();
      var next = 0;
      final controller = TerminalSessionController(
        workspace: FakeWorkspace(),
        api: gateway,
        transportFactory: () => next++ == 0 ? first : second,
      );

      await controller.start();
      first.ready(sessionId: 'sh_other');
      expect(controller.phase, TerminalSessionPhase.error);
      expect(controller.errorCode, 'terminal_session_mismatch');
      await Future<void>.delayed(Duration.zero);

      await controller.retry();
      second.ready();
      second.controlController.add(
        const TerminalExited(code: 130, signal: 'SIGINT'),
      );
      expect(controller.phase, TerminalSessionPhase.exited);
      expect(controller.exitCode, 130);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.closed, ['sh_1', 'sh_2']);
      controller.dispose();
    },
  );

  test('detaches in background and resumes the same backend session', () async {
    final gateway = FakeGateway();
    final transports = <FakeTransport>[];
    final controller = TerminalSessionController(
      workspace: FakeWorkspace(),
      api: gateway,
      transportFactory: () {
        final transport = FakeTransport();
        transports.add(transport);
        return transport;
      },
    );

    await controller.start();
    transports.single.ready();
    await controller.suspend();

    expect(controller.suspended, isTrue);
    expect(controller.phase, TerminalSessionPhase.reconnecting);
    expect(controller.sessionId, 'sh_1');
    expect(transports.single.closed, isTrue);
    expect(gateway.closed, isEmpty);

    await controller.resume();
    expect(gateway.refreshCalls, 1);
    expect(transports, hasLength(2));
    expect(controller.phase, TerminalSessionPhase.reconnecting);
    transports.last.ready();

    expect(controller.suspended, isFalse);
    expect(controller.phase, TerminalSessionPhase.ready);
    expect(controller.sessionId, 'sh_1');
    expect(gateway.creates, 1);

    await controller.shutdown();
    expect(gateway.closed, ['sh_1']);
    controller.dispose();
  });

  test(
    'creates a fresh session when background ticket refresh fails',
    () async {
      final gateway = FakeGateway();
      final transports = <FakeTransport>[];
      final controller = TerminalSessionController(
        workspace: FakeWorkspace(),
        api: gateway,
        transportFactory: () {
          final transport = FakeTransport();
          transports.add(transport);
          return transport;
        },
      );

      await controller.start();
      transports.single.ready();
      await controller.suspend();
      gateway.failRefresh = true;
      await controller.resume();

      expect(gateway.refreshCalls, 1);
      expect(gateway.creates, 2);
      expect(gateway.closed, ['sh_1']);
      expect(controller.sessionId, 'sh_2');
      expect(controller.phase, TerminalSessionPhase.connecting);

      await controller.shutdown();
      controller.dispose();
    },
  );
}
