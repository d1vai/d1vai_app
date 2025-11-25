
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/message.dart';
import '../core/api_client.dart';

/// Chat service for managing chat operations
class ChatService {
  final ApiClient _apiClient;

  ChatService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Execute a chat session with AI
  Future<ExecuteSessionResponse> executeSession({
    required String projectId,
    required String prompt,
    String sessionType = 'new',
    String? sessionId,
    String? model,
    String? systemPrompt,
    String? optimisticMessage,
  }) async {
    try {
      final payload = {
        'prompt': prompt,
        if (sessionType != 'new') 'session_type': sessionType,
        if (sessionId != null) 'session_id': sessionId,
        if (model != null) 'model': model,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        if (optimisticMessage != null) 'optimistic_message': optimisticMessage,
      };

      final response = await _apiClient.post(
        '/api/projects/$projectId/sessions/execute',
        payload,
      );

      return ExecuteSessionResponse.fromJson(response);
    } catch (e) {
      throw ChatException('Failed to execute session: $e');
    }
  }

  /// Get chat history for a project
  Future<List<ChatHistoryEntry>> getChatHistory({
    required String projectId,
    int limit = 50,
    String? beforeTs,
    String? direction,
    String? messageType,
    bool includePayload = true,
  }) async {
    try {
      final queryParams = <String>[
        'limit=$limit',
        'include_payload=$includePayload',
      ];

      if (beforeTs != null) {
        queryParams.add('before_ts=${Uri.encodeComponent(beforeTs)}');
      }
      if (direction != null) {
        queryParams.add('direction=$direction');
      }
      if (messageType != null) {
        queryParams.add('message_type=${Uri.encodeComponent(messageType)}');
      }

      final response = await _apiClient.get(
        '/api/projects/$projectId/history?${queryParams.join('&')}',
      );

      final List<dynamic> data = response['data'] ?? response;
      return data.map((json) => ChatHistoryEntry.fromJson(json)).toList();
    } catch (e) {
      throw ChatException('Failed to get chat history: $e');
    }
  }

  /// Get all chat sessions for a project
  /// Note: This endpoint is not available in the backend API
  /// Sessions are now ephemeral and managed by opcode
  @Deprecated('Sessions are now ephemeral and managed by opcode. Use executeSession instead.')
  Future<List<ChatSession>> getChatSessions({
    required String projectId,
  }) async {
    // Return empty list as sessions are ephemeral
    return [];
  }

  /// Send a message to an existing session
  /// Note: This endpoint is not available in the backend API
  /// Messages should be sent through the WebSocket connection instead
  @Deprecated('Messages should be sent through the WebSocket connection. Use executeSession with sessionType="continue" instead.')
  Future<Stream<Uint8List>> sendMessageStream({
    required String projectId,
    required String sessionId,
    required String message,
  }) async {
    throw ChatException(
      'Use WebSocket connection to send messages. Call executeSession with sessionType="continue" to continue an existing session.',
    );
  }

  /// Connect to WebSocket for real-time chat
  Future<WebSocket> connectWebSocket({
    required String websocketUrl,
  }) async {
    try {
      final uri = Uri.parse(websocketUrl);
      final webSocket = await WebSocket.connect(uri.toString());

      return webSocket;
    } catch (e) {
      throw ChatException('Failed to connect to WebSocket: $e');
    }
  }

