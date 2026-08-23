import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shell_session.dart';
import '../services/shell_session_api.dart';
import '../services/terminal_protocol.dart';
import '../services/terminal_transport.dart';
import '../services/workspace_service.dart';

enum TerminalSessionPhase {
  idle,
  checking,
  waking,
  creating,
  connecting,
  ready,
  reconnecting,
  exited,
  denied,
  capacity,
  error,
}

typedef TerminalTransportFactory = TerminalTransportClient Function();

class TerminalSessionController extends ChangeNotifier {
  final WorkspaceReadinessService _workspace;
  final ShellSessionGateway _api;
  final TerminalTransportFactory _transportFactory;
  final Duration resizeDebounce;

  final StreamController<Uint8List> _outputController =
      StreamController<Uint8List>.broadcast(sync: true);

  TerminalSessionPhase _phase = TerminalSessionPhase.idle;
  String? _projectId;
  int? _organizationId;
  String? _sessionId;
  String? _cwd;
  String? _errorCode;
  int? _exitCode;
  bool _retryable = false;
  int _columns = 120;
  int _rows = 40;
  int? _lastResizeColumns;
  int? _lastResizeRows;
  int _generation = 0;
  bool _disposed = false;

  TerminalTransportClient? _transport;
  StreamSubscription<Uint8List>? _outputSubscription;
  StreamSubscription<TerminalServerControl>? _controlSubscription;
  StreamSubscription<TerminalTransportFailure>? _failureSubscription;
  Timer? _resizeTimer;

  TerminalSessionController({
    required WorkspaceReadinessService workspace,
    required ShellSessionGateway api,
    TerminalTransportFactory? transportFactory,
    this.resizeDebounce = const Duration(milliseconds: 50),
  }) : _workspace = workspace,
       _api = api,
       _transportFactory = transportFactory ?? TerminalTransport.new;

  TerminalSessionPhase get phase => _phase;
  String? get projectId => _projectId;
  int? get organizationId => _organizationId;
  String? get sessionId => _sessionId;
  String? get cwd => _cwd;
  String? get errorCode => _errorCode;
  int? get exitCode => _exitCode;
  bool get retryable => _retryable;
  int get columns => _columns;
  int get rows => _rows;
  bool get acceptsInput => _phase == TerminalSessionPhase.ready;
  Stream<Uint8List> get output => _outputController.stream;

  Future<void> start({
    String? projectId,
    int? organizationId,
    int columns = 120,
    int rows = 40,
  }) async {
    _ensureNotDisposed();
    final generation = ++_generation;
    final normalizedProjectId = _normalizeProjectId(projectId);
    _projectId = normalizedProjectId;
    _organizationId = organizationId;
    _columns = columns.clamp(terminalMinSize, terminalMaxColumns);
    _rows = rows.clamp(terminalMinSize, terminalMaxRows);
    _lastResizeColumns = null;
    _lastResizeRows = null;
    _errorCode = null;
    _exitCode = null;
    _retryable = false;
    _setPhase(TerminalSessionPhase.checking);

    await _closeCurrent(deleteSession: true);
    if (!_isCurrent(generation)) return;

    _workspace.setScope(
      organizationId: organizationId,
      projectId: normalizedProjectId,
    );
    _setPhase(TerminalSessionPhase.waking);
    try {
      await _workspace.ensureWorkspaceReady();
      if (!_isCurrent(generation)) return;

      _setPhase(TerminalSessionPhase.creating);
      final connection = await _api.create(
        projectId: normalizedProjectId,
        organizationId: organizationId,
        columns: _columns,
        rows: _rows,
      );
      if (!_isCurrent(generation)) {
        await _closeBackendSession(connection.sessionId);
        return;
      }
      _sessionId = connection.sessionId;
      _cwd = connection.cwd;

      final transport = _transportFactory();
      _transport = transport;
      _outputSubscription = transport.output.listen(_handleOutput);
      _controlSubscription = transport.controls.listen(
        (control) => _handleControl(generation, connection, control),
      );
      _failureSubscription = transport.failures.listen(
        (failure) => _handleFailure(generation, failure),
      );
      _setPhase(TerminalSessionPhase.connecting);
      await transport.connect(connection, columns: _columns, rows: _rows);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _setFailure(_failureCode(error), retryable: _isRetryable(error));
      await _closeCurrent(deleteSession: true);
    }
  }

  Future<void> retry() async {
    _ensureNotDisposed();
    final projectId = _projectId;
    final organizationId = _organizationId;
    final columns = _columns;
    final rows = _rows;
    _setPhase(TerminalSessionPhase.reconnecting);
    await start(
      projectId: projectId,
      organizationId: organizationId,
      columns: columns,
      rows: rows,
    );
  }

