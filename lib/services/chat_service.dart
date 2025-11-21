import 'dart:typed_data';
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
  }) async {
    try {
      final payload = {
        'prompt': prompt,
        if (sessionType != 'new') 'session_type': sessionType,
        if (sessionId != null) 'session_id': sessionId,
        if (model != null) 'model': model,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
      };

      final response = await _apiClient.post(
        '/api/projects/$projectId/execute',
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
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/projects/$projectId/chat/history?limit=$limit&offset=$offset',
      );

      final List<dynamic> data = response['data'] ?? response;
      return data.map((json) => ChatHistoryEntry.fromJson(json)).toList();
    } catch (e) {
      throw ChatException('Failed to get chat history: $e');
    }
  }

  /// Get all chat sessions for a project
  Future<List<ChatSession>> getChatSessions({
    required String projectId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/projects/$projectId/sessions',
      );

      final List<dynamic> data = response['sessions'] ?? response;
      return data.map((json) => ChatSession.fromJson(json)).toList();
    } catch (e) {
      throw ChatException('Failed to get chat sessions: $e');
    }
  }

  /// Send a message to an existing session
  Future<Stream<Uint8List>> sendMessageStream({
    required String projectId,
    required String sessionId,
    required String message,
  }) async {
    try {
      final payload = {
        'message': message,
        'session_id': sessionId,
      };

      return await _apiClient.postStream(
        '/api/projects/$projectId/chat/send',
        payload,
      );
    } catch (e) {
      throw ChatException('Failed to send message: $e');
    }
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
        return ChatMessage.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to parse WebSocket message: $e');
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
