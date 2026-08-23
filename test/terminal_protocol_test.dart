import 'dart:convert';
import 'dart:typed_data';

import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/services/terminal_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

ShellConnection connection({
  String url = 'wss://node.d1v.dev/ws/terminal/sh_1?region=jp',
  String ticket = 'secret ticket',
}) {
  return ShellConnection(
    sessionId: 'sh_1',
    workspaceScope: 'user:7',
    projectId: null,
    runtimeProvider: 'fabric',
    nodeId: 'node-1',
    cwd: '/workspace',
    transport: ShellSessionTransport.direct,
    websocketUri: Uri.parse(url),
    connectionTicket: ticket,
    ticketExpiresAt: DateTime.utc(2026, 8, 24, 12),
  );
}

void main() {
  group('ShellConnection', () {
    test('parses the backend connection contract', () {
      final result = ShellConnection.fromJson(<String, dynamic>{
        'session_id': 'sh_1',
        'workspace_scope': 'organization:3',
        'project_id': 'project-1',
        'runtime_provider': 'fabric',
        'node_id': 'node-1',
        'cwd': '/workspace/projects/project-1',
        'transport': 'relay',
        'websocket_url': 'wss://relay.d1v.dev/ws/terminal/sh_1',
        'connection_ticket': 'ticket',
        'ticket_expires_at': '2026-08-24T12:00:00Z',
      });

      expect(result.transport, ShellSessionTransport.relay);
      expect(result.projectId, 'project-1');
      expect(result.cwd, '/workspace/projects/project-1');
    });

    test('rejects missing fields and unknown transports', () {
      expect(
        () => ShellConnection.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
      expect(
        () => ShellConnection.fromJson(<String, dynamic>{
          'session_id': 'sh_1',
          'workspace_scope': 'user:7',
          'runtime_provider': 'fabric',
          'node_id': 'node-1',
          'cwd': '/workspace',
          'transport': 'ssh',
          'websocket_url': 'wss://node.d1v.dev/ws/terminal/sh_1',
          'connection_ticket': 'ticket',
          'ticket_expires_at': '2026-08-24T12:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('terminal binary frames', () {
    test('encodes input and decodes output without changing payload bytes', () {
      expect(encodeTerminalInput(<int>[0, 1, 255]), <int>[0, 0, 1, 255]);
      expect(
        decodeTerminalOutput(Uint8List.fromList(<int>[1, 0, 1, 255])),
        <int>[0, 1, 255],
      );
    });

    test('rejects empty, wrong-channel, non-binary, and oversized frames', () {
      expect(
        () => decodeTerminalOutput(Uint8List(0)),
        throwsA(isA<TerminalProtocolException>()),
      );
      expect(
        () => decodeTerminalOutput(Uint8List.fromList(<int>[0, 1])),
        throwsA(isA<TerminalProtocolException>()),
      );
      expect(
        () => decodeTerminalOutput('text'),
        throwsA(isA<TerminalProtocolException>()),
      );
      expect(
        () => encodeTerminalInput(
          List<int>.filled(terminalMaxBinaryPayloadBytes + 1, 1),
        ),
        throwsA(isA<TerminalProtocolException>()),
      );
    });
  });

  group('terminal control frames', () {
    test('encodes all client controls', () {
      expect(jsonDecode(encodeTerminalOpen(columns: 120, rows: 40)), {
        'type': 'open',
        'version': 1,
        'cols': 120,
        'rows': 40,
        'term': 'xterm-256color',
      });
      expect(jsonDecode(encodeTerminalResize(columns: 80, rows: 24)), {
        'type': 'resize',
        'cols': 80,
        'rows': 24,
      });
      expect(jsonDecode(encodeTerminalPing(123)), {
        'type': 'ping',
        'timestamp': 123,
      });
      expect(jsonDecode(encodeTerminalSignal('SIGINT')), {
        'type': 'signal',
        'signal': 'SIGINT',
      });
      expect(jsonDecode(encodeTerminalDetach()), {'type': 'detach'});
    });

    test('decodes all server controls', () {
      final ready =
          decodeTerminalControl(
                '{"type":"ready","session_id":"sh_1","cwd":"/workspace"}',
              )
              as TerminalReady;
      expect(ready.sessionId, 'sh_1');
      expect(ready.cwd, '/workspace');

      final pong =
          decodeTerminalControl('{"type":"pong","timestamp":123}')
              as TerminalPong;
      expect(pong.timestamp, 123);

      final cwd =
          decodeTerminalControl('{"type":"cwd","path":"/workspace/project"}')
              as TerminalCwdChanged;
      expect(cwd.path, '/workspace/project');

      final exited =
          decodeTerminalControl('{"type":"exit","code":0,"signal":null}')
              as TerminalExited;
      expect(exited.code, 0);
      expect(exited.signal, isNull);

      final error =
          decodeTerminalControl(
                '{"type":"error","code":"workspace_capacity","retryable":true}',
              )
              as TerminalServerError;
      expect(error.code, 'workspace_capacity');
      expect(error.retryable, isTrue);
    });

    test('rejects invalid controls, sizes, and signals', () {
      for (final input in <String>[
        'nope',
        '[]',
        '{"type":"ready","session_id":7,"cwd":"/workspace"}',
        '{"type":"pong","timestamp":true}',
        '{"type":"exit","code":"0","signal":null}',
        '{"type":"unknown"}',
      ]) {
        expect(
          () => decodeTerminalControl(input),
          throwsA(isA<TerminalProtocolException>()),
        );
      }
      expect(
        () => encodeTerminalOpen(columns: 0, rows: 24),
        throwsA(isA<TerminalProtocolException>()),
      );
      expect(
        () => encodeTerminalResize(columns: 80, rows: 501),
        throwsA(isA<TerminalProtocolException>()),
      );
      expect(
        () => encodeTerminalSignal('SIGKILL'),
        throwsA(isA<TerminalProtocolException>()),
      );
      expect(
        () => decodeTerminalControl('x' * (terminalMaxControlFrameBytes + 1)),
        throwsA(isA<TerminalProtocolException>()),
      );
    });
  });

  group('terminal WebSocket URL', () {
    test('adds an encoded one-time ticket and preserves safe query values', () {
      final uri = buildTerminalWebSocketUri(connection());
      expect(uri.scheme, 'wss');
      expect(uri.queryParameters['region'], 'jp');
      expect(uri.queryParameters['ticket'], 'secret ticket');
    });

    test('allows insecure WebSocket only for explicit local development', () {
      final local = connection(url: 'ws://127.0.0.1:8787/ws/terminal/sh_1');
      expect(
        () => buildTerminalWebSocketUri(local),
        throwsA(isA<TerminalProtocolException>()),
      );
      expect(
        buildTerminalWebSocketUri(local, allowInsecureLocalhost: true).scheme,
        'ws',
      );
      expect(
        () => buildTerminalWebSocketUri(
          connection(url: 'ws://node.d1v.dev/ws/terminal/sh_1'),
          allowInsecureLocalhost: true,
        ),
        throwsA(isA<TerminalProtocolException>()),
      );
    });

    test('rejects user info and fragments', () {
      for (final value in <String>[
        'wss://user@node.d1v.dev/ws/terminal/sh_1',
        'wss://node.d1v.dev/ws/terminal/sh_1#ticket',
        'https://node.d1v.dev/ws/terminal/sh_1',
      ]) {
        expect(
          () => buildTerminalWebSocketUri(connection(url: value)),
          throwsA(isA<TerminalProtocolException>()),
        );
      }
    });

    test('redacts tickets from valid and malformed diagnostic text', () {
      expect(
        redactTerminalTicket('wss://node.d1v.dev/ws?ticket=secret&region=jp'),
        contains('ticket=%5Bredacted%5D'),
      );
      expect(
        redactTerminalTicket('failed ?ticket=secret&next=1'),
        'failed ?ticket=[redacted]&next=1',
      );
      expect(redactTerminalTicket('safe error'), 'safe error');
    });
  });
}
