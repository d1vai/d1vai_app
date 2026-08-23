import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:d1vai_app/controllers/terminal_session_controller.dart';
import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/services/shell_session_api.dart';
import 'package:d1vai_app/services/terminal_protocol.dart';
import 'package:d1vai_app/services/terminal_transport.dart';
import 'package:d1vai_app/services/workspace_service.dart';
import 'package:d1vai_app/widgets/terminal/terminal_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _Workspace implements WorkspaceReadinessService {
  @override
  Future<WorkspaceConnection> ensureWorkspaceReady({Duration? timeout}) async =>
      const WorkspaceConnection(ip: '10.0.0.1', port: 8080);

  @override
  void setScope({int? organizationId, String? projectId}) {}
}

class _Gateway implements ShellSessionGateway {
  int creates = 0;
  int closes = 0;

  @override
  Future<ShellConnection> create({
    String? projectId,
    int? organizationId,
    required int columns,
    required int rows,
  }) async {
    creates += 1;
    return ShellConnection(
      sessionId: 'performance-$creates',
      workspaceScope: 'user:7',
      projectId: projectId,
      runtimeProvider: 'fabric',
      nodeId: 'node-1',
      cwd: '/workspace',
      transport: ShellSessionTransport.direct,
      websocketUri: Uri.parse(
        'wss://node.d1v.dev/ws/terminal/performance-$creates',
      ),
      connectionTicket: 'performance-ticket',
      ticketExpiresAt: DateTime.utc(2026, 8, 24),
    );
  }

  @override
  Future<ShellSessionMetadata> close(String sessionId) async {
    closes += 1;
    return _metadata(sessionId);
  }

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
    terminationReason: 'performance-test',
  );
}

class _Transport implements TerminalTransportClient {
  final StreamController<Uint8List> outputController =
      StreamController<Uint8List>.broadcast(sync: true);
  final StreamController<TerminalServerControl> controlController =
      StreamController<TerminalServerControl>.broadcast(sync: true);
  final StreamController<TerminalTransportFailure> failureController =
      StreamController<TerminalTransportFailure>.broadcast(sync: true);
  ShellConnection? connection;
  bool closed = false;

  @override
  Stream<TerminalServerControl> get controls => controlController.stream;

  @override
  Stream<TerminalTransportFailure> get failures => failureController.stream;

  @override
  bool get isReady => connection != null && !closed;

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
  Future<void> close({bool detach = true}) async {
    if (closed) return;
    closed = true;
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

int _percentile(List<int> values, double percentile) {
  final sorted = List<int>.from(values)..sort();
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}

double _milliseconds(int microseconds) => microseconds / 1000;

Future<void> _waitUntilBufferContains(
  WidgetTester tester,
  TerminalSurfaceState surface,
  String marker,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    // Normal 4-16 KiB output batches dispatch in a microtask. Check that path
    // before advancing a frame so this measures write latency, not vsync wait.
    await Future<void>.delayed(Duration.zero);
    if (surface.terminal.buffer.getText().contains(marker)) return;
    await tester.pump();
  }
  throw TestFailure('Timed out draining a terminal performance burst');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('terminal client remains inside frame and memory budgets', (
    tester,
  ) async {
    final gateway = _Gateway();
    final transports = <_Transport>[];
    final session = TerminalSessionController(
      workspace: _Workspace(),
      api: gateway,
      transportFactory: () {
        final transport = _Transport();
        transports.add(transport);
        return transport;
      },
    );
    addTearDown(session.dispose);

    final mountMicros = <int>[];
    for (var index = 0; index < 23; index += 1) {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalSurface(
              key: ValueKey('performance-terminal-$index'),
              session: session,
              targetKey: 'personal:workspace',
            ),
          ),
        ),
      );
      await tester.pump();
      stopwatch.stop();
      if (index >= 3) mountMicros.add(stopwatch.elapsedMicroseconds);
    }
    await session.start();
    transports.last.ready();
    await tester.pump();
    final surface = tester.state<TerminalSurfaceState>(
      find.byType(TerminalSurface),
    );
    final rssBeforeOutput = ProcessInfo.currentRss;
    final outputWriteDispatchMicros = <int>[];
    const outputStart = '\x1b]133;C\x07';
    const outputEnd = '\x1b]133;D;0\x07';
    for (var batch = 0; batch < 50; batch += 1) {
      final batchMarker = 'D1V_PERFORMANCE_BATCH_$batch';
      final text = StringBuffer(outputStart);
      for (var line = 0; line < 100; line += 1) {
        text.writeln(
          line.isEven
              ? 'warning: performance batch $batch line $line'
              : 'completed performance batch $batch line $line',
        );
      }
      text.writeln(batchMarker);
      text.write(outputEnd);
      final stopwatch = Stopwatch()..start();
      transports.last.outputController.add(
        Uint8List.fromList(utf8.encode(text.toString())),
      );
      await _waitUntilBufferContains(tester, surface, batchMarker);
      stopwatch.stop();
      outputWriteDispatchMicros.add(stopwatch.elapsedMicroseconds);
      await tester.pump();
    }
    final rssAfterOutput = ProcessInfo.currentRss;
    expect(surface.terminal.buffer.lines.length, lessThanOrEqualTo(5000));

    surface.clear();
    await session.shutdown();
    await tester.pump();
    int? rssAfterTenCycles;
    for (var cycle = 1; cycle <= 20; cycle += 1) {
      await session.start();
      transports.last.ready();
      await tester.pump();
      await session.shutdown();
      await tester.pump();
      if (cycle == 10) rssAfterTenCycles = ProcessInfo.currentRss;
    }
    final rssAfterTwentyCycles = ProcessInfo.currentRss;

    final metrics = <String, num>{
      'warmMountP95Ms': _milliseconds(_percentile(mountMicros, 0.95)),
      'outputWriteDispatchP95Ms': _milliseconds(
        _percentile(outputWriteDispatchMicros, 0.95),
      ),
      'outputWriteDispatchMaxMs': _milliseconds(
        outputWriteDispatchMicros.reduce((a, b) => a > b ? a : b),
      ),
      'outputRssDeltaMiB': (rssAfterOutput - rssBeforeOutput) / (1024 * 1024),
      'cycle10To20RssDeltaMiB':
          (rssAfterTwentyCycles - rssAfterTenCycles!) / (1024 * 1024),
    };
    // ignore: avoid_print
    print('D1V_TERMINAL_PERFORMANCE=${jsonEncode(metrics)}');

    expect(metrics['warmMountP95Ms']!, lessThanOrEqualTo(100));
    expect(metrics['outputWriteDispatchP95Ms']!, lessThanOrEqualTo(16));
    expect(metrics['outputWriteDispatchMaxMs']!, lessThanOrEqualTo(50));
    expect(metrics['outputRssDeltaMiB']!, lessThanOrEqualTo(40));
    expect(metrics['cycle10To20RssDeltaMiB']!, lessThanOrEqualTo(4));
    expect(gateway.creates, 21);
    expect(gateway.closes, 21);
    expect(
      transports,
      everyElement(predicate<_Transport>((item) => item.closed)),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