  /// Parse WebSocket message
  ChatMessage? parseWebSocketMessage(String message) {
    try {
      final data = json.decode(message);
      if (data is Map<String, dynamic>) {
        // Handle different message formats from WebSocket
        // Format 1: Standard ChatMessage format
        if (data.containsKey('contents') && data['contents'] is List) {
          return ChatMessage.fromJson(data);
        }

        // Format 2: Simple text message with type
        if (data.containsKey('type')) {
          final messageType = data['type'] as String;
          final role = data['role'] as String? ?? 'assistant';
          final id = data['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
          final createdAt = data['createdAt'] as String? ?? DateTime.now().toIso8601String();

          List<MessageContent> contents = [];

          switch (messageType) {
            case 'text':
            case 'assistant':
              final text = data['text'] as String? ?? data['content'] as String? ?? '';

              // Smart detection based on content
              if (text.contains('✅') || text.contains('❌')) {
                if (text.contains('finished') || text.contains('failed')) {
                  contents.add(CompletionMessageContent(
                    message: text,
                    success: text.contains('✅'),
                    details: null,
                  ));
                } else if (text.startsWith('❌')) {
                  contents.add(ErrorMessageContent(
                    message: text,
                    code: null,
                    details: null,
                  ));
                } else {
                  contents.add(TextMessageContent(text: text));
                }
              } else {
                contents.add(TextMessageContent(text: text));
              }
              break;

            case 'tool_call':
              if (data.containsKey('tool')) {
                final tool = data['tool'] as Map<String, dynamic>;
                contents.add(ToolMessageContent(
                  name: tool['name'] as String? ?? 'unknown',
                  input: tool['input'],
                ));
              }
              break;

            case 'tool_result':
            case 'result':
              contents.add(ResultMessageContent(
                payload: data['result'] ?? data['payload'] ?? data['content'],
              ));
              break;

            case 'deployment':
              contents.add(DeploymentMessageContent(
                status: data['status'] as String? ?? 'unknown',
                environment: data['environment'] as String?,
                url: data['url'] as String?,
                message: data['message'] as String?,
                deploymentId: data['deploymentId'] as String?,
              ));
              break;

            case 'git_commit':
              contents.add(GitCommitMessageContent(
                projectId: data['projectId'] as String?,
                message: data['message'] as String? ?? '',
                files: (data['files'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList(),
              ));
              break;

            case 'git_push':
              contents.add(GitPushMessageContent(
                projectId: data['projectId'] as String?,
                branch: data['branch'] as String? ?? '',
                success: data['success'] as bool? ?? false,
                error: data['error'] as String?,
              ));
              break;

            case 'error':
              contents.add(ErrorMessageContent(
                message: data['message'] as String? ?? 'Unknown error',
                code: data['code'] as String?,
                details: data['details'],
              ));
              break;

            case 'thinking':
              if (data.containsKey('text')) {
                contents.add(ThinkingMessageContent(text: data['text'] as String));
              }
              break;

            case 'code':
              if (data.containsKey('code')) {
                contents.add(CodeMessageContent(code: data['code'] as String));
              }
              break;

            default:
              // Unknown type, try to extract as text
              if (data.containsKey('text')) {
                contents.add(TextMessageContent(text: data['text'] as String));
              } else if (data.containsKey('content')) {
                contents.add(TextMessageContent(text: data['content'] as String));
              } else {
                contents.add(TextMessageContent(text: json.encode(data)));
              }
              break;
          }

          if (contents.isNotEmpty) {
            return ChatMessage(
              id: id,
              role: role,
              createdAt: DateTime.parse(createdAt),
              contents: contents,
            );
          }
        }

        // Format 3: Legacy format or raw data
        if (data.containsKey('text') || data.containsKey('content')) {
          final text = data['text'] as String? ?? data['content'] as String? ?? '';
          final role = data['role'] as String? ?? 'assistant';
          final id = data['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
          final createdAt = data['createdAt'] as String? ?? DateTime.now().toIso8601String();

          // Smart detection for legacy format
          if (text.contains('✅') || text.contains('❌')) {
            if (text.contains('finished') || text.contains('failed')) {
              return ChatMessage(
                id: id,
                role: role,
                createdAt: DateTime.parse(createdAt),
                contents: [
                  CompletionMessageContent(
                    message: text,
                    success: text.contains('✅'),
                    details: null,
                  ),
                ],
              );
            } else if (text.startsWith('❌')) {
              return ChatMessage(
                id: id,
                role: role,
                createdAt: DateTime.parse(createdAt),
                contents: [
                  ErrorMessageContent(
                    message: text,
                    code: null,
                    details: null,
                  ),
                ],
              );
            }
          }

          return ChatMessage(
            id: id,
            role: role,
            createdAt: DateTime.parse(createdAt),
            contents: [TextMessageContent(text: text)],
          );
        }

        // Format 4: Raw payload
        return ChatMessage(
          id: data['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
          role: data['role'] as String? ?? 'assistant',
          createdAt: DateTime.parse(
            data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          ),
          contents: [RawMessageContent(payload: data)],
        );
      }
      return null;
    } catch (e) {
      debugPrint('Failed to parse WebSocket message: $e');
      debugPrint('Message content: $message');
      return null;
    }
  }

  /// Create a new chat session
  Future<ChatSession> createChatSession({
    required String projectId,
    String? model,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/projects/$projectId/sessions',
        {
          if (model != null) 'model': model,
        },
      );

      return ChatSession.fromJson(response['session'] ?? response);
    } catch (e) {
      throw ChatException('Failed to create chat session: $e');
    }
  }

  /// Delete a chat session
  Future<void> deleteChatSession({
    required String projectId,
    required String sessionId,
  }) async {
    try {
      await _apiClient.delete(
        '/api/projects/$projectId/sessions/$sessionId',
      );
    } catch (e) {
      throw ChatException('Failed to delete chat session: $e');
    }
  }
}

/// Response model for execute session
class ExecuteSessionResponse {
  final String sessionId;
  final String websocketUrl;
  final ChatSession session;

  const ExecuteSessionResponse({
    required this.sessionId,
    required this.websocketUrl,
    required this.session,
  });

  factory ExecuteSessionResponse.fromJson(Map<String, dynamic> json) {
    return ExecuteSessionResponse(
      sessionId: json['session_id'] as String,
      websocketUrl: json['websocket_url'] as String,
      session: ChatSession.fromJson(json['session'] ?? json),
    );
  }
}

/// Custom exception for chat operations
class ChatException implements Exception {
  final String message;

  const ChatException(this.message);

  @override
  String toString() => 'ChatException: $message';
}

/// WebSocket event types
class WebSocketEvent {
  static const String message = 'message';
  static const String typing = 'typing';
  static const String error = 'error';
  static const String complete = 'complete';
  static const String start = 'start';
  static const String toolCall = 'tool_call';
  static const String toolResult = 'tool_result';
}

/// Stream controller for chat events
class ChatStreamController {
  final _controller = StreamController<ChatMessage>.broadcast();
  final _typingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<ChatMessage> get messages => _controller.stream;
  Stream<bool> get typing => _typingController.stream;
  Stream<String> get errors => _errorController.stream;

  void addMessage(ChatMessage message) => _controller.add(message);
  void addTyping(bool typing) => _typingController.add(typing);
  void addError(String error) => _errorController.add(error);

  void dispose() {
    _controller.close();
    _typingController.close();
    _errorController.close();
  }
}
