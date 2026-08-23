import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as socket_status;

import '../models/shell_session.dart';
import 'terminal_protocol.dart';

abstract interface class TerminalSocket {
  Future<void> get ready;
  String? get protocol;
  Stream<Object?> get stream;
  void add(Object value);
  Future<void> close([int? code, String? reason]);
}

class WebSocketTerminalSocket implements TerminalSocket {
  final WebSocketChannel _channel;

  WebSocketTerminalSocket._(this._channel);

  factory WebSocketTerminalSocket.connect(Uri uri) {
    return WebSocketTerminalSocket._(
      WebSocketChannel.connect(uri, protocols: const [terminalSubprotocol]),
    );
  }

  @override
  Future<void> get ready => _channel.ready;

  @override
  String? get protocol => _channel.protocol;

  @override
  Stream<Object?> get stream => _channel.stream;

  @override
  void add(Object value) => _channel.sink.add(value);

  @override
  Future<void> close([int? code, String? reason]) {
    return _channel.sink.close(code, reason);
  }
}

typedef TerminalSocketConnector = TerminalSocket Function(Uri uri);

class TerminalTransportFailure implements Exception {
  final String code;
  final bool retryable;

  const TerminalTransportFailure(this.code, {this.retryable = false});

  @override
  String toString() => 'TerminalTransportFailure: $code';
}

abstract interface class TerminalTransportClient {
  Stream<Uint8List> get output;
  Stream<TerminalServerControl> get controls;
  Stream<TerminalTransportFailure> get failures;
  bool get isReady;

  Future<void> connect(
    ShellConnection connection, {
    required int columns,
    required int rows,
  });

  void sendInput(List<int> payload);
  void resize({required int columns, required int rows});
  void signal(String signal);
  Future<void> close({bool detach = true});
}

class TerminalTransport implements TerminalTransportClient {
  final TerminalSocketConnector _connector;
  final bool allowInsecureLocalhost;
  final Duration heartbeatInterval;
  final Duration heartbeatTimeout;

  final StreamController<Uint8List> _outputController =
      StreamController<Uint8List>.broadcast(sync: true);
  final StreamController<TerminalServerControl> _controlController =
      StreamController<TerminalServerControl>.broadcast(sync: true);
  final StreamController<TerminalTransportFailure> _failureController =
      StreamController<TerminalTransportFailure>.broadcast(sync: true);

  TerminalSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  int? _expectedHeartbeatTimestamp;
  bool _serverReady = false;
  bool _closed = false;

  TerminalTransport({
    TerminalSocketConnector? connector,
    this.allowInsecureLocalhost = false,
    this.heartbeatInterval = const Duration(seconds: 20),
    this.heartbeatTimeout = const Duration(seconds: 10),
  }) : _connector = connector ?? WebSocketTerminalSocket.connect;

  @override
  Stream<Uint8List> get output => _outputController.stream;
  @override
  Stream<TerminalServerControl> get controls => _controlController.stream;
  @override
  Stream<TerminalTransportFailure> get failures => _failureController.stream;
  @override
  bool get isReady => _serverReady && !_closed;

  @override
  Future<void> connect(
    ShellConnection connection, {
    required int columns,
    required int rows,
  }) async {
    if (_socket != null || _closed) {
      throw const TerminalTransportFailure('transport_already_used');
    }
    final uri = buildTerminalWebSocketUri(
      connection,
      allowInsecureLocalhost: allowInsecureLocalhost,
    );
    final socket = _connector(uri);
    _socket = socket;
    _subscription = socket.stream.listen(
      _handleMessage,
      onError: (Object error, StackTrace stackTrace) {
        _fail(
          const TerminalTransportFailure('websocket_error', retryable: true),
        );
      },
      onDone: () {
        if (!_closed) {
          _fail(
            const TerminalTransportFailure('websocket_closed', retryable: true),
          );
        }
      },
      cancelOnError: false,
    );
    try {
      await socket.ready;
      if (_closed) return;
      if (socket.protocol != terminalSubprotocol) {
        throw const TerminalTransportFailure('websocket_subprotocol_mismatch');
      }
      socket.add(encodeTerminalOpen(columns: columns, rows: rows));
    } catch (error) {
      final failure = error is TerminalTransportFailure
          ? error
          : const TerminalTransportFailure(
              'websocket_connect_failed',
              retryable: true,
            );
      await _fail(failure);
      throw failure;
    }
  }

  @override
  void sendInput(List<int> payload) {
    _requireReady();
    _socket!.add(encodeTerminalInput(payload));
  }

  @override
  void resize({required int columns, required int rows}) {
    _requireReady();
    _socket!.add(encodeTerminalResize(columns: columns, rows: rows));
  }

  @override
  void signal(String signal) {
    _requireReady();
    _socket!.add(encodeTerminalSignal(signal));
  }

  @override
  Future<void> close({bool detach = true}) async {
    if (_closed) return;
    _closed = true;
    _serverReady = false;
    _stopHeartbeat();
    await _closeResources(detach: detach);
  }

  Future<void> _closeResources({required bool detach}) async {
    final socket = _socket;
    if (detach && socket != null) {
      try {
        socket.add(encodeTerminalDetach());
      } catch (_) {}
    }
    await _subscription?.cancel();
    _subscription = null;
    if (socket != null) {
      try {
        await socket.close(
          socket_status.normalClosure,
          detach ? 'terminal_detached' : 'terminal_closed',
        );
      } catch (_) {}
    }
    await _outputController.close();
    await _controlController.close();
    await _failureController.close();
  }

  void _handleMessage(Object? message) {
    if (_closed) return;
    try {
      if (message is String) {
        final control = decodeTerminalControl(message);
        _handleControl(control);
        _controlController.add(control);
        return;
      }
      _outputController.add(decodeTerminalOutput(message as Object));
    } on TerminalProtocolException {
      _fail(const TerminalTransportFailure('terminal_protocol_error'));
    } catch (_) {
      _fail(const TerminalTransportFailure('terminal_protocol_error'));
    }
  }

  void _handleControl(TerminalServerControl control) {
    if (control is TerminalReady) {
      _serverReady = true;
      _sendHeartbeat();
      return;
    }
    if (control is TerminalPong &&
        control.timestamp == _expectedHeartbeatTimestamp) {
      _heartbeatTimeoutTimer?.cancel();
      _heartbeatTimeoutTimer = null;
      _expectedHeartbeatTimestamp = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer(heartbeatInterval, _sendHeartbeat);
      return;
    }
    if (control is TerminalExited) {
      _serverReady = false;
      _stopHeartbeat();
      return;
    }
    if (control is TerminalServerError) {
      _serverReady = false;
      _stopHeartbeat();
    }
  }

  void _sendHeartbeat() {
    if (_closed || !_serverReady || _socket == null) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _expectedHeartbeatTimestamp = timestamp;
    _socket!.add(encodeTerminalPing(timestamp));
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = Timer(heartbeatTimeout, () {
      _expectedHeartbeatTimestamp = null;
      _fail(
        const TerminalTransportFailure(
          'terminal_heartbeat_timeout',
          retryable: true,
        ),
      );
    });
  }

  Future<void> _fail(TerminalTransportFailure failure) async {
    if (_closed) return;
    _closed = true;
    _serverReady = false;
    _stopHeartbeat();
    if (!_failureController.isClosed) _failureController.add(failure);
    await _closeResources(detach: false);
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer = null;
    _expectedHeartbeatTimestamp = null;
  }

  void _requireReady() {
    if (!isReady || _socket == null) {
      throw const TerminalTransportFailure('terminal_not_ready');
    }
  }
}
