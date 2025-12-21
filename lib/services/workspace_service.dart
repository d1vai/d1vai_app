import 'dart:async';

import '../core/api_client.dart';

class WorkspaceStateInfo {
  final String? status;
  final String? ip;
  final int? port;

  const WorkspaceStateInfo({this.status, this.ip, this.port});

  factory WorkspaceStateInfo.fromJson(Map<String, dynamic> json) {
    final ip = json['ip'];
    final port = json['port'];
    return WorkspaceStateInfo(
      status: json['status']?.toString(),
      ip: ip is String ? ip : null,
      port: port is int ? port : port is num ? port.toInt() : null,
    );
  }

  bool get isReady => (ip != null && ip!.isNotEmpty) && (port != null && port! > 0);
}

class WorkspaceConnection {
  final String ip;
  final int port;
  final String? rawStatus;

  const WorkspaceConnection({required this.ip, required this.port, this.rawStatus});
}

enum WorkspacePhase {
  unknown,
  starting,
  ready,
  syncing,
  standby,
  archived,
  error,
}

WorkspacePhase normalizeWorkspacePhase(WorkspaceStateInfo? input) {
  if (input == null) return WorkspacePhase.unknown;
  if (input.isReady) return WorkspacePhase.ready;

  final raw = (input.status ?? '').trim();
  if (raw.isEmpty) return WorkspacePhase.unknown;
  final u = raw.toUpperCase();

  if (u == 'ACTIVE' || u == 'READY' || u == 'RUNNING') return WorkspacePhase.ready;
  if (u == 'SYNCING') return WorkspacePhase.syncing;
  if (u == 'STANDBY') return WorkspacePhase.standby;
  if (u == 'ARCHIVED') return WorkspacePhase.archived;
  if (u.contains('PENDING') || u.contains('START') || u.contains('CREAT')) {
    return WorkspacePhase.starting;
  }
  if (u.contains('FAIL') || u.contains('ERROR')) return WorkspacePhase.error;
  return WorkspacePhase.unknown;
}

class WorkspaceService {
  final ApiClient _apiClient;

  WorkspaceService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  static const _statusCacheMaxAge = Duration(milliseconds: 1500);
  static const _statusInflightDedupe = Duration(milliseconds: 800);
  static const _readyCacheMaxAge = Duration(seconds: 10);
  static const _defaultEnsureTimeout = Duration(minutes: 3);

  static Future<WorkspaceStateInfo>? _statusInFlight;
  static DateTime? _statusInFlightAt;
  static WorkspaceStateInfo? _lastStatus;
  static DateTime? _lastStatusAt;

  static Future<WorkspaceConnection>? _ensureInFlight;
  static WorkspaceConnection? _lastReady;
  static DateTime? _lastReadyAt;

  Future<WorkspaceStateInfo> getWorkspaceStatus({bool bypassCache = false}) async {
    final now = DateTime.now();
    if (!bypassCache && _lastStatus != null && _lastStatusAt != null) {
      if (now.difference(_lastStatusAt!) < _statusCacheMaxAge) return _lastStatus!;
    }

    if (_statusInFlight != null && _statusInFlightAt != null) {
      if (now.difference(_statusInFlightAt!) < _statusInflightDedupe) {
        return _statusInFlight!;
      }
    }

    _statusInFlightAt = now;
    _statusInFlight = () async {
      try {
        final data = await _apiClient.get<Map<String, dynamic>>('/api/workspace/status');
        final st = WorkspaceStateInfo.fromJson(data);
        _lastStatus = st;
        _lastStatusAt = DateTime.now();
        return st;
      } finally {
        _statusInFlight = null;
      }
    }();

    return _statusInFlight!;
  }

  Future<WorkspaceStateInfo> discoverWorkspace() async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      '/api/workspace/discover',
      {},
    );
    final st = WorkspaceStateInfo.fromJson(data);
    _lastStatus = st;
    _lastStatusAt = DateTime.now();
    return st;
  }

  bool _isTransientError(Object err) {
    final s = err.toString();
    return s.contains('HTTP Error: 503') || s.contains('HTTP Error: 504');
  }

  Future<WorkspaceConnection> ensureWorkspaceReady({Duration? timeout}) async {
    final now = DateTime.now();
    if (_lastReady != null && _lastReadyAt != null) {
      if (now.difference(_lastReadyAt!) < _readyCacheMaxAge) return _lastReady!;
    }
    if (_ensureInFlight != null) return _ensureInFlight!;

    _ensureInFlight = () async {
      final startedAt = DateTime.now();
      final timeoutDuration = timeout ?? _defaultEnsureTimeout;

      WorkspaceConnection? readyFrom(WorkspaceStateInfo st) {
        if (!st.isReady) return null;
        return WorkspaceConnection(ip: st.ip!, port: st.port!, rawStatus: st.status);
      }

      final first = await getWorkspaceStatus(bypassCache: true);
      final firstReady = readyFrom(first);
      if (firstReady != null) {
        _lastReady = firstReady;
        _lastReadyAt = DateTime.now();
        return firstReady;
      }

      var discoverAttempted = false;
      while (true) {
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed > timeoutDuration) {
          throw Exception('Workspace warmup timed out');
        }

        if (!discoverAttempted) {
          discoverAttempted = true;
          try {
            final info = await discoverWorkspace();
            final r = readyFrom(info);
            if (r != null) {
              _lastReady = r;
              _lastReadyAt = DateTime.now();
              return r;
            }
          } catch (e) {
            if (!_isTransientError(e)) rethrow;
          }
        }

        final state = await getWorkspaceStatus(bypassCache: true);
        final r = readyFrom(state);
        if (r != null) {
          _lastReady = r;
          _lastReadyAt = DateTime.now();
          return r;
        }

        final delay = elapsed < const Duration(seconds: 30)
            ? const Duration(seconds: 3)
            : const Duration(seconds: 5);
        await Future<void>.delayed(delay);
      }
    }();

    try {
      return await _ensureInFlight!;
    } finally {
      _ensureInFlight = null;
    }
  }
}
