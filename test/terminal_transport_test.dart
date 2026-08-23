import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/services/terminal_protocol.dart';
import 'package:d1vai_app/services/terminal_transport.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTerminalSocket implements TerminalSocket {
  final StreamController<Object?> controller =
      StreamController<Object?>.broadcast(sync: true);
  final List<Object> sent = <Object>[];
  final Completer<void> readyCompleter = Completer<void>();
  @override
  String? protocol;
  bool closed = false;
  int? closeCode;
  String? closeReason;

  FakeTerminalSocket({this.protocol = terminalSubprotocol}) {
    readyCompleter.complete();
  }

  @override
  Future<void> get ready => readyCompleter.future;

  @override
  Stream<Object?> get stream => controller.stream;

  @override
  void add(Object value) => sent.add(value);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    closeCode = code;
    closeReason = reason;
    if (!controller.isClosed) await controller.close();
  }
}

ShellConnection connection() => ShellConnection(
  sessionId: 'sh_1',
  workspaceScope: 'user:7',
  projectId: null,
  runtimeProvider: 'fabric',
  nodeId: 'node-1',
  cwd: '/workspace',
  transport: ShellSessionTransport.direct,
  websocketUri: Uri.parse('wss://node.d1v.dev/ws/terminal/sh_1'),
  connectionTicket: 'secret',
  ticketExpiresAt: DateTime.utc(2026, 8, 24, 12),
);

Map<String, dynamic> sentJson(Object value) =>
    jsonDecode(value as String) as Map<String, dynamic>;

void main() {
  test(
    'connects with a ticket, opens, relays frames, and detaches once',
    () async {
      final socket = FakeTerminalSocket();
      Uri? connectedUri;
      final transport = TerminalTransport(
        connector: (uri) {
          connectedUri = uri;
          return socket;
        },
        heartbeatInterval: const Duration(hours: 1),
        heartbeatTimeout: const Duration(hours: 1),
      );
      final outputs = <Uint8List>[];
      final controls = <TerminalServerControl>[];
      final outputSubscription = transport.output.listen(outputs.add);
      final controlSubscription = transport.controls.listen(controls.add);

      await transport.connect(connection(), columns: 100, rows: 30);
      expect(connectedUri?.queryParameters['ticket'], 'secret');
      expect(sentJson(socket.sent.single), {
        'type': 'open',
        'version': 1,
        'cols': 100,
        'rows': 30,
        'term': 'xterm-256color',
      });
      expect(
        () => transport.sendInput(<int>[65]),
        throwsA(isA<TerminalTransportFailure>()),
      );

      socket.controller.add(
        '{"type":"ready","session_id":"sh_1","cwd":"/workspace"}',
      );
      expect(transport.isReady, isTrue);
      expect(controls.single, isA<TerminalReady>());
      expect(sentJson(socket.sent[1])['type'], 'ping');
      final pingTimestamp = sentJson(socket.sent[1])['timestamp'] as int;
      socket.controller.add('{"type":"pong","timestamp":$pingTimestamp}');

      socket.controller.add(Uint8List.fromList(<int>[1, 65, 0, 255]));
      transport.sendInput(<int>[66, 0]);
      transport.resize(columns: 80, rows: 24);
      transport.signal('SIGINT');

      expect(outputs.single, <int>[65, 0, 255]);
      expect(socket.sent[2], <int>[0, 66, 0]);
      expect(sentJson(socket.sent[3]), {
        'type': 'resize',
        'cols': 80,
        'rows': 24,
      });
      expect(sentJson(socket.sent[4]), {'type': 'signal', 'signal': 'SIGINT'});

      await transport.close();
      expect(sentJson(socket.sent[5]), {'type': 'detach'});
      expect(socket.closed, isTrue);
      await transport.close();
      expect(socket.sent.length, 6);
      await outputSubscription.cancel();
      await controlSubscription.cancel();
    },
  );

  test(
    'fails closed when the server does not negotiate the subprotocol',
    () async {
      final socket = FakeTerminalSocket(protocol: null);
      final transport = TerminalTransport(connector: (_) => socket);

      await expectLater(
        transport.connect(connection(), columns: 80, rows: 24),
        throwsA(
          isA<TerminalTransportFailure>().having(
            (failure) => failure.code,
            'code',
            'websocket_subprotocol_mismatch',
          ),
        ),
      );
      expect(socket.closed, isTrue);
      expect(socket.sent, isEmpty);
    },
  );

  test('invalid server frames emit one protocol failure and close', () async {
    final socket = FakeTerminalSocket();
    final transport = TerminalTransport(connector: (_) => socket);
    await transport.connect(connection(), columns: 80, rows: 24);
    final failure = transport.failures.first;

    socket.controller.add(Uint8List.fromList(<int>[0, 65]));

    expect((await failure).code, 'terminal_protocol_error');
    await Future<void>.delayed(Duration.zero);
    expect(socket.closed, isTrue);
    expect(transport.isReady, isFalse);
  });

  test('missing application pong closes the transport on timeout', () async {
    final socket = FakeTerminalSocket();
    final transport = TerminalTransport(
      connector: (_) => socket,
      heartbeatInterval: const Duration(milliseconds: 5),
      heartbeatTimeout: const Duration(milliseconds: 10),
    );
    await transport.connect(connection(), columns: 80, rows: 24);
    final failure = transport.failures.first;

    socket.controller.add(
      '{"type":"ready","session_id":"sh_1","cwd":"/workspace"}',
    );

    final result = await failure.timeout(const Duration(seconds: 1));
    expect(result.code, 'terminal_heartbeat_timeout');
    expect(result.retryable, isTrue);
    expect(transport.isReady, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(socket.closed, isTrue);
  });

  test('server exit stops input and preserves the exit control', () async {
    final socket = FakeTerminalSocket();
    final transport = TerminalTransport(connector: (_) => socket);
    final controls = <TerminalServerControl>[];
    final subscription = transport.controls.listen(controls.add);
    await transport.connect(connection(), columns: 80, rows: 24);
    socket.controller.add(
      '{"type":"ready","session_id":"sh_1","cwd":"/workspace"}',
    );
    socket.controller.add('{"type":"exit","code":130,"signal":"SIGINT"}');

    expect(transport.isReady, isFalse);
    expect((controls.last as TerminalExited).code, 130);
    expect(
      () => transport.sendInput(<int>[65]),
      throwsA(isA<TerminalTransportFailure>()),
    );

    await transport.close(detach: false);
    await subscription.cancel();
  });
}
