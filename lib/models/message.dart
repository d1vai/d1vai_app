/// Message content types for rich chat rendering
abstract class MessageContent {
  final String type;

  const MessageContent(this.type);
}

/// Text message content
class TextMessageContent extends MessageContent {
  final String text;

  const TextMessageContent({required this.text}) : super('text');
}

/// Thinking/Reasoning message
class ThinkingMessageContent extends MessageContent {
  final String text;

  const ThinkingMessageContent({required this.text}) : super('thinking');
}

/// Code message with syntax highlighting
class CodeMessageContent extends MessageContent {
  final String code;

  const CodeMessageContent({required this.code}) : super('code');
}

/// Tool execution message
class ToolMessageContent extends MessageContent {
  final String name;
  final dynamic input;

  const ToolMessageContent({
    required this.name,
    required this.input,
  }) : super('tool');
}

/// Tool result message
class ResultMessageContent extends MessageContent {
  final dynamic payload;

  const ResultMessageContent({required this.payload}) : super('result');
}

/// Raw payload message
class RawMessageContent extends MessageContent {
  final dynamic payload;

  const RawMessageContent({required this.payload}) : super('raw');
}

/// Git commit message
class GitCommitMessageContent extends MessageContent {
  final String? projectId;
  final String message;
  final List<String>? files;

  const GitCommitMessageContent({
    this.projectId,
    required this.message,
    this.files,
  }) : super('git_commit');
}

/// Git push message
class GitPushMessageContent extends MessageContent {
  final String? projectId;
  final String branch;
  final bool success;
  final String? error;

  const GitPushMessageContent({
    this.projectId,
    required this.branch,
    required this.success,
    this.error,
  }) : super('git_push');
}

/// Deployment status message
class DeploymentMessageContent extends MessageContent {
  final String status;
  final String? environment;
  final String? url;
  final String? message;
  final String? deploymentId;

  const DeploymentMessageContent({
    required this.status,
    this.environment,
    this.url,
    this.message,
    this.deploymentId,
  }) : super('deployment');
}

/// Error message
class ErrorMessageContent extends MessageContent {
  final String message;
  final String? code;
  final dynamic details;

  const ErrorMessageContent({
    required this.message,
    this.code,
    this.details,
  }) : super('error');
}

/// Completion/success message (for finished tasks, deployments, etc.)
class CompletionMessageContent extends MessageContent {
  final String message;
  final bool success;
  final String? details;

  const CompletionMessageContent({
    required this.message,
    required this.success,
    this.details,
  }) : super('completion');
}

