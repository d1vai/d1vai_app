import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../core/api_client.dart';
import '../utils/message_parser.dart';

/// Chat service for managing chat operations
class ChatService {
  final ApiClient _apiClient;

  ChatService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

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
      throw ChatException('Failed to execute session', cause: e);
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

      // Safely extract data with proper type checking
      List<dynamic> data;
      if (response is Map<String, dynamic>) {
        data =
            response['data'] as List<dynamic>? ??
            response.values.first as List<dynamic>? ??
            <dynamic>[];
      } else if (response is List<dynamic>) {
        data = response;
      } else {
        debugPrint('Unexpected response format: ${response.runtimeType}');
        data = <dynamic>[];
      }

      // Filter and validate data items before mapping
      final validEntries = <ChatHistoryEntry>[];
      for (final item in data) {
        try {
          if (item is Map<String, dynamic>) {
            final entry = ChatHistoryEntry.fromJson(item);
            validEntries.add(entry);
          } else {
            debugPrint('Skipping non-map item in history: ${item.runtimeType}');
          }
        } catch (e) {
          debugPrint('Failed to parse history entry: $e');
          debugPrint('Item: $item');
        }
      }

      return validEntries;
    } catch (e, stackTrace) {
      debugPrint('Failed to get chat history: $e');
      debugPrint('Stack trace: $stackTrace');
      throw ChatException('Failed to get chat history: $e');
    }
  }

  /// Get all chat sessions for a project
  /// Note: This endpoint is not available in the backend API
  /// Sessions are now ephemeral and managed by opcode
  @Deprecated(
    'Sessions are now ephemeral and managed by opcode. Use executeSession instead.',
  )
  Future<List<ChatSession>> getChatSessions({required String projectId}) async {
    // Return empty list as sessions are ephemeral
    return [];
  }

  /// Send a message to an existing session
  /// Note: This endpoint is not available in the backend API
  /// Messages should be sent through the WebSocket connection instead
  @Deprecated(
    'Messages should be sent through the WebSocket connection. Use executeSession with sessionType="continue" instead.',
  )
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
  Future<WebSocket> connectWebSocket({required String websocketUrl}) async {
    try {
      final uri = Uri.parse(websocketUrl);
      final webSocket = await WebSocket.connect(uri.toString());

      return webSocket;
    } catch (e) {
      throw ChatException('Failed to connect to WebSocket: $e');
    }
  }

  /// Return the latest running session for a project (if any).
  ///
  /// Backend returns `null` when no active running session exists or when the
  /// latest persisted message is terminal (complete/result/error/cancelled).
  Future<Map<String, dynamic>?> getActiveProjectSession({
    required String projectId,
  }) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/api/projects/$projectId/sessions/active',
        retries: 0,
      );
      if (response == null) return null;
      if (response is Map<String, dynamic>) return response;
      if (response is Map) {
        return response.map((k, v) => MapEntry(k.toString(), v));
      }
      debugPrint(
        'Unexpected active session response type: ${response.runtimeType}',
      );
      return null;
    } catch (e) {
      debugPrint('Failed to get active project session: $e');
      return null;
    }
  }

  /// Build WebSocket URL for a project session (backend expects `?token=...` query param).
  ///
  /// Web uses `/api/projects/ws/session/{session_id}` with `ws/wss` derived from API base URL.
  Future<String> buildProjectSessionWebSocketUrl({
    required String sessionId,
    String? websocketUrlOverride,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.trim().isEmpty) {
        throw ChatException('Not logged in or token expired');
      }
      final trimmedOverride = websocketUrlOverride?.trim();
      if (trimmedOverride != null && trimmedOverride.isNotEmpty) {
        final overrideUri = Uri.parse(trimmedOverride);
        Uri resolved;
        if (overrideUri.scheme.isEmpty) {
          // Allow path-only overrides (e.g. "/api/projects/ws/session/<sid>").
          final base = Uri.parse(ApiClient.baseUrl);
          final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
          resolved = base.replace(
            scheme: wsScheme,
            path: overrideUri.path,
            queryParameters: overrideUri.queryParameters,
          );
        } else if (overrideUri.scheme == 'http' ||
            overrideUri.scheme == 'https') {
          resolved = overrideUri.replace(
            scheme: overrideUri.scheme == 'https' ? 'wss' : 'ws',
          );
        } else {
          resolved = overrideUri;
        }

        final hasToken = resolved.queryParameters.containsKey('token');
        final qp = Map<String, String>.from(resolved.queryParameters);
        if (!hasToken) qp['token'] = token.trim();
        return resolved.replace(queryParameters: qp).toString();
      }

      final base = Uri.parse(ApiClient.baseUrl);
      final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
      final wsUri = base.replace(
        scheme: wsScheme,
        path: '/api/projects/ws/session/$sessionId',
        queryParameters: {'token': token},
      );
      return wsUri.toString();
    } catch (e) {
      throw ChatException('Failed to build WebSocket URL: $e');
    }
  }

  /// Parse WebSocket message using unified MessageParser
  ChatMessage? parseWebSocketMessage(String message) {
    return MessageParser.parseWebSocketMessage(message);
  }

  /// Create a new chat session
  Future<ChatSession> createChatSession({
    required String projectId,
    String? model,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/projects/$projectId/sessions',
        {if (model != null) 'model': model},
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
      await _apiClient.delete('/api/projects/$projectId/sessions/$sessionId');
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
    // Handle both direct data and nested response structures
    final sessionId =
        json['session_id'] as String? ??
        (json['session']?['session_id'] as String?);
    final websocketUrl =
        json['websocket_url'] as String? ??
        (json['session']?['websocket_url'] as String?);

    if (sessionId == null) {
      throw ChatException('Missing session_id in response');
    }
    if (websocketUrl == null) {
      throw ChatException('Missing websocket_url in response');
    }

    return ExecuteSessionResponse(
      sessionId: sessionId,
      websocketUrl: websocketUrl,
      session: ChatSession.fromJson(json['session'] ?? json),
    );
  }
}

/// Custom exception for chat operations
class ChatException implements Exception {
  final String message;
  final Object? cause;

  const ChatException(this.message, {this.cause});

  @override
  String toString() => cause == null
      ? 'ChatException: $message'
      : 'ChatException: $message ($cause)';
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
