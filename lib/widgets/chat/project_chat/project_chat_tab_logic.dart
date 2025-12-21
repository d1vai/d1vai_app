part of '../../project_chat/project_chat_tab.dart';

mixin _ProjectChatTabLogic on _ProjectChatTabStateBase {
  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapWorkspace());
  }

  @override
  void dispose() {
    _typingResetTimer?.cancel();
    _reconnectTimer?.cancel();
    _workspacePollTimer?.cancel();
    _webSocketSubscription?.cancel();
    _manualWsClose = true;
    _webSocket?.close(1000, 'dispose');
    _chatScrollController.dispose();
    super.dispose();
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
      _workspacePollErrorStreak = 0;
      _scheduleWorkspacePoll(phase);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspacePhase = WorkspacePhase.error;
        _workspaceError = e.toString();
      });
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
      _workspacePollErrorStreak = 0;
      _scheduleWorkspacePoll(WorkspacePhase.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspacePhase = WorkspacePhase.error;
        _workspaceError = e.toString();
      });
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
    await _maybeWarmupWorkspace();
    if (_workspacePhase != WorkspacePhase.ready) {
      throw Exception(_workspaceError ?? 'Workspace is not ready');
    }
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

  @override
  Future<void> _loadEnvVars() async {
    if (_isLoadingEnvVars) return;
    setState(() {
      _isLoadingEnvVars = true;
    });

    try {
      final service = D1vaiService();
      final data = await service.listEnvVars(
        widget.projectId,
        showValues: false,
      );
      if (!mounted) return;
      final vars = data
          .map((e) => EnvVar.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _envVars = List<EnvVar>.from(vars);
        _isLoadingEnvVars = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingEnvVars = false;
      });
    }
  }

  /// 加载聊天历史
  Future<void> _loadChatHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _isLoadingMoreHistory = false;
      _hasMoreHistory = true;
      _oldestMessageAt = null;
    });

    try {
      final history = await _chatService.getChatHistory(
        projectId: widget.projectId,
        limit: 30,
        messageType: 'all',
        includePayload: true,
      );

      if (!mounted) return;

      history.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final messages = <ChatMessage>[];
      for (final entry in history) {
        final message = _convertHistoryEntryToChatMessage(entry);
        if (message != null) {
          messages.add(message);
        }
      }

      setState(() {
        _chatMessages
          ..clear()
          ..addAll(messages);
        _messageStatuses.clear();
        _isLoadingHistory = false;
        _historyLoaded = true;
        _hasMoreHistory = history.length >= 30;
        _oldestMessageAt =
            history.isNotEmpty ? history.first.createdAt : null;
      });

      // Match web behavior: optionally reconnect to a recent session to stream live output.
      await _restoreSessionFromHistory(history);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
      });
      debugPrint('Failed to load chat history: $e');
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

    final controller = _chatScrollController;
    final hadClients = controller.hasClients;
    final beforeOffset = hadClients ? controller.offset : 0.0;
    final beforeMaxExtent =
        hadClients ? controller.position.maxScrollExtent : 0.0;

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
        final m = _convertHistoryEntryToChatMessage(entry);
        if (m == null) continue;
        final allEmptyText = m.contents.isNotEmpty &&
            m.contents.every(
              (c) => c is TextMessageContent && c.text.trim().isEmpty,
            );
        if (!allEmptyText) older.add(m);
      }

      final existingIds = _chatMessages.map((m) => m.id).toSet();
      final deduped =
          older.where((m) => !existingIds.contains(m.id)).toList();

      setState(() {
        _chatMessages.insertAll(0, deduped);
        _isLoadingMoreHistory = false;
        _hasMoreHistory = history.length >= limit;
        _oldestMessageAt =
            history.isNotEmpty ? history.first.createdAt : _oldestMessageAt;
      });

      // Preserve viewport position after prepending.
      if (hadClients && controller.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!controller.hasClients) return;
          final afterMax = controller.position.maxScrollExtent;
          final delta = afterMax - beforeMaxExtent;
          if (delta > 0) {
            controller.jumpTo(beforeOffset + delta);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreHistory = false;
        _hasMoreHistory = false;
      });
    }
  }

  /// 将 ChatHistoryEntry 转换为 ChatMessage（使用统一的 MessageParser）
  ChatMessage? _convertHistoryEntryToChatMessage(ChatHistoryEntry entry) {
    try {
      return MessageParser.historyEntryToMessage(entry);
    } catch (e, stackTrace) {
      debugPrint('Failed to convert history entry ${entry.id}: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  void _scheduleTypingReset() {
    _typingResetTimer?.cancel();
    _typingResetTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
      });
    });
  }

  Future<void> _closeWebSocket({bool manual = true}) async {
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

  void _appendAssistantDelta(String delta) {
    if (delta.isEmpty) return;
    setState(() {
      if (_chatMessages.isNotEmpty) {
        final last = _chatMessages.last;
        if (last.role != 'user' &&
            last.contents.isNotEmpty &&
            last.contents.first is TextMessageContent) {
          final first = last.contents.first as TextMessageContent;
          final updated = last.copyWith(
            contents: [
              TextMessageContent(text: '${first.text}$delta'),
              ...last.contents.skip(1),
            ],
          );
          _chatMessages[_chatMessages.length - 1] = updated;
          return;
        }
      }

      _chatMessages.add(
        ChatMessage(
          id: 'asst-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          createdAt: DateTime.now(),
          contents: [TextMessageContent(text: delta)],
        ),
      );
    });
    _scrollToBottom();
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

  void _handleWsPayload(Map<String, dynamic> payload) {
    final type = payload['type']?.toString();

    // Web loads history via HTTP; WS history frames are ignored to avoid duplication.
    if (type == 'history' || type == 'history_complete') {
      return;
    }

    // Proxy status is used to gate auto-connect.
    if (type == 'proxy_status') {
      final st = payload['status']?.toString();
      if (st == 'remote_connect_failed') {
        _autoConnectDisabled = true;
        if (mounted) {
          SnackBarHelper.showError(
            context,
            title: 'WebSocket',
            message: 'Remote connection failed. Auto-connect disabled.',
          );
        }
      }
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
        if (wsKey != null) {
          if (_seenWsKeys.contains(wsKey)) return;
          _seenWsKeys.add(wsKey);
          if (_seenWsKeys.length > 500) _seenWsKeys.clear();
        }
      }
    } catch (_) {}

    // Any non-history frame is live activity.
    if (mounted) {
      setState(() {
        _isTyping = true;
      });
    }
    _scheduleTypingReset();

    if (type == 'content_block_delta' || type == 'message_delta') {
      final delta = MessageParser.normalizeOpcodeText(payload);
      if (delta != null && delta.isNotEmpty) {
        _appendAssistantDelta(delta);
      }
      return;
    }

    if (type == 'assistant_message') {
      // Final aggregated assistant message: replace last assistant if any.
      _finalizePrevToolDone();
      final contents = MessageParser.createMessageContentsFromPayload(payload);
      if (contents.isEmpty) return;
      setState(() {
        if (_chatMessages.isNotEmpty && _chatMessages.last.role != 'user') {
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
            ),
          );
        }
      });
      _scrollToBottom();
      return;
    }

    if (type == 'assistant') {
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
      setState(() {
        _chatMessages.add(
          ChatMessage(
            id: 'tool-${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            createdAt: DateTime.now(),
            contents: contents,
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    if (type == 'result' ||
        type == 'complete' ||
        type == 'error' ||
        type == 'cancelled') {
      // Treat these as terminal signals for the current run; don't render as a chat bubble.
      if (type == 'error') {
        _markLastToolOutcome('error');
      } else if (type == 'cancelled') {
        _markLastToolOutcome('warning');
      } else {
        _finalizePrevToolDone();
      }
      _autoConnectDisabled = true;
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
      return;
    }

    if (type == 'user' && _userPayloadHasToolResult(payload)) {
      _markLastToolOutcome(
        _userPayloadIsToolResultError(payload) ? 'error' : 'done',
      );
    }

    // Default: render as a standalone assistant message derived from payload.
    final contents = MessageParser.createMessageContentsFromPayload(payload);
    if (contents.isEmpty) return;
    setState(() {
      _chatMessages.add(
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

  Future<void> _ensureWebSocketOpen(String sessionId) async {
    if (!mounted) return;

    // If already connected to this session, keep it.
    if (_webSocket != null &&
        _activeWsSessionId == sessionId &&
        _webSocket!.readyState == WebSocket.open) {
      return;
    }

    // Close any previous connection without triggering reconnect loops.
    if (_webSocket != null) {
      await _closeWebSocket(manual: true);
    }

    _reconnectTimer?.cancel();
    _manualWsClose = false;
    _activeWsSessionId = sessionId;

    try {
      await _webSocketSubscription?.cancel();
    } catch (_) {}
    _webSocketSubscription = null;

    try {
      final wsUrl = await _chatService.buildProjectSessionWebSocketUrl(
        sessionId: sessionId,
      );
      final ws = await WebSocket.connect(wsUrl);
      if (!mounted) {
        await ws.close(1000, 'unmounted');
        return;
      }
      _webSocket = ws;
      _reconnectAttempts = 0;

      _webSocketSubscription = ws.listen(
        (data) {
          final obj = _decodeWsPayload(data);
          if (obj != null) _handleWsPayload(obj);
        },
        onError: (_) {
          if (!mounted) return;
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'WebSocket',
        message: 'Failed to connect: $e',
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
      _ensureWebSocketOpen(sid);
    });
  }

  Future<void> _restoreSessionFromHistory(
    List<ChatHistoryEntry> history,
  ) async {
    if (!mounted) return;

    // If the latest history entry is a completion, don't auto-connect on enter.
    ChatHistoryEntry? latest;
    for (final e in history) {
      if (latest == null || e.createdAt.isAfter(latest.createdAt)) {
        latest = e;
      }
    }
    final latestType = (latest?.payload is Map<String, dynamic>)
        ? (latest!.payload as Map<String, dynamic>)['type']?.toString()
        : null;
    if (latestType == 'complete') {
      _autoConnectDisabled = true;
      return;
    }

    // Find newest entry with a usable session_id (same heuristic as web).
    ChatHistoryEntry? newestWithSession;
    for (final e in history) {
      if (e.payload is! Map<String, dynamic>) continue;
      final sid = (e.payload as Map<String, dynamic>)['session_id'];
      if (sid is! String || sid.isEmpty) continue;
      if (newestWithSession == null ||
          e.createdAt.isAfter(newestWithSession.createdAt)) {
        newestWithSession = e;
      }
    }
    if (newestWithSession == null) return;

    final sid =
        (newestWithSession.payload as Map<String, dynamic>)['session_id']
            as String;
    setState(() {
      _currentSessionId = sid;
    });

    // Only auto-connect for a recent session to avoid reviving stale sessions.
    final now = DateTime.now();
    if (now.difference(newestWithSession.createdAt).inMinutes <= 10 &&
        !_autoConnectDisabled) {
      await _ensureWebSocketOpen(sid);
    }
  }

  /// 发送普通聊天消息
  @override
  void _sendChatMessage(String text) async {
    if (text.trim().isEmpty || _isChatLoading) return;

    final tempId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final userMessage = ChatMessage(
      id: tempId,
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: text)],
    );

    setState(() {
      _chatMessages.add(userMessage);
      _isTyping = true;
      _isChatLoading = true;
      _messageStatuses[tempId] = MessageStatus.pending;
    });

    _scrollToBottom();

    try {
      await _ensureWorkspaceReadyForSend();
      final isNew = _currentSessionId == null;
      final response = await _chatService.executeSession(
        projectId: widget.projectId,
        prompt: text,
        sessionType: isNew ? 'new' : 'continue',
        sessionId: isNew ? null : _currentSessionId,
        optimisticMessage: text,
      );
      if (!mounted) return;

      final sid = response.sessionId;
      setState(() {
        _currentSessionId = sid;
        _isChatLoading = false;
        // This is an active run now; allow reconnect if needed.
        _autoConnectDisabled = false;
        _messageStatuses[tempId] = MessageStatus.sent;
      });

      await _ensureWebSocketOpen(sid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _isChatLoading = false;
        _messageStatuses[tempId] = MessageStatus.failed;
      });
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to send message: $e',
      );
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
      _isTyping = true;
      _messageStatuses[message.id] = MessageStatus.pending;
    });

    try {
      await _ensureWorkspaceReadyForSend();
      final response = await _chatService.executeSession(
        projectId: widget.projectId,
        prompt: prompt,
        sessionType: 'new',
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
      await _ensureWebSocketOpen(sid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChatLoading = false;
        _isTyping = false;
        _messageStatuses[message.id] = MessageStatus.failed;
      });
      SnackBarHelper.showError(
        context,
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
