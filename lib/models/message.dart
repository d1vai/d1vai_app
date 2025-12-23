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
  final String? subtype;

  const CodeMessageContent({required this.code, this.subtype}) : super('code');
}

class ToolOutput {
  final String text;
  final bool? isError;

  const ToolOutput({required this.text, this.isError});

  factory ToolOutput.fromJson(Map<String, dynamic> json) {
    return ToolOutput(
      text: (json['text'] ?? '').toString(),
      isError: json['is_error'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (isError != null) 'is_error': isError,
    };
  }
}

/// Tool execution message
class ToolMessageContent extends MessageContent {
  final String? id;
  final String name;
  final dynamic input;
  final String? status;
  final ToolOutput? output;

  const ToolMessageContent({
    this.id,
    required this.name,
    required this.input,
    this.status,
    this.output,
  })
    : super('tool');

  ToolMessageContent copyWith({
    String? id,
    String? name,
    dynamic input,
    String? status,
    ToolOutput? output,
  }) {
    return ToolMessageContent(
      id: id ?? this.id,
      name: name ?? this.name,
      input: input ?? this.input,
      status: status ?? this.status,
      output: output ?? this.output,
    );
  }
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

  const ErrorMessageContent({required this.message, this.code, this.details})
    : super('error');
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
          return TextMessageContent(text: contentJson['text'] as String);
        case 'thinking':
          return ThinkingMessageContent(text: contentJson['text'] as String);
        case 'code':
          return CodeMessageContent(
            code: contentJson['code'] as String,
            subtype: contentJson['subtype'] as String?,
          );
        case 'tool':
          return ToolMessageContent(
            id: contentJson['id']?.toString(),
            name: contentJson['name'] as String,
            input: contentJson['input'],
            status: contentJson['status']?.toString(),
            output: contentJson['output'] is Map<String, dynamic>
                ? ToolOutput.fromJson(contentJson['output'] as Map<String, dynamic>)
                : null,
          );
        case 'result':
          return ResultMessageContent(payload: contentJson['payload']);
        case 'raw':
          return RawMessageContent(payload: contentJson['payload']);
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
          return TextMessageContent(text: 'Unknown message type: $type');
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
          return {'type': 'text', 'text': content.text};
        } else if (content is ThinkingMessageContent) {
          return {'type': 'thinking', 'text': content.text};
        } else if (content is CodeMessageContent) {
          return {
            'type': 'code',
            'code': content.code,
            if (content.subtype != null) 'subtype': content.subtype,
          };
        } else if (content is ToolMessageContent) {
          return {
            'type': 'tool',
            'id': content.id,
            'name': content.name,
            'input': content.input,
            'status': content.status,
            if (content.output != null) 'output': content.output!.toJson(),
          };
        } else if (content is ResultMessageContent) {
          return {'type': 'result', 'payload': content.payload};
        } else if (content is RawMessageContent) {
          return {'type': 'raw', 'payload': content.payload};
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
    // Handle both int and String id types
    final idValue = json['id'];
    final id = idValue is int ? idValue : int.parse(idValue.toString());

    return ChatHistoryEntry(
      id: id,
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
    // 安全处理 created_at 和 updated_at 可能为 null 的情况
    final createdAtStr = json['created_at'] as String?;
    final updatedAtStr = json['updated_at'] as String?;
    final now = DateTime.now();

    return ChatSession(
      id: json['id'].toString(),
      projectId: json['project_id'] as String,
      opcodeProjectId: json['opcode_project_id'] as String,
      opcodeProjectPath: json['opcode_project_path'] as String,
      sessionId: json['session_id'] as String,
      model: json['model'] as String?,
      status: json['status'] as String?,
      createdAt: createdAtStr != null ? DateTime.parse(createdAtStr) : now,
      updatedAt: updatedAtStr != null ? DateTime.parse(updatedAtStr) : now,
      websocketUrl: json['websocket_url'] as String?,
    );
  }
}
