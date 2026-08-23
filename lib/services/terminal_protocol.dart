import 'dart:convert';
import 'dart:typed_data';

import '../models/shell_session.dart';

const int terminalProtocolVersion = 1;
const String terminalSubprotocol = 'd1v-terminal.v1';
const int terminalInputChannel = 0x00;
const int terminalOutputChannel = 0x01;
const int terminalMaxBinaryPayloadBytes = 64 * 1024;
const int terminalMaxControlFrameBytes = 8 * 1024;
const int terminalMinSize = 1;
const int terminalMaxColumns = 1000;
const int terminalMaxRows = 500;

class TerminalProtocolException implements Exception {
  final String code;

  const TerminalProtocolException(this.code);

  @override
  String toString() => 'TerminalProtocolException: $code';
}

sealed class TerminalServerControl {
  const TerminalServerControl();
}

class TerminalReady extends TerminalServerControl {
  final String sessionId;
  final String cwd;

  const TerminalReady({required this.sessionId, required this.cwd});
}

class TerminalPong extends TerminalServerControl {
  final int timestamp;

  const TerminalPong(this.timestamp);
}

class TerminalCwdChanged extends TerminalServerControl {
  final String path;

  const TerminalCwdChanged(this.path);
}

class TerminalExited extends TerminalServerControl {
  final int? code;
  final String? signal;

  const TerminalExited({required this.code, required this.signal});
}

class TerminalServerError extends TerminalServerControl {
  final String code;
  final bool retryable;

  const TerminalServerError({required this.code, required this.retryable});
}

Uint8List encodeTerminalInput(List<int> payload) {
  if (payload.length > terminalMaxBinaryPayloadBytes) {
    throw const TerminalProtocolException('binary_frame_too_large');
  }
  return Uint8List.fromList(<int>[terminalInputChannel, ...payload]);
}

Uint8List decodeTerminalOutput(Object frame) {
  final bytes = switch (frame) {
    Uint8List value => value,
    List<int> value => Uint8List.fromList(value),
    _ => throw const TerminalProtocolException('binary_frame_required'),
  };
  if (bytes.isEmpty) {
    throw const TerminalProtocolException('empty_binary_frame');
  }
  if (bytes.first != terminalOutputChannel) {
    throw const TerminalProtocolException('binary_channel_not_allowed');
  }
  final payloadLength = bytes.length - 1;
  if (payloadLength > terminalMaxBinaryPayloadBytes) {
    throw const TerminalProtocolException('binary_frame_too_large');
  }
  return Uint8List.sublistView(bytes, 1);
}

String encodeTerminalOpen({required int columns, required int rows}) {
  _validateTerminalSize(columns, rows);
  return _encodeControl(<String, Object>{
    'type': 'open',
    'version': terminalProtocolVersion,
    'cols': columns,
    'rows': rows,
    'term': 'xterm-256color',
  });
}

String encodeTerminalResize({required int columns, required int rows}) {
  _validateTerminalSize(columns, rows);
  return _encodeControl(<String, Object>{
    'type': 'resize',
    'cols': columns,
    'rows': rows,
  });
}

String encodeTerminalPing(int timestamp) =>
    _encodeControl(<String, Object>{'type': 'ping', 'timestamp': timestamp});

String encodeTerminalSignal(String signal) {
  if (!const {'SIGINT', 'SIGTERM', 'SIGHUP'}.contains(signal)) {
    throw const TerminalProtocolException('unsupported_signal');
  }
  return _encodeControl(<String, Object>{'type': 'signal', 'signal': signal});
}

String encodeTerminalDetach() =>
    _encodeControl(const <String, Object>{'type': 'detach'});

TerminalServerControl decodeTerminalControl(String frame) {
  if (utf8.encode(frame).length > terminalMaxControlFrameBytes) {
    throw const TerminalProtocolException('control_frame_too_large');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(frame);
  } on FormatException {
    throw const TerminalProtocolException('invalid_control_json');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const TerminalProtocolException('invalid_control_shape');
  }
  return switch (decoded['type']) {
    'ready' => TerminalReady(
      sessionId: _requiredControlString(decoded, 'session_id'),
      cwd: _requiredControlString(decoded, 'cwd'),
    ),
    'pong' => TerminalPong(_requiredControlInteger(decoded, 'timestamp')),
    'cwd' => TerminalCwdChanged(_requiredControlString(decoded, 'path')),
    'exit' => TerminalExited(
      code: _nullableControlInteger(decoded, 'code'),
      signal: _nullableControlString(decoded, 'signal'),
    ),
    'error' => TerminalServerError(
      code: _requiredControlString(decoded, 'code'),
      retryable: _requiredControlBoolean(decoded, 'retryable'),
    ),
    _ => throw const TerminalProtocolException('unsupported_control_type'),
  };
}

Uri buildTerminalWebSocketUri(
  ShellConnection connection, {
  bool allowInsecureLocalhost = false,
}) {
  final uri = connection.websocketUri;
  final isSecure = uri.scheme == 'wss';
  final isLocalInsecure =
      allowInsecureLocalhost &&
      uri.scheme == 'ws' &&
      const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
  if ((!isSecure && !isLocalInsecure) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw const TerminalProtocolException('websocket_url_not_allowed');
  }
  return uri.replace(
    queryParameters: <String, String>{
      ...uri.queryParameters,
      'ticket': connection.connectionTicket,
    },
  );
}

String redactTerminalTicket(Object value) {
  final raw = value.toString();
  final uri = Uri.tryParse(raw);
  if (uri != null &&
      uri.hasScheme &&
      uri.hasAuthority &&
      uri.queryParameters.containsKey('ticket')) {
    return uri
        .replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'ticket': '[redacted]',
          },
        )
        .toString();
  }
  return raw.replaceAllMapped(
    RegExp(r'([?&]ticket=)[^&\s]+', caseSensitive: false),
    (match) => '${match.group(1)}[redacted]',
  );
}

String _encodeControl(Map<String, Object> value) => jsonEncode(value);

void _validateTerminalSize(int columns, int rows) {
  if (columns < terminalMinSize ||
      columns > terminalMaxColumns ||
      rows < terminalMinSize ||
      rows > terminalMaxRows) {
    throw const TerminalProtocolException('invalid_terminal_size');
  }
}

String _requiredControlString(Map<String, dynamic> value, String key) {
  final item = value[key];
  if (item is! String || item.isEmpty) {
    throw const TerminalProtocolException('invalid_control_shape');
  }
  return item;
}

String? _nullableControlString(Map<String, dynamic> value, String key) {
  final item = value[key];
  if (item == null) return null;
  if (item is! String) {
    throw const TerminalProtocolException('invalid_control_shape');
  }
  return item;
}

int _requiredControlInteger(Map<String, dynamic> value, String key) {
  final item = value[key];
  if (item is! num || item is bool || item.toInt() != item) {
    throw const TerminalProtocolException('invalid_control_shape');
  }
  return item.toInt();
}

int? _nullableControlInteger(Map<String, dynamic> value, String key) {
  if (value[key] == null) return null;
  return _requiredControlInteger(value, key);
}

bool _requiredControlBoolean(Map<String, dynamic> value, String key) {
  final item = value[key];
  if (item is! bool) {
    throw const TerminalProtocolException('invalid_control_shape');
  }
  return item;
}
