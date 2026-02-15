import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

/// Unified message parser for converting payload data to ChatMessage
/// Based on d1vai frontend implementation in messages.ts
class MessageParser {
  static dynamic _coerceJsonPayload(dynamic raw) {
    if (raw is! String) return raw;
    final s = raw.trim();
    if (s.isEmpty) return raw;
    if (!(s.startsWith('{') || s.startsWith('['))) return raw;
    try {
      return jsonDecode(s);
    } catch (_) {
      return raw;
    }
  }

  static String? _normalizeRole(String? v) {
    if (v == null) return null;
    final s = v.toLowerCase().trim();
    if (s.isEmpty) return null;
    if (s == 'user') return 'user';
    if (s == 'system') return 'system';
    if (s == 'assistant' ||
        s == 'ai' ||
        s == 'assistant_message' ||
        s == 'bot') {
      return 'assistant';
    }
    if (s == 'warning') return 'warning';
    if (s == 'error') return 'error';
    return null;
  }

  static bool _isNonRenderableType(String? t) {
    if (t == null) return false;
    final s = t.toLowerCase().trim();
    if (s.isEmpty) return false;
    // Align with web: certain frames are terminal/meta signals and should not
    // be rendered as chat bubbles in history or live stream.
    const skip = <String>{
      'complete',
      'system',
      'history',
      'history_complete',
      'proxy_status',
      // Web filters these from history list; handled via side effects.
      'deployment_start',
      'deployment_complete',
    };
    return skip.contains(s);
  }

  static bool isSystemPayload(dynamic rawPayload) {
    rawPayload = _coerceJsonPayload(rawPayload);
    if (rawPayload is! Map<String, dynamic>) return false;

    final payloadType = rawPayload['type']?.toString();
    if (_normalizeRole(payloadType) == 'system') return true;

    final payloadRole = rawPayload['role']?.toString();
    if (_normalizeRole(payloadRole) == 'system') return true;

    final message = rawPayload['message'];
    if (message is Map) {
      final msgRole = message['role']?.toString();
      if (_normalizeRole(msgRole) == 'system') return true;
    }

    return false;
  }

