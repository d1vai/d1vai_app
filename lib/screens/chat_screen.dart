import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:d1vai_app/models/message.dart';
import 'package:d1vai_app/models/model_config.dart';
import 'package:d1vai_app/models/outbox.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:d1vai_app/services/chat_service.dart';
import 'package:d1vai_app/services/d1vai_service.dart';
import 'package:d1vai_app/services/model_config_service.dart';
import 'package:d1vai_app/services/workspace_service.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/utils/error_utils.dart';
import 'package:d1vai_app/utils/message_parser.dart';
import 'package:d1vai_app/widgets/chat/message_list.dart';
import 'package:d1vai_app/widgets/chat/message_input.dart';
import 'package:d1vai_app/widgets/chat/outbox/outbox_widgets.dart';
import 'package:d1vai_app/widgets/chat/chat_screen_states.dart';
import 'package:d1vai_app/widgets/chat/floating_preview_dock.dart';
import 'package:d1vai_app/widgets/chat/status_pill.dart';
import 'package:d1vai_app/widgets/compact_selector.dart';
import 'package:d1vai_app/widgets/alert.dart';
import 'package:d1vai_app/widgets/snackbar_helper.dart';

class _OutboxAborted implements Exception {
  const _OutboxAborted();

  @override
  String toString() => 'outbox_aborted';
}

enum _ChatAppBarAction {
  openOverview,
  openEnvironment,
  openDatabase,
  openPayment,
  openDeployHistory,
  openAnalytics,
  workspaceStatus,
  refresh,
  clearChat,
}

/// Main chat screen for AI conversations
class ChatScreen extends StatefulWidget {
  final String projectId;
  final String? autoprompt;

  const ChatScreen({super.key, required this.projectId, this.autoprompt});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final D1vaiService _d1vaiService = D1vaiService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final ModelConfigService _modelConfigService = ModelConfigService();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Map<String, MessageStatus> _messageStatuses = {};
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  // Session UI phase (align with ProjectChatTab mobile status label)
  bool _sessionDone = false;
  bool _sessionError = false;

  bool _isLoading = false;
  bool _isLoadingHistory = false;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = true;
  DateTime? _oldestMessageAt;
  String? _currentSessionId;

  // Outbox queue (mobile-friendly message queue)
  final List<OutboxItem> _outboxItems = <OutboxItem>[];
  OutboxMode _outboxMode = OutboxMode.idle;
  bool _outboxDrainInFlight = false;
  int _outboxAbortToken = 0;
  final StreamController<void> _outboxSignals =
      StreamController<void>.broadcast(sync: true);
  bool _outboxCollapsed = false;

  // WebSocket runtime (mirrors responsibilities from ProjectChatTab / web ChatSection)
  String? _activeWsSessionId;
  String? _activeWsUrlOverride;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _manualWsClose = false;
  bool _autoConnectDisabled = false;
  final Set<String> _seenWsKeys = <String>{};
  _WsConnectionState _wsConnState = _WsConnectionState.idle;

  final StringBuffer _assistantDeltaBuffer = StringBuffer();
  int _assistantDeltaChars = 0;
  Timer? _assistantDeltaFlushTimer;

  bool _autopromptHandled = false;

  WorkspaceStateInfo? _workspaceState;
  WorkspacePhase _workspacePhase = WorkspacePhase.unknown;
  String? _workspaceError;
  Timer? _workspacePollTimer;
  bool _workspacePollInFlight = false;
  bool _workspaceWarmupInFlight = false;
  int _workspacePollErrorStreak = 0;

  List<ModelInfo> _availableModels = <ModelInfo>[];
  String _selectedModelId = '';
  bool _isLoadingModels = false;
  bool _isSwitchingModel = false;
  bool _hasLoadedModelConfig = false;
  Timer? _modelConfigRetryTimer;