  void sendInput(List<int> bytes) {
    if (!acceptsInput || bytes.isEmpty) return;
    _transport?.sendInput(bytes);
  }

  void sendSignal(String signal) {
    if (!acceptsInput) return;
    _transport?.signal(signal);
  }

  void updateSize(int columns, int rows) {
    final nextColumns = columns.clamp(terminalMinSize, terminalMaxColumns);
    final nextRows = rows.clamp(terminalMinSize, terminalMaxRows);
    if (_columns == nextColumns && _rows == nextRows) return;
    _columns = nextColumns;
    _rows = nextRows;
    _resizeTimer?.cancel();
    if (!acceptsInput) return;
    _resizeTimer = Timer(resizeDebounce, () {
      if (!acceptsInput ||
          (_lastResizeColumns == _columns && _lastResizeRows == _rows)) {
        return;
      }
      _transport?.resize(columns: _columns, rows: _rows);
      _lastResizeColumns = _columns;
      _lastResizeRows = _rows;
    });
  }

  Future<void> shutdown() async {
    if (_disposed) return;
    ++_generation;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    await _closeCurrent(deleteSession: true);
    _setPhase(TerminalSessionPhase.idle);
  }

  void _handleOutput(Uint8List bytes) {
    if (!_disposed && !_outputController.isClosed) {
      _outputController.add(bytes);
    }
  }

  void _handleControl(
    int generation,
    ShellConnection connection,
    TerminalServerControl control,
  ) {
    if (!_isCurrent(generation)) return;
    if (control is TerminalReady) {
      if (control.sessionId != connection.sessionId) {
        _setFailure('terminal_session_mismatch', retryable: false);
        unawaited(_closeCurrent(deleteSession: true));
        return;
      }
      _cwd = control.cwd;
      _errorCode = null;
      _retryable = false;
      _setPhase(TerminalSessionPhase.ready);
      return;
    }
    if (control is TerminalCwdChanged) {
      _cwd = control.path;
      _notify();
      return;
    }
    if (control is TerminalExited) {
      _exitCode = control.code;
      _setPhase(TerminalSessionPhase.exited);
      unawaited(_closeCurrent(deleteSession: true));
      return;
    }
    if (control is TerminalServerError) {
      _setFailure(control.code, retryable: control.retryable);
      unawaited(_closeCurrent(deleteSession: true));
    }
  }

  void _handleFailure(int generation, TerminalTransportFailure failure) {
    if (!_isCurrent(generation)) return;
    _setFailure(failure.code, retryable: failure.retryable);
    unawaited(_closeCurrent(deleteSession: true));
  }

  void _setFailure(String code, {required bool retryable}) {
    _errorCode = code;
    _retryable = retryable;
    final normalized = code.toLowerCase();
    if (normalized.contains('denied') ||
        normalized.contains('forbidden') ||
        normalized.contains('role')) {
      _setPhase(TerminalSessionPhase.denied);
    } else if (normalized.contains('capacity') ||
        normalized.contains('session_limit')) {
      _setPhase(TerminalSessionPhase.capacity);
    } else {
      _setPhase(TerminalSessionPhase.error);
    }
  }

  Future<void> _closeCurrent({required bool deleteSession}) async {
    _resizeTimer?.cancel();
    _resizeTimer = null;
    final transport = _transport;
    final sessionId = _sessionId;
    _transport = null;
    _sessionId = null;
    _lastResizeColumns = null;
    _lastResizeRows = null;

    await _outputSubscription?.cancel();
    await _controlSubscription?.cancel();
    await _failureSubscription?.cancel();
    _outputSubscription = null;
    _controlSubscription = null;
    _failureSubscription = null;
    if (transport != null) {
      await transport.close(detach: true);
    }
    if (deleteSession && sessionId != null) {
      await _closeBackendSession(sessionId);
    }
  }

  Future<void> _closeBackendSession(String sessionId) async {
    try {
      await _api.close(sessionId);
    } catch (_) {}
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _setPhase(TerminalSessionPhase value) {
    if (_phase == value) return;
    _phase = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('terminal_controller_disposed');
  }

  String _failureCode(Object error) {
    if (error is TerminalTransportFailure) return error.code;
    return 'terminal_start_failed';
  }

  bool _isRetryable(Object error) =>
      error is TerminalTransportFailure && error.retryable;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _resizeTimer?.cancel();
    unawaited(_closeCurrent(deleteSession: true));
    unawaited(_outputController.close());
    super.dispose();
  }
}

String? _normalizeProjectId(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