  /// Normalize opcode text from various payload formats
  static String? normalizeOpcodeText(dynamic payload) {
    try {
      if (payload == null || payload is! Map<String, dynamic>) return null;

      final type = payload['type'] as String?;

      // Anthropic-style aggregated assistant message with full content array
      if (type == 'assistant_message' && payload['content'] is List) {
        final texts = (payload['content'] as List)
            .where(
              (p) =>
                  p != null &&
                  p is Map<String, dynamic> &&
                  p['type'] == 'text' &&
                  p['text'] != null,
            )
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
    rawPayload = _coerceJsonPayload(rawPayload);
    // Handle null or non-map payload (e.g., string, number, etc.)
    if (rawPayload == null) {
      return [const TextMessageContent(text: '')];
    }

    // If payload is not a Map (e.g., String, int), convert to text
    if (rawPayload is! Map<String, dynamic>) {
      return [TextMessageContent(text: rawPayload.toString())];
    }

    if (isSystemPayload(rawPayload)) return [];

    final payloadType = rawPayload['type'] as String?;

    try {
      // Some servers wrap chat blocks in `payload.message` with a separate
      // `payload.type` like `session_message`. Mirror web behavior by parsing
      // based on message.role/content even when payload.type is unknown.
      final wrapped = rawPayload['message'];
      if (wrapped is Map<String, dynamic> && wrapped['content'] is List) {
        final wrappedRole = _normalizeRole(wrapped['role']?.toString());
        if (wrappedRole == 'assistant') {
          final blocks = wrapped['content'] as List;
          final contents = <MessageContent>[];
          final toolUseTotal = blocks
              .where(
                (it) => it is Map<String, dynamic> && it['type'] == 'tool_use',
              )
              .length;
          var toolUseSeen = 0;

          for (final item in blocks) {
            if (item is! Map<String, dynamic>) continue;
            if (item['type'] == 'text' && item['text'] != null) {
              contents.add(TextMessageContent(text: item['text'].toString()));
            } else if (item['type'] == 'thinking' && item['thinking'] != null) {
              contents.add(
                ThinkingMessageContent(text: item['thinking'].toString()),
              );
            } else if (item['type'] == 'tool_use' && item['name'] != null) {
              toolUseSeen += 1;
              contents.add(
                ToolMessageContent(
                  id: item['id']?.toString(),
                  name: item['name'].toString(),
                  input: item['input'],
                  status: toolUseSeen >= toolUseTotal ? 'processing' : 'done',
                ),
              );
            }
          }

          if (contents.isNotEmpty) return contents;
        }

        if (wrappedRole == 'user') {
          final blocks = wrapped['content'] as List;
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

          for (final item in blocks) {
            if (item is! Map<String, dynamic>) continue;
            if (item['type'] == 'tool_result') {
              String codeStr;
              if (item['content'] is List) {
                codeStr = (item['content'] as List)
                    .map((p) => toText(p))
                    .join('\n');
              } else {
                codeStr = toText(item['content']);
              }
              final isErr = item['is_error'] == true;
              final toolUseId = item['tool_use_id']?.toString().trim();
              final baseSubtype = isErr ? 'tool_result_error' : 'tool_result';
              final subtype = (toolUseId != null && toolUseId.isNotEmpty)
                  ? '$baseSubtype:$toolUseId'
                  : baseSubtype;
              contents.add(
                CodeMessageContent(
                  code: codeStr.isNotEmpty ? codeStr : 'No result',
                  subtype: subtype,
                ),
              );
            } else if (item['type'] == 'text') {
              contents.add(TextMessageContent(text: toText(item['text'])));
            }
          }

          if (contents.isNotEmpty) return contents;
        }
      }

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
            final error = errorVal is String ? errorVal : null;
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
                  ThinkingMessageContent(text: item['thinking'] as String),
                );
              }
            }
            return contents.isNotEmpty
                ? contents
                : [const TextMessageContent(text: '')];
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
            final text =
                '✅ Deployment succeeded${url.isNotEmpty ? ': $url' : ''}';
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
            if (message is Map<String, dynamic> && message['content'] is List) {
              final contents = <MessageContent>[];
              final blocks = message['content'] as List;
              final toolUseTotal = blocks
                  .where(
                    (it) =>
                        it is Map<String, dynamic> && it['type'] == 'tool_use',
                  )
                  .length;
              var toolUseSeen = 0;

              for (final item in blocks) {
                if (item is! Map<String, dynamic>) continue;
                if (item['type'] == 'text' && item['text'] != null) {
                  contents.add(
                    TextMessageContent(text: item['text'].toString()),
                  );
                } else if (item['type'] == 'thinking' &&
                    item['thinking'] != null) {
                  contents.add(
                    ThinkingMessageContent(text: item['thinking'].toString()),
                  );
                } else if (item['type'] == 'tool_use' && item['name'] != null) {
                  toolUseSeen += 1;
                  contents.add(
                    ToolMessageContent(
                      id: item['id']?.toString(),
                      name: item['name'].toString(),
                      input: item['input'],
                      status: toolUseSeen >= toolUseTotal
                          ? 'processing'
                          : 'done',
                    ),
                  );
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
            if (message is Map<String, dynamic> && message['content'] is List) {
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
                  final isErr = item['is_error'] == true;
                  final toolUseId = item['tool_use_id']?.toString().trim();
                  final baseSubtype = isErr
                      ? 'tool_result_error'
                      : 'tool_result';
                  final subtype = (toolUseId != null && toolUseId.isNotEmpty)
                      ? '$baseSubtype:$toolUseId'
                      : baseSubtype;
                  contents.add(
                    CodeMessageContent(
                      code: codeStr.isNotEmpty ? codeStr : 'No result',
                      subtype: subtype,
                    ),
                  );
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
            final errorMsg =
                rawPayload['message'] ?? rawPayload['error'] ?? 'Unknown error';
            return [TextMessageContent(text: '❌ $errorMsg')];
          }

        case 'complete':
          {
            // Complete message handling
            final success = rawPayload['success'];
            final code = rawPayload['code'];
            final statusText = success == true
                ? '✅ Task completed'
                : '❌ Task failed';
            final codeText = code != null ? ' (code: $code)' : '';
            return [TextMessageContent(text: '$statusText$codeText')];
          }

        case 'tool_result':
          {
            final content = rawPayload['content'] ?? rawPayload['message'];
            final isErr = rawPayload['is_error'] == true;
            final toolUseId = rawPayload['tool_use_id']?.toString().trim();
            final baseSubtype = isErr ? 'tool_result_error' : 'tool_result';
            final subtype = (toolUseId != null && toolUseId.isNotEmpty)
                ? '$baseSubtype:$toolUseId'
                : baseSubtype;

            String toText(dynamic val) {
              if (val is String) return val;
              if (val is Map<String, dynamic>) {
                if (val['text'] is String) return val['text'] as String;
                try {
                  return json.encode(val);
                } catch (_) {
                  return val.toString();
                }
              }
              return val?.toString() ?? '';
            }

            String codeStr;
            if (content is List) {
              codeStr = content.map((p) => toText(p)).join('\n');
            } else {
              codeStr = toText(content);
            }

            if (codeStr.trim().isEmpty) break;
            return [CodeMessageContent(code: codeStr, subtype: subtype)];
          }
        case 'task_update':
          {
            final content = rawPayload['content'] ?? rawPayload['message'];
            if (content is String) {
              final isErr = rawPayload['is_error'] == true;
              return [
                CodeMessageContent(
                  code: content,
                  subtype: isErr ? 'tool_result_error' : 'tool_result',
                ),
              ];
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
                          TextMessageContent(text: item['text'] as String),
                        );
                      } else if (item['type'] == 'thinking' &&
                          item['thinking'] is String) {
                        results.add(
                          ThinkingMessageContent(
                            text: item['thinking'] as String,
                          ),
                        );
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
    rawPayload = _coerceJsonPayload(rawPayload);
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

      // Some payloads (e.g. `session_message`) omit a recognized payload.type but
      // still carry tool_use/tool_result blocks inside `payload.message.content`.
      // Prefer parsing those blocks so tool outputs can be merged into tool calls.
      final wrapped = rawPayload['message'];
      if (wrapped is Map<String, dynamic> && wrapped['content'] is List) {
        final blocks = wrapped['content'] as List;
        final hasToolBlocks = blocks.any(
          (it) =>
              it is Map<String, dynamic> &&
              (it['type'] == 'tool_use' || it['type'] == 'tool_result'),
        );
        if (hasToolBlocks) {
          return createMessageContentsFromPayload(rawPayload);
        }
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
  static ChatMessage? historyEntryToMessage(ChatHistoryEntry entry) {
    var p = _coerceJsonPayload(entry.payload);

    String? payloadType;
    if (p is Map<String, dynamic>) {
      payloadType = p['type']?.toString();
    }

    final effectiveType =
        entry.messageType?.toString().trim().isNotEmpty == true
        ? entry.messageType?.toString()
        : payloadType;

    if (_isNonRenderableType(effectiveType)) return null;

    // Some history rows rely on entry.message_type; mirror web by treating it as payload.type.
    if (p is Map<String, dynamic> &&
        (payloadType == null || payloadType.trim().isEmpty) &&
        entry.messageType != null &&
        entry.messageType!.trim().isNotEmpty) {
      p = {...p, 'type': entry.messageType};
      payloadType = entry.messageType;
    }

    // Match web behavior: prefer message.role/payload.role/payload.type/message_type,
    // then fall back to direction.
    String? msgRole;
    String? payloadRole;
    if (p is Map<String, dynamic>) {
      final m = p['message'];
      if (m is Map) {
        msgRole = m['role']?.toString();
      }
      payloadRole = p['role']?.toString();
    }

    String role =
        _normalizeRole(msgRole) ??
        _normalizeRole(payloadRole) ??
        _normalizeRole(payloadType) ??
        _normalizeRole(entry.messageType) ??
        _normalizeRole(entry.direction) ??
        (entry.direction == 'user' ? 'user' : 'assistant');

    if (role == 'system') return null;

    // History should never look "in progress" in the UI.
    final contents = createMessageContents(entry.messageText, p).map((c) {
      if (c is! ToolMessageContent) return c;
      final st = (c.status ?? '').toLowerCase();
      if (st == 'processing') return c.copyWith(status: 'done');
      return c.copyWith(status: c.status ?? 'done');
    }).toList();

    if (contents.isEmpty) return null;
    final allEmptyText = contents.every(
      (c) => c is TextMessageContent && c.text.trim().isEmpty,
    );
    if (allEmptyText) return null;

    return ChatMessage(
      id: entry.id.toString(),
      role: role,
      createdAt: entry.createdAt,
      contents: contents,
    );
  }

  /// Align with d1vai web: merge tool execution results into the previous Bash tool
  /// message, so the message list doesn't show a standalone "tool result" bubble.
  static List<ChatMessage> mergeToolResultsIntoPrevBashTool(
    List<ChatMessage> messages,
  ) {
    // Backward-compat wrapper (now supports all tools, not only bash).
    return mergeToolResultsIntoPrevToolCalls(messages);
  }

  static bool _isToolResultSubtype(String? subtype) {
    final s = (subtype ?? '').toLowerCase().trim();
    return s == 'tool_result' ||
        s == 'tool_result_error' ||
        s.startsWith('tool_result:') ||
        s.startsWith('tool_result_error:');
  }

  static String? _extractToolUseIdFromSubtype(String? subtype) {
    final s = (subtype ?? '').trim();
    final idx = s.indexOf(':');
    if (idx < 0) return null;
    final id = s.substring(idx + 1).trim();
    return id.isEmpty ? null : id;
  }

  static List<ChatMessage> mergeToolResultsIntoPrevToolCalls(
    List<ChatMessage> messages,
  ) {
    final out = <ChatMessage>[];

    // Index tool result blocks by tool_use_id (order-preserving).
    final resultsById = <String, List<({String text, bool isError})>>{};
    for (final msg in messages) {
      for (final c in msg.contents.whereType<CodeMessageContent>()) {
        if (!_isToolResultSubtype(c.subtype)) continue;
        final id = _extractToolUseIdFromSubtype(c.subtype);
        if (id == null) continue;
        final isErr = (c.subtype ?? '').toLowerCase().trim().startsWith(
          'tool_result_error',
        );
        (resultsById[id] ??= []).add((text: c.code, isError: isErr));
      }
    }

    // Identify which tool_use_id actually exists in tool call messages.
    final toolIdsPresent = <String>{};
    for (final msg in messages) {
      for (final tool in msg.contents.whereType<ToolMessageContent>()) {
        final id = tool.id?.trim();
        if (id != null && id.isNotEmpty) toolIdsPresent.add(id);
      }
    }
    final attachableIds = resultsById.keys
        .where((id) => toolIdsPresent.contains(id))
        .toSet();

    // Attach each tool_use_id at most once.
    final attachedIds = <String>{};

    for (final msg in messages) {
      final contents = msg.contents;

      final toolResultCodes = contents
          .whereType<CodeMessageContent>()
          .where((c) => _isToolResultSubtype(c.subtype))
          .toList();

      final isToolResultMsg =
          toolResultCodes.isNotEmpty &&
          contents.isNotEmpty &&
          contents.every((c) {
            if (c is CodeMessageContent) return _isToolResultSubtype(c.subtype);
            if (c is TextMessageContent) return c.text.trim().isEmpty;
            return false;
          });

      if (isToolResultMsg) {
        String inferName(String text) {
          final s = text.trimLeft();
          if (s.startsWith('\$ ') || s.contains('\n\$ ')) return 'bash';
          if (s.startsWith('{') || s.startsWith('[')) return 'bash';
          if (s.contains('Traceback (most recent call last)')) return 'bash';
          return 'bash';
        }

        final orphan = <({String text, bool isError, String? toolUseId})>[];

        for (final code in toolResultCodes) {
          final toolUseId = _extractToolUseIdFromSubtype(code.subtype);
          if (toolUseId != null && attachableIds.contains(toolUseId)) {
            // Will be merged into the corresponding tool call message.
            continue;
          }

          final isErr = (code.subtype ?? '').toLowerCase().trim().startsWith(
            'tool_result_error',
          );

          // If the result has no id, best-effort attach to a previous tool call.
          if (toolUseId == null) {
            final ok = _attachToolOutputToPrevTool(
              out,
              toolUseId: null,
              outputText: code.code,
              isError: isErr,
            );
            if (ok) continue;
          }

          orphan.add((text: code.code, isError: isErr, toolUseId: toolUseId));
        }

        if (orphan.isEmpty) continue;

        final joined = orphan
            .map((o) => o.text.trimRight())
            .where((t) => t.isNotEmpty)
            .join('\n\n');
        if (joined.trim().isEmpty) continue;

        final anyError = orphan.any((o) => o.isError);
        String? firstId;
        for (final o in orphan) {
          final id = o.toolUseId?.trim();
          if (id != null && id.isNotEmpty) {
            firstId = id;
            break;
          }
        }

        final toolName = inferName(joined);
        final input = <String, dynamic>{
          'orphan_tool_result': true,
          if (firstId != null && firstId.trim().isNotEmpty)
            'tool_use_id': firstId,
        };

        out.add(
          msg.copyWith(
            role: 'assistant',
            contents: [
              ToolMessageContent(
                id: firstId,
                name: toolName,
                input: input,
                status: anyError ? 'error' : 'done',
                output: ToolOutput(
                  text: joined,
                  isError: anyError ? true : null,
                ),
              ),
            ],
          ),
        );
        continue;
      }

      // Attach indexed tool outputs onto tool call blocks.
      var mutated = false;
      final nextContents = <MessageContent>[];

      for (final c in contents) {
        if (c is! ToolMessageContent) {
          nextContents.add(c);
          continue;
        }

        final toolId = c.id?.trim();
        if (toolId == null ||
            toolId.isEmpty ||
            !attachableIds.contains(toolId) ||
            attachedIds.contains(toolId)) {
          nextContents.add(c);
          continue;
        }

        final results = resultsById[toolId];
        if (results == null || results.isEmpty) {
          nextContents.add(c);
          continue;
        }

        final prevOut = c.output?.text ?? '';
        var joined = prevOut;
        var sawError = c.output?.isError == true;

        for (final r in results) {
          final text = r.text.trimRight();
          if (text.isEmpty) continue;
          joined = joined.trim().isNotEmpty ? '$joined\n\n$text' : text;
          if (r.isError) sawError = true;
        }

        if (joined.trim().isEmpty) {
          nextContents.add(c);
          continue;
        }

        final capped = joined.length > 120000
            ? joined.substring(joined.length - 120000)
            : joined;

        mutated = true;
        attachedIds.add(toolId);
        nextContents.add(
          c.copyWith(
            status: sawError ? 'error' : 'done',
            output: ToolOutput(text: capped, isError: sawError ? true : null),
          ),
        );
      }

      out.add(mutated ? msg.copyWith(contents: nextContents) : msg);
    }

    return out;
  }

  static bool _attachToolOutputToPrevTool(
    List<ChatMessage> out, {
    required String? toolUseId,
    required String outputText,
    required bool isError,
  }) {
    final text = outputText.trimRight();
    if (text.isEmpty) return true;

    int targetMsgIndex = -1;
    int targetToolIndex = -1;

    // Prefer matching by tool_use_id when available.
    if (toolUseId != null && toolUseId.isNotEmpty) {
      for (var mi = out.length - 1; mi >= 0; mi--) {
        final prevContents = out[mi].contents;
        for (var ci = prevContents.length - 1; ci >= 0; ci--) {
          final c = prevContents[ci];
          if (c is! ToolMessageContent) continue;
          if ((c.id ?? '').trim() == toolUseId) {
            targetMsgIndex = mi;
            targetToolIndex = ci;
            break;
          }
        }
        if (targetMsgIndex >= 0) break;
      }
    }

    // Fallback: attach to the nearest previous tool call.
    if (targetMsgIndex < 0 || targetToolIndex < 0) {
      for (var mi = out.length - 1; mi >= 0; mi--) {
        final prevContents = out[mi].contents;
        for (var ci = prevContents.length - 1; ci >= 0; ci--) {
          final c = prevContents[ci];
          if (c is! ToolMessageContent) continue;
          targetMsgIndex = mi;
          targetToolIndex = ci;
          break;
        }
        if (targetMsgIndex >= 0) break;
      }
    }

    if (targetMsgIndex < 0 || targetToolIndex < 0) return false;

    final prevMsg = out[targetMsgIndex];
    final prevContents = prevMsg.contents.toList();
    final prevTool = prevContents[targetToolIndex] as ToolMessageContent;

    final prevOut = prevTool.output?.text ?? '';
    final joined = prevOut.trim().isNotEmpty ? '$prevOut\n\n$text' : text;
    final capped = joined.length > 120000
        ? joined.substring(joined.length - 120000)
        : joined;

    final nextStatus = isError ? 'error' : 'done';

    prevContents[targetToolIndex] = prevTool.copyWith(
      status: nextStatus,
      output: ToolOutput(
        text: capped,
        isError: isError || prevTool.output?.isError == true ? true : null,
      ),
    );

    out[targetMsgIndex] = prevMsg.copyWith(contents: prevContents);
    return true;
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
                id: contentJson['id']?.toString(),
                name: contentJson['name']?.toString() ?? 'unknown',
                input: contentJson['input'],
                status: contentJson['status']?.toString(),
                output: contentJson['output'] is Map<String, dynamic>
                    ? ToolOutput.fromJson(
                        contentJson['output'] as Map<String, dynamic>,
                      )
                    : null,
              );
            case 'result':
              return ResultMessageContent(
                payload:
                    contentJson['result'] ??
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
                subtype: contentJson['subtype']?.toString(),
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
                text:
                    contentJson['text']?.toString() ??
                    contentJson['content']?.toString() ??
                    json.encode(contentJson),
              );
          }
        }).toList();

        return ChatMessage(
          id:
              data['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          role: data['role']?.toString() ?? 'assistant',
          createdAt:
              DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          contents: contents,
        );
      }

      // Format 2: Simple message with type
      if (data['type'] is String) {
        final messageType = data['type'] as String;
        final role = data['role']?.toString() ?? 'assistant';
        final id =
            data['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        final createdAt =
            data['createdAt']?.toString() ?? DateTime.now().toIso8601String();

        final contents = <MessageContent>[];

        switch (messageType) {
          case 'text':
          case 'assistant':
            final text =
                data['text']?.toString() ?? data['content']?.toString() ?? '';

            // Smart detection based on content
            if (text.contains('✅') || text.contains('❌')) {
              if (text.contains('finished') || text.contains('failed')) {
                contents.add(
                  CompletionMessageContent(
                    message: text,
                    success: text.contains('✅'),
                    details: null,
                  ),
                );
              } else if (text.startsWith('❌')) {
                contents.add(
                  ErrorMessageContent(message: text, code: null, details: null),
                );
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
              contents.add(
                ToolMessageContent(
                  id: tool['id']?.toString(),
                  name: tool['name']?.toString() ?? 'unknown',
                  input: tool['input'],
                  status: tool['status']?.toString(),
                ),
              );
            }
            break;

          case 'tool_result':
          case 'result':
            contents.add(
              ResultMessageContent(
                payload: data['result'] ?? data['payload'] ?? data['content'],
              ),
            );
            break;

          case 'deployment':
            contents.add(
              DeploymentMessageContent(
                status: data['status']?.toString() ?? 'unknown',
                environment: data['environment']?.toString(),
                url: data['url']?.toString(),
                message: data['message']?.toString(),
                deploymentId: data['deploymentId']?.toString(),
              ),
            );
            break;

          case 'git_commit':
            contents.add(
              GitCommitMessageContent(
                projectId: data['projectId']?.toString(),
                message: data['message']?.toString() ?? '',
                files: (data['files'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList(),
              ),
            );
            break;

          case 'git_push':
            contents.add(
              GitPushMessageContent(
                projectId: data['projectId']?.toString(),
                branch: data['branch']?.toString() ?? '',
                success: data['success'] is bool
                    ? data['success'] as bool
                    : false,
                error: data['error']?.toString(),
              ),
            );
            break;

          case 'error':
            contents.add(
              ErrorMessageContent(
                message: data['message']?.toString() ?? 'Unknown error',
                code: data['code']?.toString(),
                details: data['details'],
              ),
            );
            break;

          case 'thinking':
            if (data['text'] is String) {
              contents.add(
                ThinkingMessageContent(text: data['text'] as String),
              );
            }
            break;

          case 'code':
            if (data['code'] is String) {
              contents.add(
                CodeMessageContent(
                  code: data['code'] as String,
                  subtype: data['subtype']?.toString(),
                ),
              );
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
        final text =
            data['text']?.toString() ?? data['content']?.toString() ?? '';
        final role = data['role']?.toString() ?? 'assistant';
        final id =
            data['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        final createdAt =
            data['createdAt']?.toString() ?? DateTime.now().toIso8601String();

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
                ErrorMessageContent(message: text, code: null, details: null),
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
        id:
            data['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        role: data['role']?.toString() ?? 'assistant',
        createdAt:
            DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
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
