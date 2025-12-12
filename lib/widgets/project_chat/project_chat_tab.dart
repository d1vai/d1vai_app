import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/env_var.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../chat/chat_bottom_sheet.dart';
import '../chat/floating_chat_button.dart';
import '../../services/d1vai_service.dart';
import '../../utils/message_parser.dart';
import '../snackbar_helper.dart';

/// 项目详情页 - Chat Tab
class ProjectChatTab extends StatefulWidget {
  final String projectId;
  final String? previewUrl;

  const ProjectChatTab({
    super.key,
    required this.projectId,
    required this.previewUrl,
  });

  @override
  ProjectChatTabState createState() => ProjectChatTabState();
}

class ProjectChatTabState extends State<ProjectChatTab>
    with AutomaticKeepAliveClientMixin {
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();

  bool _isChatLoading = false;
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  String? _currentSessionId;
  bool _historyLoaded = false;

  // WebSocket runtime (similar responsibilities to web's wsManager + useWebSocket)
  String? _activeWsSessionId;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _manualWsClose = false;
  bool _autoConnectDisabled = false;
  final Set<String> _seenWsKeys = <String>{};

  // Mobile chat bottom sheet state
  bool _showMobileChat = false;

  // Sub-tab state (Preview / Code / Env)
  int _currentChatTabIndex = 0;

  // Environment variables for Env sub-tab
  List<EnvVar> _envVars = [];
  bool _isLoadingEnvVars = false;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingEnvVars = false;
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

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

  /// 允许其他 Tab 触发首条消息并自动切换到 Preview 子标签
  void sendInitialPrompt(String text) {
    _currentChatTabIndex = 0;
    _sendFirstMessage(text);
  }

  /// 初始化聊天会话（只加载历史记录）
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

  Timer? _typingResetTimer;

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
        onError: (e) {
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
  void _sendFirstMessage(String text) async {
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

  // ==== UI ====

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMobile = _isMobile(context);

    if (isMobile) {
      return _buildChatTabMobile(context);
    } else {
      return _buildChatTabDesktop(context);
    }
  }

  Widget _buildChatTabMobile(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            // Top Bar: Tab buttons on left, action icons on right
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Left: Tab buttons
                  Expanded(
                    child: Row(
                      children: [
                        _buildChatTabButton(0, 'Preview', Icons.preview),
                        const SizedBox(width: 8),
                        _buildChatTabButton(1, 'Code', Icons.code),
                        const SizedBox(width: 8),
                        _buildChatTabButton(2, 'Env', Icons.settings),
                      ],
                    ),
                  ),
                  // Right: Action icons
                  Row(
                    children: [
                      _buildActionIconButton(
                        icon: Icons.restart_alt,
                        onPressed: _handleRefreshPreview,
                        tooltip: 'Refresh Preview',
                      ),
                      const SizedBox(width: 8),
                      _buildActionIconButton(
                        icon: Icons.open_in_new,
                        onPressed: _handleOpenInNewTab,
                        tooltip: 'Open in New Tab',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tab Content
            Expanded(
              child: IndexedStack(
                index: _currentChatTabIndex,
                children: [
                  _buildChatPreviewTabMobile(),
                  _buildChatCodeTab(),
                  _buildChatEnvTab(),
                ],
              ),
            ),
          ],
        ),
        // Floating chat button
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingChatButton(
            onPressed: () {
              setState(() {
                _showMobileChat = true;
              });
              _initializeChat();
            },
            statusLabel: _isChatLoading
                ? 'Sending...'
                : _isTyping
                ? 'Thinking...'
                : 'Ready',
            isError: false,
            isDone: false,
            isWorking: _isChatLoading,
            isThinking: _isTyping,
            isDeploying: false,
          ),
        ),
        if (_showMobileChat)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMobileChat = false;
                });
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: GestureDetector(
                  onTap: () {},
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.7,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: ChatBottomSheet(
                          messages: _chatMessages,
                          isTyping: _isTyping,
                          isLoading: _isChatLoading,
                          isLoadingHistory: _isLoadingHistory,
                          scrollController: _chatScrollController,
                          onSendMessage: _sendChatMessage,
                          onRedeploy: () {
                            SnackBarHelper.showInfo(
                              context,
                              title: 'Redeploy',
                              message: 'Triggering redeploy...',
                            );
                          },
                          onClose: () {
                            setState(() {
                              _showMobileChat = false;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatTabDesktop(BuildContext context) {
    return Column(
      children: [
        // Top Bar: Tab buttons on left, action icons on right
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Left: Tab buttons
              Expanded(
                child: Row(
                  children: [
                    _buildChatTabButton(0, 'Preview', Icons.preview),
                    const SizedBox(width: 8),
                    _buildChatTabButton(1, 'Code', Icons.code),
                    const SizedBox(width: 8),
                    _buildChatTabButton(2, 'Env', Icons.settings),
                  ],
                ),
              ),
              // Right: Action icons
              Row(
                children: [
                  _buildActionIconButton(
                    icon: Icons.restart_alt,
                    onPressed: _handleRefreshPreview,
                    tooltip: 'Refresh Preview',
                  ),
                  const SizedBox(width: 8),
                  _buildActionIconButton(
                    icon: Icons.open_in_new,
                    onPressed: _handleOpenInNewTab,
                    tooltip: 'Open in New Tab',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _currentChatTabIndex,
            children: [
              _buildChatPreviewTab(),
              _buildChatCodeTab(),
              _buildChatEnvTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatPreviewTabMobile() {
    final previewUrl = widget.previewUrl;

    if (previewUrl == null || previewUrl.isEmpty) {
      return _buildNoPreviewAvailable();
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            child: _buildWebViewContent(previewUrl),
          ),
        ),
      ],
    );
  }

  Widget _buildNoPreviewAvailable() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.preview,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text('No Preview Available', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Deploy your project to see a preview',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTabButton(int index, String label, IconData icon) {
    final isSelected = _currentChatTabIndex == index;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        setState(() {
          _currentChatTabIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatPreviewTab() {
    final previewUrl = widget.previewUrl;
    final theme = Theme.of(context);

    if (previewUrl == null || previewUrl.isEmpty) {
      return _buildNoPreviewAvailable();
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.web, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview: ${_getDeploymentLabel(previewUrl)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      previewUrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _handleRefreshPreview,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Preview',
              ),
              IconButton(
                onPressed: _handleOpenInNewTab,
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Open in Browser',
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            child: _buildWebViewContent(previewUrl),
          ),
        ),
      ],
    );
  }

  Widget _buildWebViewContent(String url) {
    return InAppWebView(
      contextMenu: ContextMenu(),
      initialUrlRequest: URLRequest(url: WebUri(url)),
    );
  }

  /// Code Tab
  Widget _buildChatCodeTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.folder, color: theme.colorScheme.secondary),
              title: const Text('src/'),
              subtitle: const Text('Source files'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                _sendFirstMessage(
                  'Can you explain the structure and contents of the src/ directory in my project?',
                );
                _currentChatTabIndex = 0;
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.folder, color: theme.colorScheme.secondary),
              title: const Text('public/'),
              subtitle: const Text('Static assets'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                _sendFirstMessage(
                  'Can you help me understand and optimize the files in the public/ directory?',
                );
                _currentChatTabIndex = 0;
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.description,
                color: theme.colorScheme.primary,
              ),
              title: const Text('README.md'),
              subtitle: const Text('Project documentation'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                _sendFirstMessage(
                  'Please review my README.md and suggest improvements to documentation and onboarding.',
                );
                _currentChatTabIndex = 0;
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.settings, color: theme.colorScheme.tertiary),
              title: const Text('package.json'),
              subtitle: const Text('Dependencies'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                _sendFirstMessage(
                  'Can you review my package.json and suggest any improvements or additional dependencies?',
                );
                _currentChatTabIndex = 0;
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Click on any file or folder to ask AI for insights, explanations, or suggestions',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Environment Variables Tab
  Widget _buildChatEnvTab() {
    final theme = Theme.of(context);

    if (_envVars.isEmpty && !_isLoadingEnvVars) {
      _loadEnvVars();
    }

    if (_isLoadingEnvVars) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_envVars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Environment Variables',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add environment variables to your project',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _envVars.length,
      itemBuilder: (context, index) {
        final envVar = _envVars[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.key,
                color: theme.colorScheme.onSecondaryContainer,
                size: 20,
              ),
            ),
            title: Text(envVar.key),
            subtitle: Text(
              (envVar.value == null || envVar.value!.isEmpty)
                  ? '(empty value)'
                  : '************',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              final question =
                  'Can you explain what the environment variable "${envVar.key}" is for and how it should be configured?';
              _sendFirstMessage(question);
              _currentChatTabIndex = 0;
            },
            onLongPress: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(envVar.key),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Value:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        (envVar.value == null || envVar.value!.isEmpty)
                            ? '(empty value)'
                            : envVar.value!,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _handleRefreshPreview() {
    SnackBarHelper.showInfo(
      context,
      title: 'Refresh Preview',
      message: 'Refreshing preview...',
    );
  }

  void _handleOpenInNewTab() {
    final previewUrl = widget.previewUrl;
    if (previewUrl == null || previewUrl.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: 'No Preview URL',
        message: 'Preview URL is not available',
      );
      return;
    }

    final uri = Uri.tryParse(previewUrl);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

String _getDeploymentLabel(String? url) {
  if (url == null || url.isEmpty) {
    return 'Configure later';
  }
  try {
    final uri = Uri.parse(url);
    return uri.host;
  } catch (e) {
    return url;
  }
}