  String? _miniPreviewUrl;
  int _miniPreviewReloadVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapWorkspace());
    unawaited(_initialize());
    unawaited(_syncMiniPreviewUrl());
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      setState(() {
        _miniPreviewUrl = null;
        _miniPreviewReloadVersion = 0;
      });
      unawaited(_syncMiniPreviewUrl());
    }
  }

  @override
  void dispose() {
    _assistantDeltaFlushTimer?.cancel();
    _reconnectTimer?.cancel();
    _workspacePollTimer?.cancel();
    _modelConfigRetryTimer?.cancel();
    _webSocketSubscription?.cancel();
    _outboxSignals.close();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _manualWsClose = true;
    _webSocket?.close(1000, 'dispose');
    _scrollController.dispose();
    super.dispose();
  }

  void _signalOutbox() {
    try {
      _outboxSignals.add(null);
    } catch (_) {}
  }

  void _abortOutboxDrain() {
    _outboxAbortToken += 1;
    _outboxDrainInFlight = false;
    _signalOutbox();
  }

  void _setOutboxMode(OutboxMode next) {
    if (_outboxMode == next) return;
    if (!mounted) {
      _outboxMode = next;
      return;
    }
    setState(() {
      _outboxMode = next;
    });
  }

  bool _hasActiveStreaming() {
    final activeSid = (_activeWsSessionId ?? '').trim();
    return _wsConnState == _WsConnectionState.connected &&
        !_autoConnectDisabled &&
        !_sessionDone &&
        !_sessionError &&
        activeSid.isNotEmpty;
  }

  bool _isTaskIdleForQueue() {
    final working =
        _isLoading ||
        _wsConnState == _WsConnectionState.connecting ||
        _hasActiveStreaming();
    return !working;
  }

  Future<void> _sleepAbortable(Duration d, int token) async {
    final deadline = DateTime.now().add(d);
    while (DateTime.now().isBefore(deadline)) {
      if (_outboxAbortToken != token) throw const _OutboxAborted();
      final remaining = deadline.difference(DateTime.now());
      final step = remaining.inMilliseconds.clamp(0, 120);
      try {
        await Future.any<void>([
          Future<void>.delayed(Duration(milliseconds: step)),
          _outboxSignals.stream.first,
        ]);
      } catch (_) {
        throw const _OutboxAborted();
      }
    }
  }

  Future<void> _waitForWorkspaceReady(int token) async {
    if (_workspacePhase == WorkspacePhase.ready) return;
    _setOutboxMode(OutboxMode.waitingWorkspace);
    while (_workspacePhase != WorkspacePhase.ready) {
      if (_outboxAbortToken != token) throw const _OutboxAborted();
      try {
        await _ensureWorkspaceReadyForSend();
      } catch (_) {}
      if (_workspacePhase == WorkspacePhase.ready) return;
      try {
        await Future.any<void>([
          Future<void>.delayed(const Duration(milliseconds: 700)),
          _outboxSignals.stream.first,
        ]);
      } catch (_) {
        throw const _OutboxAborted();
      }
    }
  }

  Future<bool> _waitForTaskIdle(int token) async {
    if (_isTaskIdleForQueue()) return false;
    _setOutboxMode(OutboxMode.waitingTask);
    while (!_isTaskIdleForQueue()) {
      if (_outboxAbortToken != token) throw const _OutboxAborted();
      try {
        await Future.any<void>([
          Future<void>.delayed(const Duration(milliseconds: 250)),
          _outboxSignals.stream.first,
        ]);
      } catch (_) {
        throw const _OutboxAborted();
      }
    }
    return true;
  }

  void _outboxEnqueue(String prompt) {
    final p = prompt.trim();
    if (p.isEmpty) return;
    final needsCooldown = !_isTaskIdleForQueue();
    setState(() {
      _outboxItems.add(
        OutboxItem(
          id: 'q-${DateTime.now().millisecondsSinceEpoch}-${_outboxItems.length}',
          prompt: p,
          enqueuedAt: DateTime.now(),
          needsCooldownAfterIdle: needsCooldown,
          status: OutboxItemStatus.queued,
        ),
      );
    });
    _signalOutbox();
    unawaited(_drainOutbox());
  }

  void _outboxDelete(OutboxItem item) {
    _abortOutboxDrain();
    setState(() {
      _outboxItems.removeWhere((x) => x.id == item.id);
    });
    _signalOutbox();
    unawaited(_drainOutbox());
  }

  void _outboxUpdate(OutboxItem item, String nextPrompt) {
    final next = nextPrompt.trim();
    _abortOutboxDrain();
    setState(() {
      final idx = _outboxItems.indexWhere((x) => x.id == item.id);
      if (idx == -1) return;
      if (next.isEmpty) {
        _outboxItems.removeAt(idx);
      } else {
        _outboxItems[idx] = _outboxItems[idx].copyWith(
          prompt: next,
          status: OutboxItemStatus.queued,
          error: null,
        );
      }
    });
    _signalOutbox();
    unawaited(_drainOutbox());
  }

  void _outboxClear() {
    _abortOutboxDrain();
    setState(() {
      _outboxItems.clear();
      _outboxMode = OutboxMode.idle;
    });
    unawaited(_maybePowerSaveCloseWebSocket());
  }

  bool _outboxHasFailed() =>
      _outboxItems.any((x) => x.status == OutboxItemStatus.failed);

  Future<void> _maybePowerSaveCloseWebSocket() async {
    if (_outboxItems.isNotEmpty) return;
    if (_hasActiveStreaming()) return;
    if (_wsConnState != _WsConnectionState.connected) return;
    await _closeWebSocket(manual: true);
  }

  Future<void> _drainOutbox() async {
    if (_outboxDrainInFlight) return;
    if (_outboxItems.isEmpty) {
      _setOutboxMode(OutboxMode.idle);
      unawaited(_maybePowerSaveCloseWebSocket());
      return;
    }
    if (_outboxHasFailed()) {
      _setOutboxMode(OutboxMode.pausedError);
      return;
    }

    _outboxDrainInFlight = true;
    final token = _outboxAbortToken;
    try {
      final nextIndex = _outboxItems.indexWhere(
        (x) => x.status == OutboxItemStatus.queued,
      );
      if (nextIndex == -1) return;
      final next = _outboxItems[nextIndex];

      try {
        await _waitForWorkspaceReady(token);
        final waited = await _waitForTaskIdle(token);
        if (waited || next.needsCooldownAfterIdle) {
          await _sleepAbortable(const Duration(milliseconds: 1500), token);
        }
      } on _OutboxAborted {
        return;
      }
      if (_outboxAbortToken != token) return;
      if (!mounted) return;

      final idx = _outboxItems.indexWhere((x) => x.id == next.id);
      if (idx == -1) return;
      if (_outboxItems[idx].status != OutboxItemStatus.queued) return;

      _setOutboxMode(OutboxMode.dispatching);
      setState(() {
        _outboxItems[idx] = _outboxItems[idx].copyWith(
          status: OutboxItemStatus.running,
          error: null,
        );
      });

      try {
        await _dispatchPrompt(next.prompt);
        if (!mounted) return;
        setState(() {
          _outboxItems.removeWhere((x) => x.id == next.id);
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          final i = _outboxItems.indexWhere((x) => x.id == next.id);
          if (i != -1) {
            _outboxItems[i] = _outboxItems[i].copyWith(
              status: OutboxItemStatus.failed,
              error: e.toString(),
            );
          }
          _outboxMode = OutboxMode.pausedError;
        });
      }
    } finally {
      _outboxDrainInFlight = false;
      if (_outboxAbortToken == token) {
        if (_outboxHasFailed()) {
          _setOutboxMode(OutboxMode.pausedError);
        } else if (_outboxItems.isEmpty) {
          _setOutboxMode(OutboxMode.idle);
        } else {
          _setOutboxMode(OutboxMode.idle);
          unawaited(_drainOutbox());
        }
      }
      _signalOutbox();
    }
  }

  Future<void> _initialize() async {
    await _refreshHistory(attemptReconnect: true);
    await _maybeRunAutoprompt();
  }

  Future<void> _syncMiniPreviewUrl({bool bumpVersion = false}) async {
    try {
      final project = await _d1vaiService.getUserProjectById(widget.projectId);
      final next =
          (project.latestPreviewUrl ?? project.latestProdDeploymentUrl ?? '')
              .trim();
      if (!mounted) return;
      if (next.isEmpty) {
        if ((_miniPreviewUrl ?? '').isNotEmpty || bumpVersion) {
          setState(() {
            _miniPreviewUrl = null;
            if (bumpVersion) _miniPreviewReloadVersion += 1;
          });
        }
        return;
      }

      final changed = next != (_miniPreviewUrl ?? '').trim();
      if (!changed && !bumpVersion) return;
      setState(() {
        _miniPreviewUrl = next;
        if (changed || bumpVersion) {
          _miniPreviewReloadVersion += 1;
        }
      });
    } catch (_) {
      if (!mounted || !bumpVersion) return;
      setState(() {
        _miniPreviewReloadVersion += 1;
      });
    }
  }

  void _refreshMiniPreview({bool fetchLatestUrl = false}) {
    if (fetchLatestUrl) {
      unawaited(_syncMiniPreviewUrl(bumpVersion: true));
      return;
    }
    if (!mounted) return;
    setState(() {
      _miniPreviewReloadVersion += 1;
    });
  }

  void _scheduleWorkspacePoll(WorkspacePhase phase) {
    _workspacePollTimer?.cancel();
    if (!mounted) return;

    Duration delay;
    switch (phase) {
      case WorkspacePhase.ready:
        delay = const Duration(minutes: 10);
        break;
      case WorkspacePhase.starting:
      case WorkspacePhase.syncing:
      case WorkspacePhase.unknown:
        delay = const Duration(seconds: 5);
        break;
      case WorkspacePhase.standby:
      case WorkspacePhase.archived:
        delay = const Duration(minutes: 1);
        break;
      case WorkspacePhase.error:
        delay = Duration(
          milliseconds: (5000 * (1 << _workspacePollErrorStreak.clamp(0, 6)))
              .clamp(5000, 5 * 60 * 1000),
        );
        break;
    }

    _workspacePollTimer = Timer(delay, () {
      if (!mounted) return;
      unawaited(_refreshWorkspaceStatus(bypassCache: true));
    });
  }

  Future<void> _refreshWorkspaceStatus({required bool bypassCache}) async {
    if (_workspacePollInFlight) return;
    _workspacePollInFlight = true;
    try {
      final st = await _workspaceService.getWorkspaceStatus(
        bypassCache: bypassCache,
      );
      if (!mounted) return;
      final phase = normalizeWorkspacePhase(st);
      setState(() {
        _workspaceState = st;
        _workspacePhase = phase;
        _workspaceError = null;
      });
      if (phase == WorkspacePhase.ready) {
        unawaited(_loadModelConfigIfPossible());
      }
      _signalOutbox();
      unawaited(_drainOutbox());
      _workspacePollErrorStreak = 0;
      _scheduleWorkspacePoll(phase);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspacePhase = WorkspacePhase.error;
        _workspaceError = humanizeError(e);
      });
      _signalOutbox();
      _workspacePollErrorStreak += 1;
      _scheduleWorkspacePoll(WorkspacePhase.error);
    } finally {
      _workspacePollInFlight = false;
    }
  }

  Future<void> _bootstrapWorkspace() async {
    await _refreshWorkspaceStatus(bypassCache: true);
    // Best-effort warmup in background to improve first-send UX.
    if (_workspacePhase != WorkspacePhase.ready) {
      unawaited(_maybeWarmupWorkspace());
    }
  }

  Future<void> _maybeWarmupWorkspace() async {
    if (_workspaceWarmupInFlight) return;
    if (_workspacePhase == WorkspacePhase.ready) return;
    _workspaceWarmupInFlight = true;
    try {
      final conn = await _workspaceService.ensureWorkspaceReady();
      if (!mounted) return;
      setState(() {
        _workspaceState = WorkspaceStateInfo(
          status: conn.rawStatus ?? _workspaceState?.status,
          ip: conn.ip,
          port: conn.port,
        );
        _workspacePhase = WorkspacePhase.ready;
        _workspaceError = null;
      });
      unawaited(_loadModelConfigIfPossible());
      _signalOutbox();
      unawaited(_drainOutbox());
      _workspacePollErrorStreak = 0;
      _scheduleWorkspacePoll(WorkspacePhase.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspacePhase = WorkspacePhase.error;
        _workspaceError = humanizeError(e);
      });
      _signalOutbox();
      _workspacePollErrorStreak += 1;
      _scheduleWorkspacePoll(WorkspacePhase.error);
    } finally {
      _workspaceWarmupInFlight = false;
    }
  }

  Future<void> _ensureWorkspaceReadyForSend() async {
    if (_workspacePhase == WorkspacePhase.ready) return;
    // Quick status check before a potentially long ensure call.
    await _refreshWorkspaceStatus(bypassCache: false);
    if (_workspacePhase == WorkspacePhase.ready) return;
    await _maybeWarmupWorkspace();
    if (_workspacePhase != WorkspacePhase.ready) {
      throw Exception(_workspaceError ?? 'Workspace is not ready');
    }
    unawaited(_loadModelConfigIfPossible());
  }

  void _scheduleModelConfigRetry() {
    _modelConfigRetryTimer?.cancel();
    _modelConfigRetryTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_workspacePhase != WorkspacePhase.ready) return;
      if (_hasLoadedModelConfig || _isLoadingModels) return;
      unawaited(_loadModelConfigIfPossible());
    });
  }

  Future<void> _loadModelConfigIfPossible() async {
    if (!mounted) return;
    if (_workspacePhase != WorkspacePhase.ready) return;
    if (_hasLoadedModelConfig || _isLoadingModels) return;

    setState(() {
      _isLoadingModels = true;
    });

    try {
      final config = await _modelConfigService.getModelConfig(retries: 0);
      if (!mounted) return;
      final models = config.availableModels;
      final firstModel = models.isNotEmpty ? models.first.id.trim() : '';
      final apiModel = config.model.trim();
      final cached = (await _modelConfigService.getCachedModel())?.trim() ?? '';
      final preferred = cached.isNotEmpty ? cached : apiModel;
      final exists =
          preferred.isNotEmpty && models.any((m) => m.id.trim() == preferred);
      final selected = exists ? preferred : firstModel;

      setState(() {
        _availableModels = models;
        _selectedModelId = selected;
        _hasLoadedModelConfig = true;
        _isLoadingModels = false;
      });

      if (selected.isNotEmpty) {
        await _modelConfigService.setCachedModel(selected);
        if (apiModel != selected) {
          try {
            await _modelConfigService.setModelConfig(selected, retries: 0);
          } catch (_) {}
        }
      }
      _modelConfigRetryTimer?.cancel();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableModels = <ModelInfo>[];
        _selectedModelId = '';
        _hasLoadedModelConfig = false;
        _isLoadingModels = false;
      });
      _scheduleModelConfigRetry();
    }
  }

  Future<void> _handleModelChanged(String modelId) async {
    final next = modelId.trim();
    if (next.isEmpty || next == _selectedModelId || _isSwitchingModel) return;
    if (!mounted) return;

    setState(() {
      _isSwitchingModel = true;
    });

    try {
      await _modelConfigService.setModelConfig(next, retries: 0);
      await _modelConfigService.setCachedModel(next);
      if (!mounted) return;
      final switchedLabel = _modelLabelFor(next);
      final loc = AppLocalizations.of(context);
      final template =
          loc?.translate('model_switch_success') ?? 'Switched to {model}';
      setState(() {
        _selectedModelId = next;
      });
      SnackBarHelper.showSuccess(
        context,
        title: loc?.translate('model_switch_title') ?? 'Model',
        message: template.replaceAll('{model}', switchedLabel),
        position: SnackBarPosition.top,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to switch model: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingModel = false;
        });
      }
    }
  }

  String _selectedModelLabel() {
    final id = _selectedModelId.trim();
    if (id.isEmpty) return 'Model';
    return _modelLabelFor(id);
  }

  String _modelLabelFor(String modelId) {
    final id = modelId.trim();
    if (id.isEmpty) return 'Model';
    for (final model in _availableModels) {
      if (model.id.trim() == id) {
        final name = model.name.trim();
        return name.isEmpty ? id : name;
      }
    }
    return id;
  }

  Future<void> _maybeRunAutoprompt() async {
    final autoprompt = widget.autoprompt?.trim();
    if (_autopromptHandled) return;
    if (autoprompt == null || autoprompt.isEmpty) return;
    _autopromptHandled = true;
    // Align with web: autoprompt should always start a new session.
    await _sendMessage(autoprompt, forceNewSession: true);
  }

  Future<void> _refreshHistory({required bool attemptReconnect}) async {
    if (_isLoadingHistory) return;
    final disableAutoConnect = _autoConnectDisabled;
    String? lastType;
    DateTime? lastAt;
    var historyOk = false;
    var nextAutoConnectDisabled = _autoConnectDisabled;
    const staleWindow = Duration(minutes: 15);
    setState(() {
      _isLoadingHistory = true;
      _isLoadingMoreHistory = false;
      _hasMoreHistory = true;
      _oldestMessageAt = null;
    });

    // Close WS to avoid mixing old runs with refreshed history.
    await _closeWebSocket(manual: true);

    try {
      const limit = 30;
      final history = await _chatService.getChatHistory(
        projectId: widget.projectId,
        limit: limit,
        messageType: 'all',
        includePayload: true,
      );
      if (!mounted) return;
      historyOk = true;
      history.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final messages = <ChatMessage>[];
      for (final entry in history) {
        final m = MessageParser.historyEntryToMessage(entry);
        if (m != null) messages.add(m);
      }
      final merged = MessageParser.mergeToolResultsIntoPrevToolCalls(messages);

      Map<String, dynamic>? payloadMap(dynamic p) {
        if (p is Map<String, dynamic>) return p;
        if (p is String) {
          final s = p.trim();
          if (!(s.startsWith('{') || s.startsWith('['))) return null;
          try {
            final v = jsonDecode(s);
            if (v is Map) {
              return v.map((k, val) => MapEntry(k.toString(), val));
            }
          } catch (_) {}
        }
        return null;
      }

      ChatHistoryEntry? latest;
      for (final e in history) {
        if (latest == null || e.createdAt.isAfter(latest.createdAt)) {
          latest = e;
        }
      }
      String? normalizeType(ChatHistoryEntry? e) {
        if (e == null) return null;
        final pm = payloadMap(e.payload);
        final raw = (pm?['type'] ?? e.messageType)?.toString();
        final t = raw?.trim().toLowerCase();
        return t != null && t.isNotEmpty ? t : null;
      }

      final terminalTypes = <String>{
        'complete',
        'result',
        'error',
        'cancelled',
      };
      final latestType = normalizeType(latest);
      nextAutoConnectDisabled =
          latestType != null && terminalTypes.contains(latestType)
          ? true
          : _autoConnectDisabled;
      final nextSessionDone =
          latestType == 'complete' ||
          latestType == 'result' ||
          latestType == 'cancelled';
      final nextSessionError = latestType == 'error';

      ChatHistoryEntry? newestWithSession;
      for (final e in history) {
        final pm = payloadMap(e.payload);
        if (pm == null) continue;
        final sid = pm['session_id'];
        if (sid is! String || sid.isEmpty) continue;
        if (newestWithSession == null ||
            e.createdAt.isAfter(newestWithSession.createdAt)) {
          newestWithSession = e;
        }
      }
      final nextSessionId =
          payloadMap(newestWithSession?.payload)?['session_id'] as String?;

      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
        _messageStatuses.clear();
        _isLoadingHistory = false;
        _hasMoreHistory = history.length >= limit;
        _oldestMessageAt = history.isNotEmpty ? history.first.createdAt : null;
        _autoConnectDisabled = nextAutoConnectDisabled;
        _sessionDone = nextSessionDone;
        _sessionError = nextSessionError;
        _currentSessionId = (nextSessionId != null && nextSessionId.isNotEmpty)
            ? nextSessionId
            : _currentSessionId;
      });

      ChatHistoryEntry? newestNonIgnorable;
      for (final e in history) {
        final t = normalizeType(e);
        if (t == null) continue;
        if (t == 'history_complete' ||
            t == 'deployment_start' ||
            t == 'deployment_complete') {
          continue;
        }
        if (newestNonIgnorable == null ||
            e.createdAt.isAfter(newestNonIgnorable.createdAt)) {
          newestNonIgnorable = e;
        }
      }
      lastType = normalizeType(newestNonIgnorable);
      lastAt = newestNonIgnorable?.createdAt;

      if (attemptReconnect &&
          !nextAutoConnectDisabled &&
          nextSessionId != null &&
          nextSessionId.isNotEmpty &&
          newestWithSession != null &&
          DateTime.now().difference(newestWithSession.createdAt).inMinutes <=
              10) {
        await _ensureWebSocketOpen(nextSessionId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
      });
      final msg = humanizeError(e);
      showDialog(
        context: context,
        builder: (context) => Alert(
          variant: AlertVariant.destructive,
          child: AlertDescription(text: 'Failed to load chat history: $msg'),
        ),
      );
    } finally {
      final canAttemptReconnect =
          attemptReconnect &&
          mounted &&
          !(disableAutoConnect || nextAutoConnectDisabled);
      final last = lastAt;
      final isStale =
          last != null && DateTime.now().difference(last) > staleWindow;
      if (canAttemptReconnect && !isStale) {
        try {
          final active = await _chatService.getActiveProjectSession(
            projectId: widget.projectId,
          );

          if (mounted) {
            final sid = active?['session_id']?.toString().trim();
            final status = active?['status']?.toString().trim();
            final wsUrl = active?['websocket_url']?.toString();

            final shouldReconnect =
                (sid != null && sid.isNotEmpty) &&
                status == 'running' &&
                !(historyOk &&
                    lastType != null &&
                    <String>{
                      'complete',
                      'result',
                      'error',
                      'cancelled',
                    }.contains(lastType));

            if (shouldReconnect) {
              _currentSessionId = sid;
              await _ensureWebSocketOpen(sid, websocketUrlOverride: wsUrl);
            }
          }
        } catch (_) {
          // best-effort
        }
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingHistory || _isLoadingMoreHistory) return;
    if (!_hasMoreHistory) return;

    final before = _oldestMessageAt;
    if (before == null) return;

    setState(() {
      _isLoadingMoreHistory = true;
    });

    try {
      const limit = 30;
      final history = await _chatService.getChatHistory(
        projectId: widget.projectId,
        limit: limit,
        messageType: 'all',
        includePayload: true,
        beforeTs: before.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      history.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final older = <ChatMessage>[];
      for (final entry in history) {
        final m = MessageParser.historyEntryToMessage(entry);
        if (m != null) older.add(m);
      }

      final existingIds = _messages.map((m) => m.id).toSet();
      final deduped = older.where((m) => !existingIds.contains(m.id)).toList();
      final merged = MessageParser.mergeToolResultsIntoPrevToolCalls([
        ...deduped,
        ..._messages,
      ]);

      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
        _isLoadingMoreHistory = false;
        _hasMoreHistory = history.length >= limit;
        _oldestMessageAt = history.isNotEmpty
            ? history.first.createdAt
            : _oldestMessageAt;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreHistory = false;
        _hasMoreHistory = false;
      });
    }
  }

  Future<void> _closeWebSocket({required bool manual}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _manualWsClose = manual;

    try {
      await _webSocketSubscription?.cancel();
    } catch (_) {}
    _webSocketSubscription = null;

    try {
      await _webSocket?.close(1000, manual ? 'manual_close' : 'close');
    } catch (_) {}
    _webSocket = null;
    _activeWsSessionId = null;
    _activeWsUrlOverride = null;
    if (mounted) {
      setState(() {
        _wsConnState = _WsConnectionState.idle;
      });
    }
  }

  Map<String, dynamic>? _decodeWsPayload(dynamic data) {
    try {
      if (data is String) {
        final obj = jsonDecode(data);
        return obj is Map<String, dynamic> ? obj : null;
      }
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return null;
  }

  void _flushAssistantDelta({bool scroll = true}) {
    if (_assistantDeltaChars == 0) return;
    _assistantDeltaFlushTimer?.cancel();
    _assistantDeltaFlushTimer = null;

    final text = _assistantDeltaBuffer.toString();
    _assistantDeltaBuffer.clear();
    _assistantDeltaChars = 0;

    if (text.isEmpty) return;
    setState(() {
      if (_messages.isNotEmpty) {
        final last = _messages.last;
        if (last.role != 'user' &&
            last.contents.isNotEmpty &&
            last.contents.first is TextMessageContent) {
          final first = last.contents.first as TextMessageContent;
          _messages[_messages.length - 1] = last.copyWith(
            contents: [
              TextMessageContent(text: '${first.text}$text'),
              ...last.contents.skip(1),
            ],
          );
          return;
        }
      }
      _messages.add(
        ChatMessage(
          id: 'asst-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          createdAt: DateTime.now(),
          contents: [TextMessageContent(text: text)],
        ),
      );
    });
    if (scroll) _scrollToBottom();
  }

  void _appendAssistantDelta(String delta) {
    if (delta.isEmpty) return;
    _assistantDeltaBuffer.write(delta);
    _assistantDeltaChars += delta.length;
    _assistantDeltaFlushTimer ??= Timer(
      const Duration(milliseconds: 60),
      () => _flushAssistantDelta(scroll: true),
    );
  }

  void _finalizePrevToolDone() {
    _markLastProcessingToolStatus('done');
  }

  void _markLastProcessingToolStatus(String nextStatus) {
    final next = nextStatus.toLowerCase();
    for (var mi = _messages.length - 1; mi >= 0; mi--) {
      final msg = _messages[mi];
      final contents = msg.contents;
      for (var ci = contents.length - 1; ci >= 0; ci--) {
        final c = contents[ci];
        if (c is! ToolMessageContent) continue;
        final cur = (c.status ?? '').toLowerCase();
        if (cur != 'processing') continue;
        final nextContents = List<MessageContent>.from(contents);
        nextContents[ci] = c.copyWith(status: next);
        setState(() {
          _messages[mi] = msg.copyWith(contents: nextContents);
        });
        return;
      }
    }
  }

  void _markLastToolOutcome(String nextStatus) {
    final next = nextStatus.toLowerCase();
    for (var mi = _messages.length - 1; mi >= 0; mi--) {
      final msg = _messages[mi];
      final contents = msg.contents;
      for (var ci = contents.length - 1; ci >= 0; ci--) {
        final c = contents[ci];
        if (c is! ToolMessageContent) continue;
        final cur = (c.status ?? '').toLowerCase();
        final shouldUpdate = next == 'error'
            ? cur != 'error'
            : next == 'warning'
            ? cur != 'warning' && cur != 'error'
            : cur != 'done' && cur != 'error' && cur != 'warning';
        if (!shouldUpdate) return;
        final nextContents = List<MessageContent>.from(contents);
        nextContents[ci] = c.copyWith(status: next);
        setState(() {
          _messages[mi] = msg.copyWith(contents: nextContents);
        });
        return;
      }
    }
  }

  bool _userPayloadHasToolResult(Map<String, dynamic> payload) {
    try {
      final message = payload['message'];
      if (message is! Map<String, dynamic>) return false;
      final content = message['content'];
      if (content is! List) return false;
      return content.any(
        (it) => it is Map<String, dynamic> && it['type'] == 'tool_result',
      );
    } catch (_) {
      return false;
    }
  }

  bool _userPayloadIsToolResultError(Map<String, dynamic> payload) {
    try {
      final message = payload['message'];
      if (message is! Map<String, dynamic>) return false;
      final content = message['content'];
      if (content is! List) return false;
      for (final it in content) {
        if (it is Map<String, dynamic> &&
            it['type'] == 'tool_result' &&
            it['is_error'] == true) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _appendCancelledNotice() {
    const text = 'Request cancelled by user.';
    if (!mounted) return;
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      if (last.role == 'warning' &&
          last.contents.isNotEmpty &&
          last.contents.first is TextMessageContent) {
        final existing = (last.contents.first as TextMessageContent).text
            .trim();
        if (existing == text) return;
      }
    }
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'cancelled-${DateTime.now().millisecondsSinceEpoch}',
          role: 'warning',
          createdAt: DateTime.now(),
          contents: const [TextMessageContent(text: text)],
        ),
      );
    });
    _scrollToBottom();
  }

  void _handleWsPayload(Map<String, dynamic> payload) {
    final type = payload['type']?.toString();

    if (type == 'system' || MessageParser.isSystemPayload(payload)) return;

    // History frames are ignored; history is loaded via HTTP.
    if (type == 'history' || type == 'history_complete') return;

    // Proxy status can disable auto-connect.
    if (type == 'proxy_status') {
      final st = payload['status']?.toString();
      if (st == 'remote_connect_failed') {
        _autoConnectDisabled = true;
      }
      return;
    }

    // Web filters these from history; treat them as non-chat side-effect frames.
    if (type == 'deployment_start' || type == 'deployment_complete') {
      if (type == 'deployment_complete') {
        _refreshMiniPreview(fetchLatestUrl: true);
      }
      return;
    }

    // Best-effort de-dup (skip for deltas and allow assistant_message to overwrite).
    try {
      if (type != 'content_block_delta' &&
          type != 'message_delta' &&
          type != 'assistant_message') {
        String? wsKey;
        final uuid = payload['uuid'];
        if (uuid is String && uuid.isNotEmpty) {
          wsKey = uuid;
        } else if (payload['message'] is Map<String, dynamic>) {
          final mid = (payload['message'] as Map<String, dynamic>)['id'];
          if (mid is String && mid.isNotEmpty) wsKey = mid;
        } else {
          final id = payload['id'];
          if (id is String && id.isNotEmpty) wsKey = id;
        }
        if (wsKey != null) {
          if (_seenWsKeys.contains(wsKey)) return;
          _seenWsKeys.add(wsKey);
          if (_seenWsKeys.length > 500) _seenWsKeys.clear();
        }
      }
    } catch (_) {}

    // Ensure any buffered deltas are rendered before applying a new non-delta frame.
    if (type != 'content_block_delta' && type != 'message_delta') {
      _flushAssistantDelta(scroll: false);
    }

    if (type == 'content_block_delta' || type == 'message_delta') {
      final delta = MessageParser.normalizeOpcodeText(payload);
      if (delta != null && delta.isNotEmpty) _appendAssistantDelta(delta);
      return;
    }

    if (type == 'assistant_message') {
      // Any newer non-error message means older tool rows should not stay "processing".
      _finalizePrevToolDone();
      final contents = MessageParser.createMessageContentsFromPayload(payload);
      if (contents.isEmpty) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.last.role != 'user') {
          final last = _messages.last;
          _messages[_messages.length - 1] = last.copyWith(
            contents: contents,
            createdAt: DateTime.now(),
          );
        } else {
          _messages.add(
            ChatMessage(
              id: 'asst-${DateTime.now().millisecondsSinceEpoch}',
              role: 'assistant',
              createdAt: DateTime.now(),
              contents: contents,
            ),
          );
        }
      });
      _scrollToBottom();
      return;
    }

    if (type == 'assistant') {
      // Structured assistant content (may include tool_use); close previous processing tools.
      _finalizePrevToolDone();
    }

    if (type == 'tool_result' || type == 'task_update') {
      if (type == 'task_update') {
        _finalizePrevToolDone();
      }
      if (type == 'tool_result') {
        final isErr = payload['is_error'] == true;
        _markLastToolOutcome(isErr ? 'error' : 'done');
      }
      final contents = MessageParser.createMessageContentsFromPayload(payload);
      if (contents.isEmpty) return;
      final toolMsg = ChatMessage(
        id: 'tool-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        createdAt: DateTime.now(),
        contents: contents,
      );
      setState(() {
        final next = MessageParser.mergeToolResultsIntoPrevToolCalls([
          ..._messages,
          toolMsg,
        ]);
        _messages
          ..clear()
          ..addAll(next);
      });
      _scrollToBottom();
      return;
    }

    if (type == 'result' ||
        type == 'complete' ||
        type == 'error' ||
        type == 'cancelled') {
      if (type == 'error') {
        _markLastToolOutcome('error');
        _sessionError = true;
        _sessionDone = false;
      } else if (type == 'cancelled') {
        _markLastToolOutcome('warning');
        _sessionDone = true;
        _sessionError = false;
        _appendCancelledNotice();
      } else {
        _finalizePrevToolDone();
        _sessionDone = true;
        _sessionError = false;
      }
      _autoConnectDisabled = true;
      if (mounted) {
        setState(() {});
      }
      if (type == 'result' || type == 'complete' || type == 'cancelled') {
        _refreshMiniPreview(fetchLatestUrl: false);
      }
      _signalOutbox();
      unawaited(_drainOutbox());
      unawaited(_maybePowerSaveCloseWebSocket());
      return;
    }

    // Some servers emit tool results wrapped as `type=user` with tool_result blocks.
    if (type == 'user' && _userPayloadHasToolResult(payload)) {
      final isErr = _userPayloadIsToolResultError(payload);
      _markLastToolOutcome(isErr ? 'error' : 'done');
      final contents = MessageParser.createMessageContentsFromPayload(payload);
      if (contents.isNotEmpty) {
        final toolMsg = ChatMessage(
          id: 'ws-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          createdAt: DateTime.now(),
          contents: contents,
        );
        setState(() {
          final next = MessageParser.mergeToolResultsIntoPrevToolCalls([
            ..._messages,
            toolMsg,
          ]);
          _messages
            ..clear()
            ..addAll(next);
        });
        _scrollToBottom();
        return;
      }
    }

    final contents = MessageParser.createMessageContentsFromPayload(payload);
    if (contents.isEmpty) return;
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'ws-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          createdAt: DateTime.now(),
          contents: contents,
        ),
      );
    });
    _scrollToBottom();
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    if (_manualWsClose || _autoConnectDisabled) return;
    final sid = _activeWsSessionId;
    if (sid == null || sid.isEmpty) return;

    // Backend uses 4401/4404 for auth/ownership errors; don't retry those.
    final code = _webSocket?.closeCode;
    if (code == 4401 || code == 4404) return;

    if (_reconnectAttempts >= 3) return;
    final delayMs = (1000 * (1 << _reconnectAttempts)).clamp(1000, 30000);
    _reconnectAttempts += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      unawaited(
        _ensureWebSocketOpen(sid, websocketUrlOverride: _activeWsUrlOverride),
      );
    });
  }

  Future<void> _ensureWebSocketOpen(
    String sessionId, {
    String? websocketUrlOverride,
  }) async {
    if (!mounted) return;

    final trimmedOverride = websocketUrlOverride?.trim();

    if (_webSocket != null &&
        _activeWsSessionId == sessionId &&
        _webSocket!.readyState == WebSocket.open) {
      if (trimmedOverride != null && trimmedOverride.isNotEmpty) {
        _activeWsUrlOverride = trimmedOverride;
      }
      return;
    }

    final prevSessionId = _activeWsSessionId;

    if (_webSocket != null) {
      await _closeWebSocket(manual: true);
    }

    _reconnectTimer?.cancel();
    _manualWsClose = false;
    _activeWsSessionId = sessionId;
    if (trimmedOverride != null && trimmedOverride.isNotEmpty) {
      _activeWsUrlOverride = trimmedOverride;
    } else if (prevSessionId != sessionId) {
      _activeWsUrlOverride = null;
    }
    setState(() {
      _wsConnState = _WsConnectionState.connecting;
    });

    try {
      await _webSocketSubscription?.cancel();
    } catch (_) {}
    _webSocketSubscription = null;

    try {
      final wsUrl = await _chatService.buildProjectSessionWebSocketUrl(
        sessionId: sessionId,
        websocketUrlOverride: _activeWsUrlOverride,
      );
      final ws = await WebSocket.connect(wsUrl);
      if (!mounted) {
        await ws.close(1000, 'unmounted');
        return;
      }
      _webSocket = ws;
      _reconnectAttempts = 0;
      setState(() {
        _wsConnState = _WsConnectionState.connected;
      });

      _webSocketSubscription = ws.listen(
        (data) {
          final obj = _decodeWsPayload(data);
          if (obj != null) _handleWsPayload(obj);
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _wsConnState = _WsConnectionState.failed;
          });
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _wsConnState = _WsConnectionState.failed;
          });
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _wsConnState = _WsConnectionState.failed;
      });
      _scheduleReconnect();
    }
  }

  String _taskLabel() {
    final working =
        _isLoading ||
        _wsConnState == _WsConnectionState.connecting ||
        (_wsConnState == _WsConnectionState.connected &&
            !_autoConnectDisabled &&
            !_sessionDone &&
            !_sessionError &&
            (_activeWsSessionId ?? '').trim().isNotEmpty);
    return _sessionError
        ? 'Error'
        : _sessionDone
        ? 'Done'
        : working
        ? 'Working'
        : 'Ready';
  }

  String _workspaceStatusLabel() {
    switch (_workspacePhase) {
      case WorkspacePhase.ready:
        return 'Ready';
      case WorkspacePhase.starting:
        return 'Starting';
      case WorkspacePhase.syncing:
        return 'Syncing';
      case WorkspacePhase.standby:
        return 'Standby';
      case WorkspacePhase.archived:
        return 'Archived';
      case WorkspacePhase.error:
        return 'Error';
      case WorkspacePhase.unknown:
        return 'Unknown';
    }
  }

  /// Send a message
  Future<void> _sendMessage(String text, {bool forceNewSession = false}) async {
    final prompt = text.trim();
    if (prompt.isEmpty) return;

    final shouldQueue =
        !forceNewSession &&
        (_outboxItems.isNotEmpty ||
            _workspacePhase != WorkspacePhase.ready ||
            !_isTaskIdleForQueue() ||
            _outboxMode == OutboxMode.dispatching);
    if (shouldQueue) {
      _outboxEnqueue(prompt);
      return;
    }

    await _dispatchPrompt(prompt, forceNewSession: forceNewSession);
  }

  Future<void> _dispatchPrompt(
    String prompt, {
    bool forceNewSession = false,
  }) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _sessionDone = false;
      _sessionError = false;
      _autoConnectDisabled = false;
    });

    final tempId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final userMessage = ChatMessage(
      id: tempId,
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: prompt)],
    );

    setState(() {
      _messages.add(userMessage);
      _messageStatuses[tempId] = MessageStatus.pending;
    });

    _scrollToBottom();

    try {
      await _ensureWorkspaceReadyForSend();
      final isNew = forceNewSession || _currentSessionId == null;
      final response = await _chatService.executeSession(
        projectId: widget.projectId,
        prompt: prompt,
        sessionType: isNew ? 'new' : 'continue',
        sessionId: isNew ? null : _currentSessionId,
        model: _selectedModelId.trim().isEmpty ? null : _selectedModelId.trim(),
        optimisticMessage: prompt,
      );

      if (!mounted) return;
      final sid = response.sessionId;

      setState(() {
        _currentSessionId = sid;
        _isLoading = false;
        _messageStatuses[tempId] = MessageStatus.sent;
        _autoConnectDisabled = false;
      });

      await _ensureWebSocketOpen(sid);
      _signalOutbox();
      unawaited(_drainOutbox());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messageStatuses[tempId] = MessageStatus.failed;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      _signalOutbox();
      unawaited(_drainOutbox());
    }
  }

  Future<void> _retryMessage(ChatMessage message) async {
    if (_isLoading) return;
    final first = message.contents.isNotEmpty ? message.contents.first : null;
    if (first is! TextMessageContent) return;
    final prompt = first.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _messageStatuses[message.id] = MessageStatus.pending;
      _sessionDone = false;
      _sessionError = false;
      _autoConnectDisabled = false;
    });

    try {
      await _ensureWorkspaceReadyForSend();
      final response = await _chatService.executeSession(
        projectId: widget.projectId,
        prompt: prompt,
        sessionType: 'new',
        model: _selectedModelId.trim().isEmpty ? null : _selectedModelId.trim(),
        optimisticMessage: prompt,
      );
      if (!mounted) return;
      final sid = response.sessionId;
      setState(() {
        _currentSessionId = sid;
        _isLoading = false;
        _messageStatuses[message.id] = MessageStatus.sent;
        _autoConnectDisabled = false;
      });
      await _ensureWebSocketOpen(sid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messageStatuses[message.id] = MessageStatus.failed;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Retry failed: $e')));
    }
  }

  /// Scroll to bottom of messages
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showClearChatDialog() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear != true || !mounted) return;
    setState(() {
      _messages.clear();
    });
  }

  void _handleAppBarAction(_ChatAppBarAction action) {
    switch (action) {
      case _ChatAppBarAction.openOverview:
        context.push('/projects/${widget.projectId}?tab=overview');
        break;
      case _ChatAppBarAction.openEnvironment:
        context.push('/projects/${widget.projectId}?tab=environment');
        break;
      case _ChatAppBarAction.openDatabase:
        context.push('/projects/${widget.projectId}?tab=database');
        break;
      case _ChatAppBarAction.openPayment:
        context.push('/projects/${widget.projectId}?tab=payment');
        break;
      case _ChatAppBarAction.openDeployHistory:
        context.push('/projects/${widget.projectId}?tab=deployment');
        break;
      case _ChatAppBarAction.openAnalytics:
        context.push('/projects/${widget.projectId}?tab=analytics');
        break;
      case _ChatAppBarAction.workspaceStatus:
        unawaited(_refreshWorkspaceStatus(bypassCache: true));
        break;
      case _ChatAppBarAction.refresh:
        unawaited(_refreshHistory(attemptReconnect: true));
        _refreshMiniPreview(fetchLatestUrl: true);
        break;
      case _ChatAppBarAction.clearChat:
        unawaited(_showClearChatDialog());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroTag = 'project-chat-messages-${widget.projectId}';

    Color dotColor;
    switch (_workspacePhase) {
      case WorkspacePhase.ready:
        dotColor = Colors.green;
        break;
      case WorkspacePhase.starting:
        dotColor = Colors.amber;
        break;
      case WorkspacePhase.syncing:
        dotColor = Colors.purple;
        break;
      case WorkspacePhase.standby:
      case WorkspacePhase.archived:
        dotColor = Colors.grey;
        break;
      case WorkspacePhase.error:
        dotColor = Colors.red;
        break;
      case WorkspacePhase.unknown:
        dotColor = Colors.grey;
        break;
    }

    final wsLabelParts = <String>[];
    final raw = _workspaceState?.status;
    if (raw != null && raw.trim().isNotEmpty) {
      wsLabelParts.add('status=$raw');
    }
    final ip = _workspaceState?.ip;
    final port = _workspaceState?.port;
    if (ip != null && port != null) {
      wsLabelParts.add('$ip:$port');
    }
    if (_workspaceError != null && _workspaceError!.trim().isNotEmpty) {
      wsLabelParts.add(_workspaceError!);
    }
    final wsTooltip = wsLabelParts.isEmpty
        ? 'Workspace'
        : wsLabelParts.join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat with AI',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axis: Axis.vertical,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ChatStatusPill(
                  key: ValueKey(_taskLabel()),
                  label: _taskLabel(),
                  isError: _sessionError,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: CompactSelector(
                options: _availableModels
                    .map(
                      (m) => CompactSelectorOption(value: m.id, label: m.name),
                    )
                    .toList(),
                value: _selectedModelId.trim().isEmpty
                    ? null
                    : _selectedModelId.trim(),
                displayLabel: _selectedModelLabel(),
                placeholder: 'Model',
                tooltip: 'Select model',
                leadingIcon: Icons.auto_awesome_rounded,
                minWidth: 108,
                maxWidth: 142,
                isLoading: _isLoadingModels || _isSwitchingModel,
                onChanged:
                    (_isLoadingModels ||
                        _isSwitchingModel ||
                        _availableModels.isEmpty)
                    ? null
                    : (value) => unawaited(_handleModelChanged(value)),
              ),
            ),
          ),
          PopupMenuButton<_ChatAppBarAction>(
            tooltip: wsTooltip,
            icon: const Icon(Icons.more_vert),
            onSelected: _handleAppBarAction,
            itemBuilder: (context) => [
              const PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.openOverview,
                child: Row(
                  children: [
                    Icon(Icons.dashboard_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Overview'),
                  ],
                ),
              ),
              const PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.openEnvironment,
                child: Row(
                  children: [
                    Icon(Icons.key_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Environment'),
                  ],
                ),
              ),
              const PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.openDatabase,
                child: Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Database'),
                  ],
                ),
              ),
              const PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.openPayment,
                child: Row(
                  children: [
                    Icon(Icons.payment_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Payment'),
                  ],
                ),
              ),
              const PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.openDeployHistory,
                child: Row(
                  children: [
                    Icon(Icons.history_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Deploy History'),
                  ],
                ),
              ),
              const PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.openAnalytics,
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Analytics'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.workspaceStatus,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Workspace: ${_workspaceStatusLabel()}'),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.refresh,
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 10),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem<_ChatAppBarAction>(
                value: _ChatAppBarAction.clearChat,
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 18),
                    SizedBox(width: 10),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Messages list
              Expanded(
                child: Hero(
                  tag: heroTag,
                  transitionOnUserGestures: true,
                  child: Material(
                    color: theme.colorScheme.surface,
                    child: _messages.isEmpty
                        ? _isLoadingHistory
                              ? const ChatScreenLoadingState()
                              : ChatScreenEmptyState(
                                  onQuickAction: _sendMessage,
                                )
                        : MessageList(
                            messages: _messages,
                            scrollController: _scrollController,
                            messageStatuses: _messageStatuses,
                            onRetry: _retryMessage,
                            onLoadMore: _loadMoreHistory,
                            hasMoreHistory: _hasMoreHistory,
                            isLoadingMore: _isLoadingMoreHistory,
                          ),
                  ),
                ),
              ),
              OutboxBar(
                count: _outboxItems.length,
                mode: _outboxMode,
                collapsed: _outboxCollapsed,
                onToggleCollapsed: () {
                  setState(() {
                    _outboxCollapsed = !_outboxCollapsed;
                  });
                },
                onOpen: () {
                  if (_outboxItems.isEmpty) return;
                  showOutboxSheet(
                    context,
                    items: _outboxItems,
                    mode: _outboxMode,
                    onClear: _outboxClear,
                    onDelete: _outboxDelete,
                    onUpdate: _outboxUpdate,
                  );
                },
              ),
              // Message input
              MessageInput(
                onSend: _sendMessage,
                isEnabled: !_isLoading,
                hintText: 'Type your message...',
                controller: _inputController,
                focusNode: _inputFocusNode,
                queueCount: _outboxItems.length,
                showSendPulse: _outboxMode == OutboxMode.dispatching,
              ),
            ],
          ),
          if ((_miniPreviewUrl ?? '').trim().isNotEmpty)
            Positioned.fill(
              child: FloatingPreviewDock(
                previewUrl: (_miniPreviewUrl ?? '').trim(),
                reloadVersion: _miniPreviewReloadVersion,
                topDock: 8,
              ),
            ),
        ],
      ),
    );
  }
}

enum _WsConnectionState { idle, connecting, connected, failed }