/// Complete chat message model
class ChatMessage {
  final String id;
  final String role;
  final DateTime createdAt;
  final List<MessageContent> contents;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    required this.contents,
  });

  /// Create from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final contentsJson = json['contents'] as List<dynamic>;
    final contents = contentsJson.map((contentJson) {
      final type = contentJson['type'] as String;
      switch (type) {
        case 'text':
          return TextMessageContent(
            text: contentJson['text'] as String,
          );
        case 'thinking':
          return ThinkingMessageContent(
            text: contentJson['text'] as String,
          );
        case 'code':
          return CodeMessageContent(
            code: contentJson['code'] as String,
          );
        case 'tool':
          return ToolMessageContent(
            name: contentJson['name'] as String,
            input: contentJson['input'],
          );
        case 'result':
          return ResultMessageContent(
            payload: contentJson['payload'],
          );
        case 'raw':
          return RawMessageContent(
            payload: contentJson['payload'],
          );
        case 'git_commit':
          return GitCommitMessageContent(
            projectId: contentJson['projectId'] as String?,
            message: contentJson['message'] as String,
            files: (contentJson['files'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList(),
          );
        case 'git_push':
          return GitPushMessageContent(
            projectId: contentJson['projectId'] as String?,
            branch: contentJson['branch'] as String,
            success: contentJson['success'] as bool,
            error: contentJson['error'] as String?,
          );
        case 'deployment':
          return DeploymentMessageContent(
            status: contentJson['status'] as String,
            environment: contentJson['environment'] as String?,
            url: contentJson['url'] as String?,
            message: contentJson['message'] as String?,
            deploymentId: contentJson['deploymentId'] as String?,
          );
        case 'error':
          return ErrorMessageContent(
            message: contentJson['message'] as String,
            code: contentJson['code'] as String?,
            details: contentJson['details'],
          );
        case 'completion':
          return CompletionMessageContent(
            message: contentJson['message'] as String,
            success: contentJson['success'] as bool? ?? false,
            details: contentJson['details'] as String?,
          );
        default:
          return TextMessageContent(
            text: 'Unknown message type: $type',
          );
      }
    }).toList();

    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      contents: contents,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'contents': contents.map((content) {
        if (content is TextMessageContent) {
          return {
            'type': 'text',
            'text': content.text,
          };
        } else if (content is ThinkingMessageContent) {
          return {
            'type': 'thinking',
            'text': content.text,
          };
        } else if (content is CodeMessageContent) {
          return {
            'type': 'code',
            'code': content.code,
          };
        } else if (content is ToolMessageContent) {
          return {
            'type': 'tool',
            'name': content.name,
            'input': content.input,
          };
        } else if (content is ResultMessageContent) {
          return {
            'type': 'result',
            'payload': content.payload,
          };
        } else if (content is RawMessageContent) {
          return {
            'type': 'raw',
            'payload': content.payload,
          };
        } else if (content is GitCommitMessageContent) {
          return {
            'type': 'git_commit',
            'projectId': content.projectId,
            'message': content.message,
            'files': content.files,
          };
        } else if (content is GitPushMessageContent) {
          return {
            'type': 'git_push',
            'projectId': content.projectId,
            'branch': content.branch,
            'success': content.success,
            'error': content.error,
          };
        } else if (content is DeploymentMessageContent) {
          return {
            'type': 'deployment',
            'status': content.status,
            'environment': content.environment,
            'url': content.url,
            'message': content.message,
            'deploymentId': content.deploymentId,
          };
        } else if (content is ErrorMessageContent) {
          return {
            'type': 'error',
            'message': content.message,
            'code': content.code,
            'details': content.details,
          };
        } else if (content is CompletionMessageContent) {
          return {
            'type': 'completion',
            'message': content.message,
            'success': content.success,
            'details': content.details,
          };
        }
        return {};
      }).toList(),
    };
  }

  /// Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? role,
    DateTime? createdAt,
    List<MessageContent>? contents,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      contents: contents ?? this.contents,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, role: $role, contents: ${contents.length})';
  }
}

/// Chat history entry for persistence
class ChatHistoryEntry {
  final int id;
  final String projectId;
  final String direction;
  final String? messageType;
  final String? messageText;
  final dynamic payload;
  final DateTime createdAt;

  const ChatHistoryEntry({
    required this.id,
    required this.projectId,
    required this.direction,
    this.messageType,
    this.messageText,
    required this.payload,
    required this.createdAt,
  });

  factory ChatHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ChatHistoryEntry(
      id: json['id'] as int,
      projectId: json['project_id'] as String,
      direction: json['direction'] as String,
      messageType: json['message_type'] as String?,
      messageText: json['message_text'] as String?,
      payload: json['payload'],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Chat session model
class ChatSession {
  final String id;
  final String projectId;
  final String opcodeProjectId;
  final String opcodeProjectPath;
  final String sessionId;
  final String? model;
  final String? status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? websocketUrl;

  const ChatSession({
    required this.id,
    required this.projectId,
    required this.opcodeProjectId,
    required this.opcodeProjectPath,
    required this.sessionId,
    this.model,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    this.websocketUrl,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'].toString(),
      projectId: json['project_id'] as String,
      opcodeProjectId: json['opcode_project_id'] as String,
      opcodeProjectPath: json['opcode_project_path'] as String,
      sessionId: json['session_id'] as String,
      model: json['model'] as String?,
      status: json['status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      websocketUrl: json['websocket_url'] as String?,
    );
  }
}
