import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

/// Unified message parser for converting payload data to ChatMessage
/// Based on d1vai frontend implementation in messages.ts
class MessageParser {
  /// Normalize opcode text from various payload formats
  static String? normalizeOpcodeText(dynamic payload) {
    try {
      if (payload == null || payload is! Map<String, dynamic>) return null;

      final type = payload['type'] as String?;

      // Anthropic-style aggregated assistant message with full content array
      if (type == 'assistant_message' && payload['content'] is List) {
        final texts = (payload['content'] as List)
            .where((p) =>
                p != null &&
                p is Map<String, dynamic> &&
                p['type'] == 'text' &&
                p['text'] != null)
            .map((p) => p['text'].toString())
            .toList();
        return texts.isNotEmpty ? texts.join('\n') : null;
      }

      // Streaming delta events
      if (type == 'content_block_delta' &&
          payload['delta'] != null &&
          payload['delta'] is Map<String, dynamic> &&
          payload['delta']['type'] == 'text_delta' &&
          payload['delta']['text'] is String) {
        return payload['delta']['text'] as String;
      }

      if (type == 'message_delta' &&
          payload['delta'] != null &&
          payload['delta'] is Map<String, dynamic> &&
          payload['delta']['text'] is String) {
        return payload['delta']['text'] as String;
      }

      if (payload['message'] is String) {
        return payload['message'] as String;
      }
      if (payload['detail'] is String) {
        return payload['detail'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Error normalizing opcode text: $e');
      return null;
    }
  }

  /// Create message contents from raw payload
  static List<MessageContent> createMessageContentsFromPayload(
    dynamic rawPayload,
  ) {
    // Handle null or non-map payload (e.g., string, number, etc.)
    if (rawPayload == null) {
      return [const TextMessageContent(text: '')];
    }

    // If payload is not a Map (e.g., String, int), convert to text
    if (rawPayload is! Map<String, dynamic>) {
      return [TextMessageContent(text: rawPayload.toString())];
    }

    final payloadType = rawPayload['type'] as String?;

    try {
      // Special handling: user prompt message (no type field)
      if (payloadType == null &&
          rawPayload['prompt'] != null &&
          rawPayload['prompt'] is String) {
        return [TextMessageContent(text: rawPayload['prompt'] as String)];
      }

      switch (payloadType) {
        case 'git_commit':
          {
            final projectId = rawPayload['project_id'] as String?;
            final message = (rawPayload['message'] ?? '').toString();
            final files = rawPayload['files'] is List
                ? (rawPayload['files'] as List)
                    .map((f) => f.toString())
                    .toList()
                : null;
            return [
              GitCommitMessageContent(
                projectId: projectId,
                message: message,
                files: files,
              ),
            ];
          }

        case 'git_push':
          {
            final projectId = rawPayload['project_id'] as String?;
            final branch = (rawPayload['branch'] ?? '').toString();
            final success = rawPayload['success'] is bool
                ? rawPayload['success'] as bool
                : false;
            final errorVal = rawPayload['error'];
            final error =
                errorVal is String ? errorVal : null;
            return [
              GitPushMessageContent(
                projectId: projectId,
                branch: branch,
                success: success,
                error: error,
              ),
            ];
          }

        case 'assistant_message':
          {
            // Anthropic-style top-level content array
            final arr = rawPayload['content'] is List
                ? rawPayload['content'] as List
                : <dynamic>[];
            final contents = <MessageContent>[];

            for (final item in arr) {
              if (item is! Map<String, dynamic>) continue;
              if (item['type'] == 'text' && item['text'] is String) {
                contents.add(TextMessageContent(text: item['text'] as String));
              } else if (item['type'] == 'thinking' &&
                  item['thinking'] is String) {
                contents.add(
                    ThinkingMessageContent(text: item['thinking'] as String));
              }
            }
            return contents.isNotEmpty ? contents : [const TextMessageContent(text: '')];
          }

        case 'deployment_checking':
          {
            final rc = rawPayload['payload']?['retry_count'];
            final rcText = rc is num ? ' (retry $rc)' : '';
            final text = '⏳ Verifying deployment...$rcText';
            return [TextMessageContent(text: text)];
          }

        case 'deployment_success':
          {
            final vercel = rawPayload['payload']?['vercel_url'] as String?;
            final custom = rawPayload['payload']?['custom_url'] as String?;
            final url = custom ?? vercel ?? '';
            final text = '✅ Deployment succeeded${url.isNotEmpty ? ': $url' : ''}';
            return [TextMessageContent(text: text)];
          }

        case 'deployment_failed':
          {
            final p = rawPayload['payload'] as Map<String, dynamic>? ?? {};
            final rc = p['retry_count'] as num?;
            final mr = p['max_retries'] as num?;
            final err = p['error_logs'];
            final retryText = rc != null
                ? mr != null
                    ? ' (retry $rc/$mr)'
                    : ' (retry $rc)'
                : '';
            final errorText = err != null
                ? '\n${err.toString().substring(0, err.toString().length > 800 ? 800 : err.toString().length)}'
                : '';
            final text = '❌ Deployment failed$retryText.$errorText';
            return [TextMessageContent(text: text)];
          }

        case 'deployment_auto_fixing':
          {
            final rc = rawPayload['payload']?['retry_count'];
            final rcText = rc is num ? ' (attempt $rc)' : '';
            final text = '🛠️ Auto fixing build issues...$rcText';
            return [TextMessageContent(text: text)];
          }

        case 'deployment_max_retries_reached':
          {
            final p = rawPayload['payload'] as Map<String, dynamic>? ?? {};
            final rc = p['retry_count'] as num?;
            final lastErr = p['last_error'];
            final rcText = rc != null ? ' ($rc)' : '';
            final errorText = lastErr != null
                ? '\n${lastErr.toString().substring(0, lastErr.toString().length > 800 ? 800 : lastErr.toString().length)}'
                : '';
            final text = '❌ Max deployment retries reached$rcText.$errorText';
            return [TextMessageContent(text: text)];
          }

        case 'result':
          {
            // Result message handling
            return [ResultMessageContent(payload: rawPayload)];
          }

        case 'assistant':
          {
            // Standard assistant message handling
            final message = rawPayload['message'];
            if (message is Map<String, dynamic> &&
                message['content'] is List) {
              final contents = <MessageContent>[];

              for (final item in (message['content'] as List)) {
                if (item is! Map<String, dynamic>) continue;
                if (item['type'] == 'text' && item['text'] != null) {
                  contents.add(TextMessageContent(text: item['text'].toString()));
                } else if (item['type'] == 'thinking' &&
                    item['thinking'] != null) {
                  contents.add(
                      ThinkingMessageContent(text: item['thinking'].toString()));
                } else if (item['type'] == 'tool_use' &&
                    item['name'] != null) {
                  contents.add(ToolMessageContent(
                    name: item['name'].toString(),
                    input: item['input'],
                  ));
                }
              }

              return contents.isNotEmpty
                  ? contents
                  : [const TextMessageContent(text: '')];
            }
            break;
          }

        case 'user':
          {
            // User message handling (usually tool results)
            final message = rawPayload['message'];
            if (message is Map<String, dynamic> &&
                message['content'] is List) {
              final contents = <MessageContent>[];

              String toText(dynamic val) {
                if (val is String) return val;
                if (val is Map<String, dynamic>) {
                  if (val['text'] is String) return val['text'] as String;
                  try {
                    return json.encode(val);
                  } catch (e) {
                    return val.toString();
                  }
                }
                return val?.toString() ?? '';
              }

              for (final item in (message['content'] as List)) {
                if (item is! Map<String, dynamic>) continue;
                if (item['type'] == 'tool_result') {
                  // Tool execution result - display as code block
                  String codeStr;
                  if (item['content'] is List) {
                    codeStr = (item['content'] as List)
                        .map((p) => toText(p))
                        .join('\n');
                  } else {
                    codeStr = toText(item['content']);
                  }
                  contents.add(CodeMessageContent(code: codeStr.isNotEmpty ? codeStr : 'No result'));
                } else if (item['type'] == 'text') {
                  contents.add(TextMessageContent(text: toText(item['text'])));
                }
              }

              return contents.isNotEmpty
                  ? contents
                  : [const TextMessageContent(text: '')];
            }
            break;
          }

        case 'error':
          {
            // Error message handling
            final errorMsg = rawPayload['message'] ??
                rawPayload['error'] ??
                'Unknown error';
            return [TextMessageContent(text: '❌ $errorMsg')];
          }

        case 'complete':
          {
            // Complete message handling
            final success = rawPayload['success'];
            final code = rawPayload['code'];
            final statusText = success == true ? '✅ Task completed' : '❌ Task failed';
            final codeText = code != null ? ' (code: $code)' : '';
            return [TextMessageContent(text: '$statusText$codeText')];
          }

        case 'tool_result':
        case 'task_update':
          {
            // Tool result or task update
            final content = rawPayload['content'] ?? rawPayload['message'];
            if (content is String) {
              return [CodeMessageContent(code: content)];
            }
            break;
          }

        case 'content_block_delta':
        case 'message_delta':
          {
            // Delta message handling - for streaming updates
            final text = rawPayload['delta']?['text'];
            if (text is String) {
              return [TextMessageContent(text: text)];
            }
            break;
          }

        default:
          {
            // Try to extract text from common fields
            if (rawPayload['message'] is Map<String, dynamic>) {
              final message = rawPayload['message'] as Map<String, dynamic>;
              if (message['content'] != null) {
                final content = message['content'];
                if (content is String) {
                  return [TextMessageContent(text: content)];
                }
                if (content is List) {
                  final results = <MessageContent>[];
                  for (final item in content) {
                    if (item is Map<String, dynamic>) {
                      if (item['type'] == 'text' && item['text'] is String) {
                        results.add(
                            TextMessageContent(text: item['text'] as String));
                      } else if (item['type'] == 'thinking' &&
                          item['thinking'] is String) {
                        results.add(
                            ThinkingMessageContent(text: item['thinking'] as String));
                      }
                    }
                  }
                  if (results.isNotEmpty) return results;
                }
              }
            }

            // Try to extract text directly
            final extractedText = normalizeOpcodeText(rawPayload);
            if (extractedText != null && extractedText.trim().isNotEmpty) {
              return [TextMessageContent(text: extractedText.trim())];
            }
          }
      }
    } catch (error) {
      debugPrint('Error processing payload: $error');
    }

    // If unable to parse, display as raw data
    return [RawMessageContent(payload: rawPayload)];
  }

  /// Create message contents with backward compatibility
  static List<MessageContent> createMessageContents(
    String? messageText,
    dynamic rawPayload,
  ) {
    // Check payload type first - some special types should use payload even if message_text exists
    if (rawPayload is Map<String, dynamic>) {
      final payloadType = rawPayload['type'] as String?;

      // These types should prioritize payload over message_text
      const payloadPriorityTypes = [
        'result',
        'assistant',
        'user',
        'tool_result',
        'git_commit',
        'git_push',
        'assistant_message',
        'deployment_checking',
        'deployment_success',
        'deployment_failed',
        'deployment_auto_fixing',
        'deployment_max_retries_reached',
        'tool_result',
        'task_update',
        'content_block_delta',
        'message_delta',
      ];

      // complete doesn't have a message, it's just a status - skip it
      if (payloadType == 'complete') return [];

      if (payloadType != null && payloadPriorityTypes.contains(payloadType)) {
        return createMessageContentsFromPayload(rawPayload);
      }
    }

    // If message_text exists and is not empty, use it
    if (messageText != null && messageText.trim().isNotEmpty) {
      return [TextMessageContent(text: messageText.trim())];
    }

    // Otherwise use payload handling
    return createMessageContentsFromPayload(rawPayload);
  }

  /// Convert ChatHistoryEntry to ChatMessage
  static ChatMessage historyEntryToMessage(ChatHistoryEntry entry) {
    final p = entry.payload;
    final role = entry.direction == 'user' ? 'user' : 'assistant';

    final contents = createMessageContents(entry.messageText, p);

    return ChatMessage(
      id: entry.id.toString(),
      role: role,
      createdAt: entry.createdAt,
      contents: contents,
    );
  }

  /// Parse WebSocket message (for real-time chat)
  static ChatMessage? parseWebSocketMessage(String message) {
    try {
      final data = json.decode(message) as Map<String, dynamic>?;
      if (data == null) return null;

      // Format 1: Standard ChatMessage format with contents array
      if (data['contents'] is List) {
        final contentsJson = data['contents'] as List;
        final contents = contentsJson.map((contentJson) {
          if (contentJson is! Map<String, dynamic>) {
            return TextMessageContent(text: contentJson.toString());
          }

          final type = contentJson['type'] as String;
          switch (type) {
            case 'text':
              return TextMessageContent(
                text: contentJson['text']?.toString() ?? '',
              );
            case 'thinking':
              return ThinkingMessageContent(
                text: contentJson['text']?.toString() ?? '',
              );
            case 'tool':
              return ToolMessageContent(
                name: contentJson['name']?.toString() ?? 'unknown',
                input: contentJson['input'],
              );
            case 'result':
              return ResultMessageContent(
                payload: contentJson['result'] ??
                    contentJson['payload'] ??
                    contentJson['content'],
              );
            case 'deployment':
              return DeploymentMessageContent(
                status: contentJson['status']?.toString() ?? 'unknown',
                environment: contentJson['environment']?.toString(),
                url: contentJson['url']?.toString(),
                message: contentJson['message']?.toString(),
                deploymentId: contentJson['deploymentId']?.toString(),
              );
            case 'git_commit':
              return GitCommitMessageContent(
                projectId: contentJson['projectId']?.toString(),
                message: contentJson['message']?.toString() ?? '',
                files: (contentJson['files'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList(),
              );
            case 'git_push':
              return GitPushMessageContent(
                projectId: contentJson['projectId']?.toString(),
                branch: contentJson['branch']?.toString() ?? '',
                success: contentJson['success'] is bool
                    ? contentJson['success'] as bool
                    : false,
                error: contentJson['error']?.toString(),
              );
            case 'error':
              return ErrorMessageContent(
                message: contentJson['message']?.toString() ?? 'Unknown error',
                code: contentJson['code']?.toString(),
                details: contentJson['details'],
              );
            case 'code':
              return CodeMessageContent(
                code: contentJson['code']?.toString() ?? '',
              );
            case 'completion':
              return CompletionMessageContent(
                message: contentJson['message']?.toString() ?? '',
                success: contentJson['success'] is bool
                    ? contentJson['success'] as bool
                    : false,
                details: contentJson['details']?.toString(),
              );
            default:
              return TextMessageContent(
                text: contentJson['text']?.toString() ??
                    contentJson['content']?.toString() ??
                    json.encode(contentJson),
              );
          }
        }).toList();

        return ChatMessage(
          id: data['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          role: data['role']?.toString() ?? 'assistant',
          createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          contents: contents,
        );
      }

      // Format 2: Simple message with type
      if (data['type'] is String) {
        final messageType = data['type'] as String;
        final role = data['role']?.toString() ?? 'assistant';
        final id = data['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        final createdAt = data['createdAt']?.toString() ??
            DateTime.now().toIso8601String();

        final contents = <MessageContent>[];

        switch (messageType) {
          case 'text':
          case 'assistant':
            final text = data['text']?.toString() ??
                data['content']?.toString() ??
                '';

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
            if (data['tool'] is Map<String, dynamic>) {
              final tool = data['tool'] as Map<String, dynamic>;
              contents.add(ToolMessageContent(
                name: tool['name']?.toString() ?? 'unknown',
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
              status: data['status']?.toString() ?? 'unknown',
              environment: data['environment']?.toString(),
              url: data['url']?.toString(),
              message: data['message']?.toString(),
              deploymentId: data['deploymentId']?.toString(),
            ));
            break;

          case 'git_commit':
            contents.add(GitCommitMessageContent(
              projectId: data['projectId']?.toString(),
              message: data['message']?.toString() ?? '',
              files: (data['files'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList(),
            ));
            break;

          case 'git_push':
            contents.add(GitPushMessageContent(
              projectId: data['projectId']?.toString(),
              branch: data['branch']?.toString() ?? '',
              success: data['success'] is bool ? data['success'] as bool : false,
              error: data['error']?.toString(),
            ));
            break;

          case 'error':
            contents.add(ErrorMessageContent(
              message: data['message']?.toString() ?? 'Unknown error',
              code: data['code']?.toString(),
              details: data['details'],
            ));
            break;

          case 'thinking':
            if (data['text'] is String) {
              contents.add(ThinkingMessageContent(text: data['text'] as String));
            }
            break;

          case 'code':
            if (data['code'] is String) {
              contents.add(CodeMessageContent(code: data['code'] as String));
            }
            break;

          case 'deployment_checking':
          case 'deployment_success':
          case 'deployment_failed':
          case 'deployment_auto_fixing':
          case 'deployment_max_retries_reached':
          case 'content_block_delta':
          case 'message_delta':
            // Use payload parsing for these types
            final parsedContents = createMessageContentsFromPayload(data);
            if (parsedContents.isNotEmpty) {
              contents.addAll(parsedContents);
            }
            break;

          default:
            // Unknown type, try to extract as text
            if (data['text'] is String) {
              contents.add(TextMessageContent(text: data['text'] as String));
            } else if (data['content'] is String) {
              contents.add(TextMessageContent(text: data['content'] as String));
            } else {
              contents.add(RawMessageContent(payload: data));
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

      // Format 3: Legacy format with text/content
      if (data['text'] is String || data['content'] is String) {
        final text = data['text']?.toString() ??
            data['content']?.toString() ??
            '';
        final role = data['role']?.toString() ?? 'assistant';
        final id = data['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        final createdAt = data['createdAt']?.toString() ??
            DateTime.now().toIso8601String();

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
        id: data['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        role: data['role']?.toString() ?? 'assistant',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        contents: [RawMessageContent(payload: data)],
      );
    } catch (e, stackTrace) {
      debugPrint('Failed to parse WebSocket message: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Message content: $message');
      return null;
    }
  }
}
