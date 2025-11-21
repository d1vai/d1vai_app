import 'dart:async';
import 'dart:io';
import '../models/message.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/chat/message_list.dart';
import '../widgets/chat/message_input.dart';
import '../widgets/chat/quick_actions.dart';
import '../widgets/snackbar_helper.dart';

/// Main chat screen for AI conversations
class ChatScreen extends StatefulWidget {
  final String projectId;

  const ChatScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isTyping = false;
  String? _currentSessionId;
  String? _websocketUrl;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _createNewSession();
  }

  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    _webSocket?.close();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load chat history from server
  Future<void> _loadChatHistory() async {
    try {
      final history = await _chatService.getChatHistory(
        projectId: widget.projectId,
      );

      if (!mounted) return;

      final messages = history.map((entry) {
        final content = entry.messageType == 'text'
            ? TextMessageContent(text: entry.messageText ?? '')
            : ResultMessageContent(payload: entry.payload);

        return ChatMessage(
          id: entry.id.toString(),
          role: entry.direction,
          createdAt: entry.createdAt,
          contents: [content],
        );
      }).toList();

      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, title: 'Error', message: 'Failed to load chat history: $e');
    }
  }

  /// Create a new chat session
  Future<void> _createNewSession() async {
    try {
      final response = await _chatService.executeSession(
        projectId: widget.projectId,
        prompt: '',
        sessionType: 'new',
      );

      if (!mounted) return;

      setState(() {
        _currentSessionId = response.sessionId;
        _websocketUrl = response.websocketUrl;
      });

      _connectWebSocket();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, title: 'Error', message: 'Failed to create session: $e');
    }
  }

  /// Connect to WebSocket for real-time communication
  void _connectWebSocket() async {
    if (_websocketUrl == null) return;

    try {
      _webSocket = await _chatService.connectWebSocket(
        websocketUrl: _websocketUrl!,
      );

      if (!mounted) {
        _webSocket?.close();
        return;
      }

      _webSocketSubscription = _webSocket!.listen(
        (data) {
          final message = _chatService.parseWebSocketMessage(data);
          if (message != null) {
            setState(() {
              _messages.add(message);
              _isTyping = false;
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          if (!mounted) return;
          SnackBarHelper.showError(context, title: 'Error', message: 'WebSocket error: $error');
          setState(() {
            _isTyping = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isTyping = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, title: 'Error', message: 'Failed to connect: $e');
    }
  }

  /// Send a message
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: text)],
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
      _isLoading = false;
    });

    _scrollToBottom();

    try {
      if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
        _webSocket!.add(text);
      } else {
        // Fallback to HTTP request
        final response = await _chatService.sendMessageStream(
          projectId: widget.projectId,
          sessionId: _currentSessionId!,
          message: text,
        );

        await for (final data in response) {
          final message = _chatService.parseWebSocketMessage(
            String.fromCharCodes(data),
          );
          if (message != null) {
            setState(() {
              _messages.add(message);
              _isTyping = false;
            });
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
      });
      SnackBarHelper.showError(context, title: 'Error', message: 'Failed to send message: $e');
    }
  }

  /// Scroll to bottom of messages
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat with AI'),
            if (_currentSessionId != null)
              Text(
                'Session: ${_currentSessionId!.substring(0, 8)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.8),
                    ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadChatHistory();
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat'),
                  content: const Text('Are you sure you want to clear all messages?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick actions
          if (_messages.isEmpty)
            QuickActions(
              onSelect: _sendMessage,
            ),
          // Messages list
          Expanded(
            child: _messages.isEmpty && !_isTyping
                ? _buildEmptyState()
                : MessageList(
                    messages: _messages,
                    isTyping: _isTyping,
                    scrollController: _scrollController,
                  ),
          ),
          // Message input
          MessageInput(
            onSend: _sendMessage,
            isEnabled: !_isLoading && _currentSessionId != null,
            hintText: 'Type your message...',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy,
              size: 80.0,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24.0),
            Text(
              'Start a conversation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12.0),
            Text(
              'Ask me anything about your project,\ncode, or get help with development',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 24.0),
            FilledButton.icon(
              onPressed: _isLoading ? null : () => _sendMessage('Hello!'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Start Chat'),
            ),
          ],
        ),
      ),
    );
  }
}
