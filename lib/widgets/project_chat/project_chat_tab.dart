import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/env_var.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../chat/chat_bottom_sheet.dart';
import '../chat/floating_chat_button.dart';
import '../../services/d1vai_service.dart';
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
  String? _websocketUrl;
  StreamSubscription? _webSocketSubscription;

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
      final data = await service.listEnvVars(widget.projectId, showValues: false);
      if (!mounted) return;
      final vars = data.map((e) => EnvVar.fromJson(e as Map<String, dynamic>)).toList();
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
    _webSocketSubscription?.cancel();
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
    if (_currentSessionId != null) return;

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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
      });
      debugPrint('Failed to load chat history: $e');
    }
  }

  /// 将 ChatHistoryEntry 转换为 ChatMessage
  ChatMessage? _convertHistoryEntryToChatMessage(ChatHistoryEntry entry) {
    try {
      final role = entry.direction == 'user' ? 'user' : 'assistant';
      final contents = <MessageContent>[];

      if (entry.payload != null) {
        final payload = entry.payload;

        if (payload is! Map<String, dynamic>) {
          contents.add(TextMessageContent(text: payload.toString()));
          return ChatMessage(
            id: entry.id.toString(),
            role: role,
            createdAt: entry.createdAt,
            contents: contents,
          );
        }

        // Assistant messages
        if (entry.messageType == 'assistant') {
          try {
            final message = payload['message'];

            if (message is! Map<String, dynamic>) {
              contents.add(TextMessageContent(text: json.encode(payload)));
              return ChatMessage(
                id: entry.id.toString(),
                role: role,
                createdAt: entry.createdAt,
                contents: contents,
              );
            }

            final contentArray = message['content'];

            if (contentArray is List<dynamic>) {
              for (final contentItem in contentArray) {
                if (contentItem is! Map<String, dynamic>) continue;
                final contentType = contentItem['type'];
                try {
                  if (contentType == 'thinking' && contentItem['thinking'] != null) {
                    contents.add(
                      ThinkingMessageContent(
                        text: contentItem['thinking'].toString(),
                      ),
                    );
                  } else if (contentType == 'text' && contentItem['text'] != null) {
                    contents.add(
                      TextMessageContent(text: contentItem['text'].toString()),
                    );
                  } else if (contentType == 'tool_use' && contentItem['name'] != null) {
                    contents.add(
                      ToolMessageContent(
                        name: contentItem['name'].toString(),
                        input: contentItem['input'],
                      ),
                    );
                  } else if (contentType == 'tool_result' &&
                      contentItem['content'] != null) {
                    contents.add(
                      ResultMessageContent(
                        payload: contentItem['content'],
                      ),
                    );
                  }
                } catch (_) {
                  // Fallback to skipping this content item
                }
              }
            }

            if (contents.isEmpty && message['text'] != null) {
              contents.add(
                TextMessageContent(text: message['text'].toString()),
              );
            }
          } catch (_) {
            contents.add(TextMessageContent(text: json.encode(payload)));
          }
        }
        // Prompt messages
        else if (entry.messageType == 'prompt' && payload['prompt'] != null) {
          contents.add(TextMessageContent(text: payload['prompt'].toString()));
        }
        // Result messages
        else if (entry.messageType == 'result') {
          if (payload['text'] != null) {
            contents.add(TextMessageContent(text: payload['text'].toString()));
          } else if (payload['content'] != null) {
            contents.add(TextMessageContent(text: payload['content'].toString()));
          } else if (payload['result'] != null) {
            contents.add(ResultMessageContent(payload: payload['result']));
          }
        }
        // Git commit messages
        else if (entry.messageType == 'git_commit') {
          contents.add(
            GitCommitMessageContent(
              projectId: payload['projectId']?.toString(),
              message: payload['message']?.toString() ?? '',
              files: (payload['files'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList(),
            ),
          );
        }
        // Completion messages
        else if (entry.messageType == 'complete') {
          final success = payload['success'] as bool? ?? false;
          final message = payload['message']?.toString() ?? '';
          contents.add(
            CompletionMessageContent(
              message: message,
              success: success,
              details: payload['details']?.toString(),
            ),
          );
        }
        // Error messages
        else if (entry.messageType == 'error') {
          contents.add(
            ErrorMessageContent(
              message: payload['message']?.toString() ?? 'Unknown error',
              code: payload['code']?.toString(),
              details: payload['details'],
            ),
          );
        }
        // Fallback for unknown types
        else {
          final text = entry.messageText ??
              payload['text']?.toString() ??
              payload['content']?.toString() ??
              json.encode(payload);
          contents.add(TextMessageContent(text: text));
        }
      } else if (entry.messageText != null) {
        contents.add(TextMessageContent(text: entry.messageText!));
      } else {
        return null;
      }

      return ChatMessage(
        id: entry.id.toString(),
        role: role,
        createdAt: entry.createdAt,
        contents: contents,
      );
    } catch (e, stackTrace) {
      debugPrint('Failed to convert history entry ${entry.id}: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// 连接 WebSocket
  Future<void> _connectWebSocket() async {
    if (_websocketUrl == null) return;

    try {
      final webSocket = await _chatService.connectWebSocket(
        websocketUrl: _websocketUrl!,
      );

      if (!mounted) {
        await webSocket.close();
        return;
      }

      _webSocketSubscription = webSocket.listen(
        (data) {
          final message = _chatService.parseWebSocketMessage(data);
          if (message != null) {
            setState(() {
              _chatMessages.add(message);
              _isTyping = false;
            });
            _scrollToBottom();
          }
        },
        onError: (_) {
          if (!mounted) return;
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
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to connect: $e',
      );
    }
  }

  /// 发送普通聊天消息
  void _sendChatMessage(String text) async {
    if (text.trim().isEmpty || _isChatLoading) return;

    setState(() {
      _isChatLoading = true;
    });

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: text)],
    );

    setState(() {
      _chatMessages.add(userMessage);
      _isTyping = true;
      _isChatLoading = false;
    });

    _scrollToBottom();

    try {
      if (_currentSessionId == null) {
        final response = await _chatService.executeSession(
          projectId: widget.projectId,
          prompt: text,
          sessionType: 'new',
        );

        if (!mounted) return;

        setState(() {
          _currentSessionId = response.sessionId;
          _websocketUrl = response.websocketUrl;
        });

        await _connectWebSocket();
      } else {
        await _chatService.executeSession(
          projectId: widget.projectId,
          prompt: text,
          sessionType: 'continue',
          sessionId: _currentSessionId!,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
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
    if (text.trim().isEmpty || _isChatLoading) return;

    setState(() {
      _isChatLoading = true;
    });

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: text)],
    );

    setState(() {
      _chatMessages.add(userMessage);
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      if (_currentSessionId == null) {
        final response = await _chatService.executeSession(
          projectId: widget.projectId,
          prompt: text,
          sessionType: 'new',
        );

        if (!mounted) return;

        setState(() {
          _currentSessionId = response.sessionId;
          _websocketUrl = response.websocketUrl;
          _isChatLoading = false;
        });

        await _connectWebSocket();
      } else {
        setState(() {
          _isChatLoading = false;
        });

        await _chatService.executeSession(
          projectId: widget.projectId,
          prompt: text,
          sessionType: 'continue',
          sessionId: _currentSessionId!,
        );
      }
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
            // Tab Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildChatTabButton(0, 'Preview', Icons.preview),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildChatTabButton(1, 'Code', Icons.code),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildChatTabButton(2, 'Env', Icons.settings),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Action Buttons - Scrollable Icons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildActionIconButton(
                      icon: Icons.refresh,
                      onPressed: _handleRedeploy,
                      tooltip: 'Redeploy',
                    ),
                    const SizedBox(width: 12),
                    _buildActionIconButton(
                      icon: Icons.restart_alt,
                      onPressed: _handleRefreshPreview,
                      tooltip: 'Refresh Preview',
                    ),
                    const SizedBox(width: 12),
                    _buildActionIconButton(
                      icon: Icons.open_in_new,
                      onPressed: _handleOpenInNewTab,
                      tooltip: 'Open in New Tab',
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
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
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildChatTabButton(0, 'Preview', Icons.preview),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildChatTabButton(1, 'Code', Icons.code),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildChatTabButton(2, 'Env', Icons.settings),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildActionIconButton(
                  icon: Icons.refresh,
                  onPressed: _handleRedeploy,
                  tooltip: 'Redeploy',
                ),
                const SizedBox(width: 12),
                _buildActionIconButton(
                  icon: Icons.restart_alt,
                  onPressed: _handleRefreshPreview,
                  tooltip: 'Refresh Preview',
                ),
                const SizedBox(width: 12),
                _buildActionIconButton(
                  icon: Icons.open_in_new,
                  onPressed: _handleOpenInNewTab,
                  tooltip: 'Open in New Tab',
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
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
          Text(
            'No Preview Available',
            style: theme.textTheme.titleMedium,
          ),
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
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _currentChatTabIndex = index;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(vertical: 6),
        minimumSize: const Size(0, 32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          foregroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
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
              Icon(
                Icons.web,
                size: 20,
                color: theme.colorScheme.primary,
              ),
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
      initialUrlRequest: URLRequest(
        url: WebUri(url),
      ),
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
              leading: Icon(Icons.description, color: theme.colorScheme.primary),
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
                Icon(Icons.lightbulb_outline,
                    color: theme.colorScheme.onPrimaryContainer),
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
            Icon(Icons.settings,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'No Environment Variables',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add environment variables to your project',
              style:
                  TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
              child: Icon(Icons.key,
                  color: theme.colorScheme.onSecondaryContainer, size: 20),
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

  void _handleRedeploy() {
    SnackBarHelper.showInfo(
      context,
      title: 'Redeploy',
      message: 'Triggering redeploy...',
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
