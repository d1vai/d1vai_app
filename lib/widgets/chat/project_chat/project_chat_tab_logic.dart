part of '../../project_chat/project_chat_tab.dart';

class _OutboxAborted implements Exception {
  const _OutboxAborted();

  @override
  String toString() => 'outbox_aborted';
}

mixin _ProjectChatTabLogic on _ProjectChatTabStateBase {
  final StringBuffer _assistantDeltaBuffer = StringBuffer();
  int _assistantDeltaChars = 0;
  Timer? _assistantDeltaFlushTimer;

  String get _chatDraftKey => 'project_chat_draft:${widget.projectId}';
  String get _selectedEngine =>
      _selectedEngineMode == ChatEngineMode.fast ? 'claude' : 'codex';

  ChatEngineMode _engineModeFromStoredValue(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'fast':
      case 'claude':
        return ChatEngineMode.fast;
      case 'think_hard':
      case 'codex':
      default:
        return ChatEngineMode.thinkHard;
    }
  }

  String _engineModeStorageValue(ChatEngineMode mode) {
    return mode == ChatEngineMode.fast ? 'fast' : 'think_hard';
  }

  String? _normalizeSessionConfigValue(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  bool _canContinueCurrentSession() {
    final sid = _normalizeSessionConfigValue(_currentSessionId);
    if (sid == null) return false;
    return _normalizeSessionConfigValue(_lastSessionModelId) ==
            _normalizeSessionConfigValue(_selectedModelId) &&
        _normalizeSessionConfigValue(_lastSessionEngine) ==
            _normalizeSessionConfigValue(_selectedEngine);
  }

  void _rememberSessionConfig({String? modelId, String? engine}) {
    _lastSessionModelId = _normalizeSessionConfigValue(modelId);
    _lastSessionEngine = _normalizeSessionConfigValue(engine);
  }

  void _loadChatDraft() {
    try {
      final saved = _storageService.getString(_chatDraftKey)?.trimRight() ?? '';
      _lastPersistedChatDraft = saved;
      if (_chatInputController.text == saved) return;
      _chatInputController.value = TextEditingValue(
        text: saved,
        selection: TextSelection.collapsed(offset: saved.length),
      );
    } catch (_) {}
  }

  @override
  Future<void> _persistChatDraft(String value) async {
    final next = value.trimRight();
    _chatDraftPersistTimer?.cancel();
    _chatDraftPersistTimer = Timer(const Duration(milliseconds: 280), () async {
      if (next == _lastPersistedChatDraft) return;
      try {
        if (next.isEmpty) {
          await _storageService.remove(_chatDraftKey);
        } else {
          await _storageService.setString(_chatDraftKey, next);
        }
        _lastPersistedChatDraft = next;
      } catch (_) {}
    });
  }

  bool _noticeAllowed(String key, Duration cooldown) {
    final now = DateTime.now();
    final prev = _noticeCooldowns[key];
    if (prev != null && now.difference(prev) < cooldown) return false;
    _noticeCooldowns[key] = now;
    if (_noticeCooldowns.length > 64) {
      _noticeCooldowns.removeWhere(
        (_, value) => now.difference(value) > const Duration(minutes: 10),
      );
    }
    return true;
  }

  void _showInfoNotice({
    required String key,
    required String title,
    required String message,
    Duration cooldown = const Duration(seconds: 8),
    Duration duration = const Duration(seconds: 3),
    SnackBarPosition position = SnackBarPosition.top,
  }) {
    if (!mounted || !_noticeAllowed(key, cooldown)) return;
    SnackBarHelper.showInfo(
      context,
      title: title,
      message: message,
      position: position,
      duration: duration,
    );
  }

  void _showSuccessNotice({
    required String key,
    required String title,
    required String message,
    Duration cooldown = const Duration(seconds: 6),
    Duration duration = const Duration(seconds: 2),
    SnackBarPosition position = SnackBarPosition.top,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    if (!mounted || !_noticeAllowed(key, cooldown)) return;
    SnackBarHelper.showSuccess(
      context,
      title: title,
      message: message,
      position: position,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  void _showErrorNotice({
    required String key,
    required String title,
    required String message,
    Duration cooldown = const Duration(seconds: 10),
    SnackBarPosition position = SnackBarPosition.top,
  }) {
    if (!mounted || !_noticeAllowed(key, cooldown)) return;
    SnackBarHelper.showError(
      context,
      title: title,
      message: message,
      position: position,
    );
  }

  void _showWorkspaceWarmupUi() {
    final loc = AppLocalizations.of(context);
    if (_workspaceWarmupVisible || !mounted) return;
    setState(() {
      _workspaceWarmupVisible = true;
      _workspaceWarmupCompleted = false;
      _workspaceWarmupMessage =
          loc?.translate('workspace_warmup_inline_next') ??
          'Starting workspace. Sending next.';
    });
    _showInfoNotice(
      key: 'workspace_warmup_started',
      title: loc?.translate('workspace_title') ?? 'Workspace',
      message:
          loc?.translate('workspace_warmup_notice_next') ??
          'Starting. Sending next.',
      cooldown: const Duration(seconds: 12),
    );
  }

  void _completeWorkspaceWarmupUi() {
    final loc = AppLocalizations.of(context);
    if (!_workspaceWarmupVisible || !mounted) return;
    setState(() {
      _workspaceWarmupCompleted = true;
      _workspaceWarmupMessage =
          loc?.translate('workspace_warmup_inline_now') ??
          'Ready. Sending now.';
    });
  }

  void _hideWorkspaceWarmupUi() {
    if (!mounted) return;
    setState(() {
      _workspaceWarmupVisible = false;
      _workspaceWarmupCompleted = false;
      _workspaceWarmupMessage = null;
    });
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

  bool _isTaskIdleForQueue() {
    if (_isDeploying) return false;
    if (_isChatLoading) return false;
    if (_sessionThinking) return false;
    if (_isSwitchingModel) return false;
    if (_wsConnState == WsConnectionState.connecting) return false;
    final activeSid = (_activeWsSessionId ?? '').trim();
    final hasActiveStreaming =
        _wsConnState == WsConnectionState.connected &&
        !_autoConnectDisabled &&
        !_sessionDone &&
        !_sessionError &&
        activeSid.isNotEmpty;
    if (hasActiveStreaming) return false;
    return true;
  }

  bool _isModelReadyForSend() {
    return _selectedModelId.trim().isNotEmpty &&
        !_isLoadingModels &&
        !_isSwitchingModel;
  }

  bool _isAuthError(Object err) {
    final s = err.toString().toLowerCase();
    return s.contains('401') ||
        s.contains('auth') ||
        s.contains('unauthenticated') ||
        s.contains('expired');
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
      } catch (_) {
        // fall through and wait for next signal/backoff
      }
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

  Future<void> _waitForModelReady(int token) async {
    if (_isModelReadyForSend()) return;
    _setOutboxMode(OutboxMode.waitingModel);
    while (!_isModelReadyForSend()) {
      if (_outboxAbortToken != token) throw const _OutboxAborted();
      if (_modelConfigError != null && _isAuthError(_modelConfigError!)) {
        throw Exception('Model loading failed due to authentication.');
      }
      if (_workspacePhase == WorkspacePhase.ready &&
          !_isLoadingModels &&
          !_hasLoadedModelConfig) {
        unawaited(_loadModelConfigIfPossible());
      }
      try {
        await Future.any<void>([
          Future<void>.delayed(const Duration(milliseconds: 450)),
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

  void _outboxEnqueue(String prompt) {
    final p = prompt.trim();
    if (p.isEmpty) return;
    final needsCooldown = !_isTaskIdleForQueue();
    final item = OutboxItem(
      id: 'q-${DateTime.now().millisecondsSinceEpoch}-${_outboxItems.length}',
      prompt: p,
      enqueuedAt: DateTime.now(),
      needsCooldownAfterIdle: needsCooldown,
      status: OutboxItemStatus.queued,
    );
    if (!mounted) {
      _outboxItems.add(item);
      _setOutboxMode(OutboxMode.idle);
      _signalOutbox();
      unawaited(_drainOutbox());
      return;
    }
    setState(() {
      _outboxItems.add(item);
    });
    _signalOutbox();
    unawaited(_drainOutbox());
  }

  @override
  void _outboxDelete(OutboxItem item) {
    _abortOutboxDrain();
    if (!mounted) {
      _outboxItems.removeWhere((x) => x.id == item.id);
      return;
    }
    setState(() {
      _outboxItems.removeWhere((x) => x.id == item.id);
    });
    _signalOutbox();
    unawaited(_drainOutbox());
  }

  @override
  void _outboxUpdate(OutboxItem item, String nextPrompt) {
    final next = nextPrompt.trim();
    _abortOutboxDrain();
    if (!mounted) {
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
      return;
    }
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

  @override
  void _outboxClear() {
    _abortOutboxDrain();
    if (!mounted) return;
    setState(() {
      _outboxItems.clear();
      _outboxMode = OutboxMode.idle;
    });
    unawaited(_maybePowerSaveCloseWebSocket());
  }

  bool _outboxHasFailed() =>
      _outboxItems.any((x) => x.status == OutboxItemStatus.failed);

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
        await _waitForModelReady(token);
        await _waitForWorkspaceReady(token);
        final waited = await _waitForTaskIdle(token);
        if (waited || next.needsCooldownAfterIdle) {
          await _sleepAbortable(const Duration(milliseconds: 1500), token);
        }
      } on _OutboxAborted {
        return;
      }
      if (_outboxAbortToken != token) return;

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
        final msg = e.toString();
        setState(() {
          final i = _outboxItems.indexWhere((x) => x.id == next.id);
          if (i != -1) {
            _outboxItems[i] = _outboxItems[i].copyWith(
              status: OutboxItemStatus.failed,
              error: msg,
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

  Future<void> _maybePowerSaveCloseWebSocket() async {
    if (_outboxItems.isNotEmpty) return;
    if (_pendingAppendQueue.isNotEmpty || _pendingAppendTimer != null) return;
    final activeSid = (_activeWsSessionId ?? '').trim();
    final hasActiveStreaming =
        _wsConnState == WsConnectionState.connected &&
        !_autoConnectDisabled &&
        !_sessionDone &&
        !_sessionError &&
        activeSid.isNotEmpty;
    if (hasActiveStreaming) return;
    if (_wsConnState != WsConnectionState.connected) return;
    await _closeWebSocket(manual: true);
  }

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.previewUrl;
    _currentChatTabIndex = _chatSubTabIndexFromName(widget.initialSubTab);
    _loadChatDraft();
    unawaited(_bootstrapWorkspace());
  }

  @override
  void didUpdateWidget(covariant ProjectChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextUrl = widget.previewUrl;
    if (nextUrl != null &&
        nextUrl.trim().isNotEmpty &&
        nextUrl.trim() != (_previewUrl ?? '').trim()) {
      setState(() {
        _previewUrl = nextUrl.trim();
        _previewKey += 1;
      });
    }
    if (oldWidget.projectId != widget.projectId) {
      _deployAutoClearTimer?.cancel();
      _modelConfigRetryTimer?.cancel();
      setState(() {
        _previewUrl = widget.previewUrl;
        _previewKey += 1;
        _currentChatTabIndex = _chatSubTabIndexFromName(widget.initialSubTab);
        _isDeploying = false;
        _deployFramework = null;
        _availableModels = <ModelInfo>[];
        _selectedModelId = '';
        _isLoadingModels = false;
        _isSwitchingModel = false;
        _hasLoadedModelConfig = false;
        _modelConfigError = null;
      });
      _loadChatDraft();
      unawaited(_bootstrapWorkspace());
    } else if (oldWidget.initialSubTab != widget.initialSubTab) {
      final nextIndex = _chatSubTabIndexFromName(widget.initialSubTab);
      if (nextIndex != _currentChatTabIndex) {
        setState(() {
          _currentChatTabIndex = nextIndex;
        });
      }
    }
  }

  @override
  void dispose() {
    _assistantDeltaFlushTimer?.cancel();
    _reconnectTimer?.cancel();
    _workspacePollTimer?.cancel();
    _modelConfigRetryTimer?.cancel();
    _deployAutoClearTimer?.cancel();
    _thinkingClearTimer?.cancel();
    _chatDraftPersistTimer?.cancel();
    _scrollToBottomTimer?.cancel();
    _pendingAppendTimer?.cancel();
    _webSocketSubscription?.cancel();
    _outboxSignals.close();
    _manualWsClose = true;
    _webSocket?.close(1000, 'dispose');
    _chatScrollController.dispose();
    _chatInputController.dispose();
    _chatInputFocusNode.dispose();
    super.dispose();
  }

  void _setSessionThinking(bool v) {
    if (_sessionThinking == v) return;
    if (!mounted) {
      _sessionThinking = v;
      return;
    }
    setState(() {
      _sessionThinking = v;
    });
  }

  void _markSessionStarted() {
    _thinkingClearTimer?.cancel();
    if (!mounted) {
      _sessionDone = false;
      _sessionError = false;
      _sessionThinking = false;
      return;
    }
    setState(() {
      _sessionDone = false;
      _sessionError = false;
      _sessionThinking = false;
    });
  }

  void _markSessionDone() {
    _thinkingClearTimer?.cancel();
    _lastSessionFinishedAt = DateTime.now();
    if (!mounted) {
      _sessionDone = true;
      _sessionError = false;
      _sessionThinking = false;
      return;
    }
    setState(() {
      _sessionDone = true;
      _sessionError = false;
      _sessionThinking = false;
    });
  }

  void _markSessionError() {
    _thinkingClearTimer?.cancel();
    _lastSessionFinishedAt = DateTime.now();
    if (!mounted) {
      _sessionDone = false;
      _sessionError = true;
      _sessionThinking = false;
      return;
    }
    setState(() {
      _sessionDone = false;
      _sessionError = true;
      _sessionThinking = false;
    });
  }

  void _scheduleDeployAutoClear([
    Duration duration = const Duration(minutes: 3),
  ]) {
    _deployAutoClearTimer?.cancel();
    _deployAutoClearTimer = Timer(duration, () {
      if (!mounted) return;
      if (!_isDeploying) return;
      setState(() {
        _isDeploying = false;
        _deployFramework = null;
      });
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

  @override
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
      if (phase == WorkspacePhase.ready && !_hasLoadedModelConfig) {
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
        _workspaceError = e.toString();
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
      if (!_hasLoadedModelConfig) {
        unawaited(_loadModelConfigIfPossible());
      }
      _signalOutbox();
      unawaited(_drainOutbox());
      _workspacePollErrorStreak = 0;
      _scheduleWorkspacePoll(WorkspacePhase.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspacePhase = WorkspacePhase.error;
        _workspaceError = e.toString();
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
    await _refreshWorkspaceStatus(bypassCache: false);
    if (_workspacePhase == WorkspacePhase.ready) return;
    _showWorkspaceWarmupUi();
    try {
      await _maybeWarmupWorkspace();
      if (_workspacePhase != WorkspacePhase.ready) {
        throw Exception(_workspaceError ?? 'Workspace is not ready');
      }
      _completeWorkspaceWarmupUi();
    } catch (_) {
      _hideWorkspaceWarmupUi();
      rethrow;
    }
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted && _workspacePhase == WorkspacePhase.ready) {
          _hideWorkspaceWarmupUi();
        }
      }),
    );
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
      _modelConfigError = null;
    });

    try {
      final config = await _modelConfigService.getModelConfig(retries: 0);
      if (!mounted) return;
      final models = config.availableModels;
      final firstModel = models.isNotEmpty ? models.first.id.trim() : '';
      final cachedModel =
          (await _modelConfigService.getCachedModel())?.trim() ?? '';
      final cachedEngineMode = _engineModeFromStoredValue(
        _storageService.getString(chatEngineModeCacheKey) ??
            _storageService.getString('project_chat_engine_mode') ??
            'think_hard',
      );
      final modelExists =
          cachedModel.isNotEmpty &&
          models.any((m) => m.id.trim() == cachedModel);
      final selected = modelExists ? cachedModel : firstModel;

      setState(() {
        _availableModels = models;
        _selectedModelId = selected;
        _selectedEngineMode = cachedEngineMode;
        _isLoadingModels = false;
        _hasLoadedModelConfig = true;
        _modelConfigError = null;
      });

      await _storageService.setString(
        chatEngineModeCacheKey,
        _engineModeStorageValue(cachedEngineMode),
      );

      if (selected.isNotEmpty) {
        await _modelConfigService.setCachedModel(selected);
        if (config.model.trim() != selected) {
          try {
            await _modelConfigService.setModelConfig(selected, retries: 0);
          } catch (_) {
            // Non-fatal: UI local selection still takes effect for sends.
          }
        }
      }
      _modelConfigRetryTimer?.cancel();
      _signalOutbox();
      unawaited(_drainOutbox());
    } catch (e) {
      if (!mounted) return;
      final authErr = _isAuthError(e);
      setState(() {
        _isLoadingModels = false;
        _hasLoadedModelConfig = false;
        _availableModels = <ModelInfo>[];
        _selectedModelId = '';
        _modelConfigError = e.toString();
      });
      _signalOutbox();
      if (authErr) {
        final loc = AppLocalizations.of(context);
        _showErrorNotice(
          key: 'model_auth_expired',
          title: loc?.translate('model_switch_title') ?? 'Model',
          message:
              loc?.translate('model_load_auth_expired') ??
              'Login expired. Please sign in again to load models.',
        );
      } else {
        _scheduleModelConfigRetry();
      }
    }
  }

  @override
  Future<void> _handleModelChanged(String modelId) async {
    final next = modelId.trim();
    if (next.isEmpty || next == _selectedModelId || _isSwitchingModel) return;
    if (!mounted) return;

    setState(() {
      _isSwitchingModel = true;
      _modelConfigError = null;
    });
    _signalOutbox();

    try {
      await _modelConfigService.setModelConfig(next, retries: 0);
      await _modelConfigService.setCachedModel(next);
      await _resetExecuteSessionForModelSwitch();
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
      setState(() {
        _modelConfigError = e.toString();
      });
      SnackBarHelper.showError(
        context,
        title:
            AppLocalizations.of(context)?.translate('model_switch_title') ??
            'Model',
        message:
            (AppLocalizations.of(context)?.translate('model_switch_failed') ??
                    'Failed to switch model: {error}')
                .replaceAll('{error}', '$e'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingModel = false;
        });
      }
      _signalOutbox();
      unawaited(_drainOutbox());
    }
  }

  @override
  Future<void> _handleEngineChanged(ChatEngineMode nextMode) async {
    if (nextMode == _selectedEngineMode) {
      return;
    }
    if (!mounted) return;

    final loc = AppLocalizations.of(context);
    setState(() {
      _selectedEngineMode = nextMode;
    });
    await _storageService.setString(
      chatEngineModeCacheKey,
      _engineModeStorageValue(nextMode),
    );
    await _storageService.remove('project_chat_engine_mode');
    await _resetExecuteSessionForModelSwitch();

    if (!mounted) return;
    final modeLabel = nextMode == ChatEngineMode.fast
        ? (loc?.translate('project_chat_engine_fast') ?? 'Fast')
        : (loc?.translate('project_chat_engine_think_hard') ?? 'Think Hard');
    final template =
        loc?.translate('project_chat_engine_switch_success') ??
        'Switched to {mode}';
    SnackBarHelper.showSuccess(
      context,
      title: loc?.translate('project_chat_engine_title') ?? 'Engine',
      message: template.replaceAll('{mode}', modeLabel),
      position: SnackBarPosition.top,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _resetExecuteSessionForModelSwitch() async {
    _abortOutboxDrain();
    await _closeWebSocket(manual: true);
    if (!mounted) {
      _currentSessionId = null;
      _lastSessionModelId = null;
      _lastSessionEngine = null;
      _sessionThinking = false;
      _sessionDone = false;
      _sessionError = false;
      _autoConnectDisabled = false;
      return;
    }
    setState(() {
      _currentSessionId = null;
      _lastSessionModelId = null;
      _lastSessionEngine = null;
      _sessionThinking = false;
      _sessionDone = false;
      _sessionError = false;
      _autoConnectDisabled = false;
    });
  }

  /// 初始化聊天会话（只加载历史记录）
  @override
  Future<void> _initializeChat() async {
    if (_historyLoaded) return;

    try {
      await _loadChatHistory();
    } catch (e) {
      debugPrint('Failed to initialize chat: $e');
    }
  }

  /// 加载聊天历史
  Future<void> _loadChatHistory() async {
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

    try {
      const limit = 60;
      final history = await _chatService.getChatHistory(
        projectId: widget.projectId,
        limit: limit,
        messageType: 'all',
        includePayload: true,
      );

      if (!mounted) return;
      historyOk = true;

      history.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final merged = MessageParser.prepareHistoryMessages(history);

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

      ChatHistoryEntry? newestWithSession;
      ChatHistoryEntry? newestPromptForSession;
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
      if (nextSessionId != null && nextSessionId.isNotEmpty) {
        for (final e in history.reversed) {
          if ((e.messageType ?? '').trim() != 'prompt') continue;
          final pm = payloadMap(e.payload);
          if (pm == null) continue;
          final sid = pm['session_id'];
          if (sid is String && sid.trim() == nextSessionId) {
            newestPromptForSession = e;
            break;
          }
        }
      }

      final hydrated = MessageParser.mergeRefreshedHistoryWithLocal(
        merged,
        _chatMessages,
      );

      setState(() {
        _chatMessages
          ..clear()
          ..addAll(hydrated);
        _messageStatuses.clear();
        _isLoadingHistory = false;
        _historyLoaded = true;
        _hasMoreHistory = history.length >= limit;
        _oldestMessageAt = history.isNotEmpty ? history.first.createdAt : null;
        _autoConnectDisabled = nextAutoConnectDisabled;
        _currentSessionId = (nextSessionId != null && nextSessionId.isNotEmpty)
            ? nextSessionId
            : _currentSessionId;
        _lastSessionModelId = _normalizeSessionConfigValue(
          payloadMap(newestPromptForSession?.payload)?['model']?.toString(),
        );
        _lastSessionEngine = _normalizeSessionConfigValue(
          payloadMap(newestPromptForSession?.payload)?['engine']?.toString(),
        );
      });

      // Find latest meaningful type timestamp (for stale guarding)
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

      // Match web behavior: optionally reconnect to a recent session to stream live output.
      if (!nextAutoConnectDisabled &&
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
      debugPrint('Failed to load chat history: $e');
    } finally {
      final canAttemptReconnect =
          mounted && !(disableAutoConnect || nextAutoConnectDisabled);
      final last = lastAt;
      final isStale =
          last != null && DateTime.now().difference(last) > staleWindow;
      if (canAttemptReconnect && !isStale) {
        // Prefer backend-provided active session on refresh (more reliable than parsing history).
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

  @override
  Future<void> _loadMoreHistory() async {
    if (_isLoadingHistory || _isLoadingMoreHistory) return;
    if (!_hasMoreHistory) return;
    final before = _oldestMessageAt;
    if (before == null) return;

    setState(() {
      _isLoadingMoreHistory = true;
    });

    try {
      const limit = 60;
      final history = await _chatService.getChatHistory(
        projectId: widget.projectId,
        limit: limit,
        messageType: 'all',
        includePayload: true,
        beforeTs: before.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      history.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final older = MessageParser.prepareHistoryMessages(history);
      final existingIds = _chatMessages.map((m) => m.id).toSet();
      final deduped = older.where((m) => !existingIds.contains(m.id)).toList();
      final merged = MessageParser.dedupeRepeatedResultMessages(
        MessageParser.mergeToolResultsIntoPrevToolCalls([
          ...deduped,
          ..._chatMessages,
        ]),
      );
      final prepended = MessageParser.prependOlderMessages(
        deduped,
        _chatMessages,
      );
      final finalMessages = MessageParser.dedupeRepeatedResultMessages(
        MessageParser.mergeToolResultsIntoPrevToolCalls(prepended),
      );

      setState(() {
        _chatMessages
          ..clear()
          ..addAll(finalMessages.isNotEmpty ? finalMessages : merged);
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

  Future<void> _closeWebSocket({bool manual = true}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _manualWsClose = manual;
    if (mounted) {
      setState(() {
        _wsConnState = WsConnectionState.idle;
      });
    } else {
      _wsConnState = WsConnectionState.idle;
    }

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
    _pendingAppendTimer?.cancel();
    _pendingAppendTimer = null;
    _pendingAppendQueue.clear();
    _pendingAppendWsKeys.clear();
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

  bool _sameRenderableMessage(ChatMessage a, ChatMessage b) {
    if (a.role != b.role) return false;
    return MessageParser.stableStringify(a.toJson()) ==
        MessageParser.stableStringify(b.toJson());
  }

  List<ChatMessage> _appendIfDifferentFromPrevious(
    List<ChatMessage> messages,
    ChatMessage nextMessage,
  ) {
    if (messages.isNotEmpty &&
        _sameRenderableMessage(messages.last, nextMessage)) {
      return messages;
    }
    return [...messages, nextMessage];
  }

  void _flushNextPendingAppend() {
    _pendingAppendTimer?.cancel();
    _pendingAppendTimer = null;
    if (_pendingAppendQueue.isEmpty || !mounted) return;

    final item = _pendingAppendQueue.removeAt(0);
    final wsKey = item.wsKey;
    if (wsKey != null && wsKey.isNotEmpty) {
      _pendingAppendWsKeys.remove(wsKey);
    }

    setState(() {
      if (wsKey != null &&
          wsKey.isNotEmpty &&
          _chatMessages.any((message) => message.meta?['wsKey'] == wsKey)) {
        return;
      }
      final next = _appendIfDifferentFromPrevious(_chatMessages, item.message);
      final deduped = MessageParser.dedupeRepeatedResultMessages(next);
      _chatMessages
        ..clear()
        ..addAll(deduped);
    });
    _scrollToBottom(force: false);

    if (_pendingAppendQueue.isNotEmpty) {
      final head = _pendingAppendQueue.first;
      _pendingAppendTimer = Timer(
        Duration(milliseconds: head.delayMs.clamp(0, 120)),
        _flushNextPendingAppend,
      );
    }
  }

  void _enqueuePendingAppend(
    ChatMessage message, {
    String? wsKey,
    int delayMs = 0,
  }) {
    final normalizedKey = (wsKey ?? '').trim();
    if (normalizedKey.isNotEmpty &&
        _pendingAppendWsKeys.contains(normalizedKey)) {
      return;
    }
    final pendingLast = _pendingAppendQueue.isNotEmpty
        ? _pendingAppendQueue.last.message
        : null;
    if (pendingLast != null && _sameRenderableMessage(pendingLast, message)) {
      return;
    }
    if (normalizedKey.isNotEmpty) {
      _pendingAppendWsKeys.add(normalizedKey);
    }
    _pendingAppendQueue.add(
      _PendingAppendItem(
        message: message,
        wsKey: normalizedKey.isEmpty ? null : normalizedKey,
        delayMs: delayMs,
      ),
    );

    if (_pendingAppendTimer == null) {
      final head = _pendingAppendQueue.first;
      _pendingAppendTimer = Timer(
        Duration(milliseconds: head.delayMs.clamp(0, 120)),
        _flushNextPendingAppend,
      );
    }
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
      if (_chatMessages.isNotEmpty) {
        final last = _chatMessages.last;
        if (last.role != 'user' &&
            last.contents.isNotEmpty &&
            last.contents.first is TextMessageContent) {
          final first = last.contents.first as TextMessageContent;
          _chatMessages[_chatMessages.length - 1] = last.copyWith(
            contents: [
              TextMessageContent(text: '${first.text}$text'),
              ...last.contents.skip(1),
            ],
          );
          return;
        }
      }

      _chatMessages.add(
        ChatMessage(
          id: 'asst-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          createdAt: DateTime.now(),
          contents: [TextMessageContent(text: text)],
        ),
      );
    });
    if (scroll) _scrollToBottom(force: false);
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
    for (var mi = _chatMessages.length - 1; mi >= 0; mi--) {
      final msg = _chatMessages[mi];
      final contents = msg.contents;
      for (var ci = contents.length - 1; ci >= 0; ci--) {
        final c = contents[ci];
        if (c is! ToolMessageContent) continue;
        final cur = (c.status ?? '').toLowerCase();
        if (cur != 'processing') continue;
        final nextContents = List<MessageContent>.from(contents);
        nextContents[ci] = c.copyWith(status: next);
        setState(() {
          _chatMessages[mi] = msg.copyWith(contents: nextContents);
        });
        return;
      }
    }
  }

  void _markLastToolOutcome(String nextStatus) {
    final next = nextStatus.toLowerCase();
    for (var mi = _chatMessages.length - 1; mi >= 0; mi--) {
      final msg = _chatMessages[mi];
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
          _chatMessages[mi] = msg.copyWith(contents: nextContents);
        });
        return;
      }
    }
  }

  void _upsertToolMessage(ToolMessageContent tool) {
    final toolId = (tool.id ?? '').trim();
    if (toolId.isNotEmpty) {
      for (var mi = _chatMessages.length - 1; mi >= 0; mi--) {
        final msg = _chatMessages[mi];
        final contents = msg.contents;
        for (var ci = contents.length - 1; ci >= 0; ci--) {
          final c = contents[ci];
          if (c is! ToolMessageContent || (c.id ?? '').trim() != toolId) {
            continue;
          }
          final prevOutput = c.output?.text ?? '';
          final nextOutput = tool.output?.text ?? '';
          final mergedOutput = prevOutput.isNotEmpty && nextOutput.isNotEmpty
              ? (prevOutput.endsWith(nextOutput)
                    ? prevOutput
                    : '$prevOutput$nextOutput')
              : (nextOutput.isNotEmpty ? nextOutput : prevOutput);
          final nextContents = List<MessageContent>.from(contents);
          nextContents[ci] = c.copyWith(
            name: tool.name,
            input: tool.input,
            status: tool.status ?? c.status,
            output: mergedOutput.isEmpty
                ? c.output
                : ToolOutput(
                    text: mergedOutput,
                    isError: tool.output?.isError ?? c.output?.isError ?? false,
                  ),
          );
          setState(() {
            _chatMessages[mi] = msg.copyWith(contents: nextContents);
          });
          return;
        }
      }
    }

    setState(() {
      _chatMessages.add(
        ChatMessage(
          id: 'tool-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          createdAt: DateTime.now(),
          contents: [tool],
        ),
      );
    });
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
    if (_chatMessages.isNotEmpty) {
      final last = _chatMessages.last;
      if (last.role == 'warning' &&
          last.contents.isNotEmpty &&
          last.contents.first is TextMessageContent) {
        final existing = (last.contents.first as TextMessageContent).text
            .trim();
        if (existing == text) return;
      }
    }
    _enqueuePendingAppend(
      ChatMessage(
        id: 'cancelled-${DateTime.now().millisecondsSinceEpoch}',
        role: 'warning',
        createdAt: DateTime.now(),
        contents: const [TextMessageContent(text: text)],
      ),
      wsKey: 'cancelled_notice',
    );
  }

  void _handleWsPayload(Map<String, dynamic> payload) {
    final type = payload['type']?.toString();
    final fingerprint = MessageParser.eventFingerprint(payload, type);
    if (fingerprint != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final seenAt = _recentEventFingerprints[fingerprint];
      if (seenAt != null && nowMs - seenAt < 8000) return;
      _recentEventFingerprints[fingerprint] = nowMs;
      if (_recentEventFingerprints.length > 400) {
        _recentEventFingerprints.removeWhere(
          (_, value) => nowMs - value > 15000,
        );
      }
    }

    if (type == 'system' || MessageParser.isSystemPayload(payload)) return;

    // Web loads history via HTTP; WS history frames are ignored to avoid duplication.
    if (type == 'history' || type == 'history_complete') {
      return;
    }

    // Proxy status is used to gate auto-connect.
    if (type == 'proxy_status') {
      final st = payload['status']?.toString();
      if (st == 'remote_connect_failed') {
        _autoConnectDisabled = true;
        _markSessionError();
        setState(() {
          _wsConnState = WsConnectionState.failed;
        });
        if (mounted) {
          _showErrorNotice(
            key: 'ws_proxy_remote_connect_failed',
            title: 'WebSocket',
            message: 'Remote connect failed. Auto-connect is off.',
          );
        }
      }
      return;
    }

    // Web filters these from history; treat them as non-chat side-effect frames.
    if (type == 'deployment_start' || type == 'deployment_complete') {
      _handleDeploymentFrame(type!, payload);
      return;
    }

    // Best-effort de-dup (web uses uuid/message.id/id). Skip for deltas and
    // allow `assistant_message` to update/overwrite streamed content.
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
        wsKey = MessageParser.deriveRenderableWsKey(payload, wsKey, type);
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
      if (delta != null && delta.isNotEmpty) {
        if (_sessionError) {
          setState(() {
            _sessionError = false;
          });
        }
        _setSessionThinking(true);
        _thinkingClearTimer?.cancel();
        _thinkingClearTimer = Timer(
          const Duration(milliseconds: 1200),
          () => _setSessionThinking(false),
        );
        _appendAssistantDelta(delta);
      }
      return;
    }

    if (type == 'assistant_message') {
      // Final aggregated assistant message: replace last assistant if any.
      _finalizePrevToolDone();
      _setSessionThinking(false);
      final contents = MessageParser.createMessageContentsFromPayload(payload);
      if (contents.isEmpty) return;
      final canReplaceLastAssistant =
          _chatMessages.isNotEmpty &&
          _chatMessages.last.role != 'user' &&
          _chatMessages.last.contents.isNotEmpty &&
          _chatMessages.last.contents.every(
            (content) => content is TextMessageContent,
          );
      setState(() {
        if (canReplaceLastAssistant) {
          final last = _chatMessages.last;
          _chatMessages[_chatMessages.length - 1] = last.copyWith(
            contents: contents,
            createdAt: DateTime.now(),
          );
        } else {
          _chatMessages.add(
            ChatMessage(
              id: 'asst-${DateTime.now().millisecondsSinceEpoch}',
              role: 'assistant',
              createdAt: DateTime.now(),
              contents: contents,
              meta: {
                if (MessageParser.payloadTurnId(payload) != null)
                  'turnId': MessageParser.payloadTurnId(payload),
              },
            ),
          );
        }
        final next = MessageParser.dedupeRepeatedResultMessages(_chatMessages);
        _chatMessages
          ..clear()
          ..addAll(next);
      });
      _scrollToBottom();
      return;
    }

    if (type == 'assistant') {
      _finalizePrevToolDone();
      _setSessionThinking(false);
    }

    if (type == 'tool_start' ||
        type == 'tool_output_delta' ||
        type == 'tool_end') {
      final contents = MessageParser.createMessageContentsFromPayload(payload);
      final tool = contents.whereType<ToolMessageContent>().isNotEmpty
          ? contents.whereType<ToolMessageContent>().first
          : null;
      if (tool == null) return;
      _upsertToolMessage(tool);
      _scrollToBottom();
      return;
    }

    if (type == 'deployment_success') {
      _handleDeploymentFrame(type!, payload);
    }

    if (type == 'tool_result' || type == 'task_update') {
      if (type == 'task_update') {
        _finalizePrevToolDone();
      }
      if (type == 'tool_result') {
        final isErr = payload['is_error'] == true;
        _markLastToolOutcome(isErr ? 'error' : 'done');
        if (isErr) _markSessionError();
      }
      _setSessionThinking(false);
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
          ..._chatMessages,
          toolMsg,
        ]);
        _chatMessages
          ..clear()
          ..addAll(next);
      });
      _scrollToBottom();
      return;
    }

    if (type == 'result' ||
        type == 'complete' ||
        type == 'error' ||
        type == 'session_failure' ||
        type == 'cancelled') {
      // Treat these as terminal signals for the current run; don't render as a chat bubble.
      if (type == 'result') {
        _finalizePrevToolDone();
        _setSessionThinking(false);
        final contents = MessageParser.createMessageContentsFromPayload(
          payload,
        );
        if (contents.isNotEmpty) {
          final turnId = MessageParser.payloadTurnId(payload);
          final resultWsKey = turnId != null ? 'result:$turnId' : null;
          setState(() {
            if (resultWsKey != null &&
                _chatMessages.any(
                  (message) => message.meta?['wsKey'] == resultWsKey,
                )) {
              return;
            }
            final next = _appendIfDifferentFromPrevious(
              _chatMessages,
              ChatMessage(
                id: 'res-${DateTime.now().millisecondsSinceEpoch}',
                role: 'assistant',
                createdAt: DateTime.now(),
                contents: contents,
                meta: {
                  if (turnId != null) 'turnId': turnId,
                  if (resultWsKey != null) 'wsKey': resultWsKey,
                },
              ),
            );
            final deduped = MessageParser.dedupeRepeatedResultMessages(next);
            _chatMessages
              ..clear()
              ..addAll(deduped);
          });
          _scrollToBottom(force: false);
        }
      } else if (type == 'complete') {
        _finalizePrevToolDone();
        _markSessionDone();
      } else if (type == 'error' || type == 'session_failure') {
        _markLastToolOutcome('error');
        _markSessionError();
      } else if (type == 'cancelled') {
        _markLastToolOutcome('warning');
        _markSessionError();
        _appendCancelledNotice();
      } else {
        _finalizePrevToolDone();
      }
      _autoConnectDisabled = true;
      _signalOutbox();
      unawaited(_drainOutbox());
      unawaited(_maybePowerSaveCloseWebSocket());
      return;
    }

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
          meta: {
            if (MessageParser.payloadTurnId(payload) != null)
              'turnId': MessageParser.payloadTurnId(payload),
          },
        );
        setState(() {
          final next = MessageParser.dedupeRepeatedResultMessages(
            MessageParser.mergeToolResultsIntoPrevToolCalls([
              ..._chatMessages,
              toolMsg,
            ]),
          );
          _chatMessages
            ..clear()
            ..addAll(next);
        });
        _scrollToBottom();
        return;
      }
    }

    // Default: render as a standalone assistant message derived from payload.
    final contents = MessageParser.createMessageContentsFromPayload(payload);
    if (contents.isEmpty) return;
    final turnId = MessageParser.payloadTurnId(payload);
    final wsKey =
        MessageParser.deriveRenderableWsKey(payload, null, type) ??
        (turnId != null && type != null ? '$type:$turnId' : null);
    _enqueuePendingAppend(
      ChatMessage(
        id: 'ws-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        createdAt: DateTime.now(),
        contents: contents,
        meta: {
          if (turnId != null) 'turnId': turnId,
          if (wsKey != null) 'wsKey': wsKey,
        },
      ),
      wsKey: wsKey,
    );
  }

  void _handleDeploymentFrame(String type, Map<String, dynamic> payload) {
    final t = type.toLowerCase().trim();
    if (t == 'deployment_start') {
      // Some deployments can emit frames out-of-order (late start after we've
      // already received a "complete" event). Ignore those to avoid getting
      // stuck in a Deploying state.
      final doneAt = _lastDeployCompletedAt;
      if (doneAt != null && DateTime.now().difference(doneAt).inSeconds < 12) {
        return;
      }
      _finalizePrevToolDone();
      final framework = payload['message'] is Map
          ? (payload['message'] as Map)['framework']
          : null;
      setState(() {
        _isDeploying = true;
        _deployFramework = framework?.toString();
      });
      _scheduleDeployAutoClear(const Duration(minutes: 3));
      _showInfoNotice(
        key: 'deployment_start',
        title:
            AppLocalizations.of(context)?.translate('deploying_title') ??
            'Deploying',
        message: _deployFramework != null && _deployFramework!.trim().isNotEmpty
            ? (AppLocalizations.of(
                        context,
                      )?.translate('deploying_start_framework') ??
                      'Starting {framework} deploy...')
                  .replaceAll('{framework}', _deployFramework!.trim())
            : (AppLocalizations.of(context)?.translate('deploying_start') ??
                  'Starting deploy...'),
        cooldown: const Duration(seconds: 4),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (t == 'deployment_complete' || t == 'deployment_success') {
      _finalizePrevToolDone();
      String? url;
      try {
        final msg = payload['message'];
        if (msg is Map) {
          url = preferredPreviewUrlFromPayload(msg.cast<String, dynamic>());
        }
        url ??= preferredPreviewUrlFromPayload(payload);
      } catch (_) {}

      final nextUrl = url?.trim() ?? '';
      setState(() {
        _isDeploying = false;
        _deployFramework = null;
        _lastDeployCompletedAt = DateTime.now();
        if (nextUrl.isNotEmpty) {
          _previewUrl = nextUrl;
        }
        _previewKey += 1;
        _currentChatTabIndex = 0;
      });
      _deployAutoClearTimer?.cancel();

      // Best-effort refresh project to pick up the bound preview domain.
      unawaited(_refreshPreviewUrlFromApi());
      return;
    }
  }

  Future<void> _refreshPreviewUrlFromApi() async {
    try {
      final project = await _d1vaiService.getUserProjectById(widget.projectId);
      final next = (preferredPreviewUrlFromProject(project) ?? '').trim();
      if (!mounted) return;
      if (next.isEmpty) return;
      setState(() {
        _previewUrl = next;
        _previewKey += 1;
      });
    } catch (_) {}
  }

  void _appendManualRedeployMessages({String? commitHash, String? branch}) {
    final now = DateTime.now();
    final branchLabel = (branch ?? '').trim().isNotEmpty
        ? branch!.trim()
        : 'dev';
    final sha = (commitHash ?? '').trim();
    final shortSha = sha.isEmpty
        ? ''
        : sha.substring(0, sha.length >= 7 ? 7 : sha.length);

    setState(() {
      _chatMessages.addAll([
        ChatMessage(
          id: 'git-manual-commit-${now.microsecondsSinceEpoch}',
          role: 'assistant',
          createdAt: now,
          contents: [
            GitCommitMessageContent(
              projectId: widget.projectId,
              message: shortSha.isNotEmpty
                  ? 'Preview branch synced for redeploy ($shortSha)'
                  : 'Preview branch synced for redeploy',
              files: const <String>[],
            ),
          ],
        ),
        ChatMessage(
          id: 'git-manual-push-${now.microsecondsSinceEpoch + 1}',
          role: 'assistant',
          createdAt: now,
          contents: [
            GitPushMessageContent(
              projectId: widget.projectId,
              branch: branchLabel,
              success: true,
            ),
          ],
        ),
      ]);
    });
    _scrollToBottom(force: false);
  }

  @override
  Future<void> triggerPreviewRedeploy() async {
    if (_isDeploying) return;
    setState(() {
      _isDeploying = true;
      _deployFramework = null;
    });
    _scheduleDeployAutoClear(const Duration(minutes: 2));
    try {
      final res = await _d1vaiService.deployProjectPreview(widget.projectId);
      final url = (preferredPreviewUrlFromPayload(res) ?? '').trim();
      final project = await _d1vaiService.getUserProjectById(widget.projectId);
      final branch =
          project.workspaceCurrentBranch ??
          project.repositoryCurrentBranch ??
          project.repositoryDefaultBranch ??
          'dev';
      final commitHash = (res['commit_hash'] ?? res['git_commit_sha'] ?? '')
          .toString()
          .trim();
      if (!mounted) return;
      _appendManualRedeployMessages(commitHash: commitHash, branch: branch);
      if (url.isNotEmpty) {
        setState(() {
          _previewUrl = url;
          _previewKey += 1;
          _currentChatTabIndex = 0;
        });
      } else {
        setState(() {
          _previewKey += 1;
          _currentChatTabIndex = 0;
        });
      }
      _showSuccessNotice(
        key: 'preview_redeploy_triggered',
        title:
            AppLocalizations.of(context)?.translate('redeploy_started_title') ??
            'Redeploy started',
        message: url.isNotEmpty
            ? url
            : (AppLocalizations.of(
                    context,
                  )?.translate('redeploy_started_message') ??
                  'Preview deploy started'),
        actionLabel: url.isNotEmpty
            ? (AppLocalizations.of(context)?.translate('open') ?? 'Open')
            : null,
        onActionPressed: url.isNotEmpty
            ? () {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : null,
        duration: const Duration(seconds: 3),
      );
      unawaited(_refreshPreviewUrlFromApi());
      // Align with web: treat a successful trigger response as "done" for the UI button.
      // If WS deployment frames arrive later, they will update `_isDeploying` again.
      setState(() {
        _isDeploying = false;
        _deployFramework = null;
        _lastDeployCompletedAt = DateTime.now();
      });
      _deployAutoClearTimer?.cancel();
    } catch (e) {
      if (!mounted) return;
      _showErrorNotice(
        key: 'preview_redeploy_failed',
        title:
            AppLocalizations.of(context)?.translate('redeploy_failed_title') ??
            'Redeploy failed',
        message: e.toString(),
      );
      setState(() {
        _isDeploying = false;
        _deployFramework = null;
        _lastDeployCompletedAt = DateTime.now();
      });
      _deployAutoClearTimer?.cancel();
    } finally {
      // no-op
    }
  }

  Future<void> _ensureWebSocketOpen(
    String sessionId, {
    String? websocketUrlOverride,
  }) async {
    if (!mounted) return;

    final trimmedOverride = websocketUrlOverride?.trim();

    // If already connected to this session, keep it.
    if (_webSocket != null &&
        _activeWsSessionId == sessionId &&
        _webSocket!.readyState == WebSocket.open) {
      if (trimmedOverride != null && trimmedOverride.isNotEmpty) {
        _activeWsUrlOverride = trimmedOverride;
      }
      return;
    }

    final prevSessionId = _activeWsSessionId;

    // Close any previous connection without triggering reconnect loops.
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
      _wsConnState = WsConnectionState.connecting;
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
        _wsConnState = WsConnectionState.connected;
      });

      _webSocketSubscription = ws.listen(
        (data) {
          final obj = _decodeWsPayload(data);
          if (obj != null) _handleWsPayload(obj);
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _wsConnState = WsConnectionState.failed;
          });
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _wsConnState = WsConnectionState.failed;
          });
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wsConnState = WsConnectionState.failed;
      });
      _showErrorNotice(
        key: 'ws_connect_failed',
        title: 'WebSocket',
        message: 'Connect failed: $e',
        cooldown: const Duration(seconds: 12),
      );
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    if (_manualWsClose || _autoConnectDisabled) return;
    final sid = _activeWsSessionId;
    if (sid == null || sid.isEmpty) return;

    // Backend uses 4401/4404 for auth/ownership errors; don't retry those.
    final code = _webSocket?.closeCode;
    if (code == 4401 || code == 4404) {
      return;
    }

    if (_reconnectAttempts >= 3) return;
    final delayMs = (1000 * (1 << _reconnectAttempts)).clamp(1000, 30000);
    _reconnectAttempts += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _ensureWebSocketOpen(sid, websocketUrlOverride: _activeWsUrlOverride);
    });
  }

  @override
  Future<void> reconnectWebSocket() async {
    final sid = _currentSessionId ?? _activeWsSessionId;
    if (sid == null || sid.trim().isEmpty) {
      if (!mounted) return;
      _showInfoNotice(
        key: 'ws_no_active_session',
        title: 'WebSocket',
        message: 'No session to reconnect.',
      );
      return;
    }
    _autoConnectDisabled = false;
    _manualWsClose = false;
    await _ensureWebSocketOpen(sid.trim());
  }

  /// 发送普通聊天消息
  @override
  void _sendChatMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty) return;
    if (!_isModelReadyForSend()) {
      if (!mounted) return;
      _showInfoNotice(
        key: 'model_not_ready_for_send',
        title: 'Model',
        message: 'Model is still loading.',
        cooldown: const Duration(seconds: 4),
      );
      return;
    }
    // If we are busy (workspace waking / previous task running / already has queue),
    // enqueue instead of rendering immediately.
    final shouldQueue =
        _outboxItems.isNotEmpty ||
        _workspacePhase != WorkspacePhase.ready ||
        !_isTaskIdleForQueue() ||
        _outboxMode == OutboxMode.dispatching;
    if (shouldQueue) {
      _outboxEnqueue(prompt);
      return;
    }
    try {
      await _dispatchPrompt(prompt);
    } catch (e) {
      if (!mounted) return;
      if (isInsufficientBalanceError(e)) {
        await showInsufficientBalanceDialog(context);
        return;
      }
      _showErrorNotice(
        key: 'send_message_failed',
        title: 'Error',
        message: 'Send failed: $e',
      );
    }
  }

  Future<void> _dispatchPrompt(String prompt) async {
    if (!mounted) return;
    _markSessionStarted();

    final tempId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final userMessage = ChatMessage(
      id: tempId,
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: prompt)],
    );

    setState(() {
      _chatMessages.add(userMessage);
      _isChatLoading = true;
      _messageStatuses[tempId] = MessageStatus.pending;
    });

    _scrollToBottom();

    try {
      await _ensureWorkspaceReadyForSend();
      final isNew = !_canContinueCurrentSession();
      final response = await _chatService.executeSession(
        projectId: widget.projectId,
        prompt: prompt,
        sessionType: isNew ? 'new' : 'continue',
        sessionId: isNew ? null : _currentSessionId,
        model: _selectedModelId.trim().isEmpty ? null : _selectedModelId.trim(),
        engine: _selectedEngine,
        optimisticMessage: prompt,
      );
      if (!mounted) return;

      final sid = response.sessionId;
      setState(() {
        _currentSessionId = sid;
        _isChatLoading = false;
        _autoConnectDisabled = false;
        _messageStatuses[tempId] = MessageStatus.sent;
      });
      _rememberSessionConfig(
        modelId: _selectedModelId,
        engine: _selectedEngine,
      );

      _signalOutbox();
      unawaited(_drainOutbox());

      await _ensureWebSocketOpen(sid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChatLoading = false;
        _messageStatuses[tempId] = MessageStatus.failed;
      });
      _markSessionError();
      _signalOutbox();
      unawaited(_drainOutbox());
      rethrow;
    }
  }

  @override
  Future<void> _retryMessage(ChatMessage message) async {
    if (_isChatLoading) return;
    final first = message.contents.isNotEmpty ? message.contents.first : null;
    if (first is! TextMessageContent) return;
    final prompt = first.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isChatLoading = true;
      _messageStatuses[message.id] = MessageStatus.pending;
    });
    _markSessionStarted();

    try {
      await _ensureWorkspaceReadyForSend();
      final response = await _chatService.executeSession(
        projectId: widget.projectId,
        prompt: prompt,
        sessionType: 'new',
        model: _selectedModelId.trim().isEmpty ? null : _selectedModelId.trim(),
        engine: _selectedEngine,
        optimisticMessage: prompt,
      );
      if (!mounted) return;
      final sid = response.sessionId;
      setState(() {
        _currentSessionId = sid;
        _isChatLoading = false;
        _autoConnectDisabled = false;
        _messageStatuses[message.id] = MessageStatus.sent;
      });
      _rememberSessionConfig(
        modelId: _selectedModelId,
        engine: _selectedEngine,
      );
      await _ensureWebSocketOpen(sid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChatLoading = false;
        _messageStatuses[message.id] = MessageStatus.failed;
      });
      _markSessionError();
      if (isInsufficientBalanceError(e)) {
        await showInsufficientBalanceDialog(context);
        return;
      }
      _showErrorNotice(
        key: 'retry_message_failed',
        title: 'Retry',
        message: 'Retry failed: $e',
      );
    }
  }

  /// 发送第一条消息（如果会话不存在则创建会话）
  @override
  void _sendFirstMessage(String text) {
    _sendChatMessage(text);
  }

  void _scrollToBottom({bool force = true, bool animated = true}) {
    void performScroll() {
      if (!_chatScrollController.hasClients) return;
      final position = _chatScrollController.position;
      if (!force && position.pixels > 120) return;
      final now = DateTime.now();
      final last = _lastScrollToBottomAt;
      if (!force &&
          last != null &&
          now.difference(last) < const Duration(milliseconds: 140)) {
        _scrollToBottomTimer?.cancel();
        _scrollToBottomTimer = Timer(const Duration(milliseconds: 140), () {
          if (!mounted) return;
          _scrollToBottom(force: false, animated: animated);
        });
        return;
      }
      _lastScrollToBottomAt = now;
      if (animated) {
        _chatScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _chatScrollController.jumpTo(0);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      performScroll();
    });
  }
}
