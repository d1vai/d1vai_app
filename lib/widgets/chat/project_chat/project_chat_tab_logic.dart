part of '../../project_chat/project_chat_tab.dart';

mixin _ProjectChatTabLogic on _ProjectChatTabStateBase {
  @override
  void dispose() {
    _typingResetTimer?.cancel();
    _reconnectTimer?.cancel();
    _webSocketSubscription?.cancel();
    _manualWsClose = true;
    _webSocket?.close(1000, 'dispose');
    _chatScrollController.dispose();
    super.dispose();
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
    });

    try {
      final history = await _chatService.getChatHistory(
        projectId: widget.projectId,
        limit: 50,
        messageType: 'all',
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
        _isLoadingHistory = false;
        _historyLoaded = true;
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

    if (type == 'result' ||
        type == 'complete' ||
        type == 'error' ||
        type == 'cancelled') {
      // Treat these as terminal signals for the current run; don't render as a chat bubble.
      _autoConnectDisabled = true;
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
      return;
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

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: text)],
    );

    setState(() {
      _chatMessages.add(userMessage);
      _isTyping = true;
      _isChatLoading = true;
    });

    _scrollToBottom();

    try {
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
      });

      await _ensureWebSocketOpen(sid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _isChatLoading = false;
      });
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to send message: $e',
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
