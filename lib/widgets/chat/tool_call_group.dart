import 'package:flutter/material.dart';

import '../../models/message.dart';
import 'message_bubble.dart';
import 'tools/tool_utils.dart';

class ToolCallGroup extends StatefulWidget {
  final List<ChatMessage> messages;

  const ToolCallGroup({super.key, required this.messages});

  @override
  State<ToolCallGroup> createState() => _ToolCallGroupState();
}

class _ToolCallGroupState extends State<ToolCallGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleMessages = widget.messages
        .map(
          (message) => message.copyWith(
            contents: message.contents
                .where(_isToolLikeContent)
                .toList(growable: false),
          ),
        )
        .where((message) => message.contents.isNotEmpty)
        .toList(growable: false);
    final renderableCount = visibleMessages.fold<int>(
      0,
      (count, message) => count + message.contents.length,
    );
    final toolCount = visibleMessages.fold<int>(
      0,
      (count, message) =>
          count + message.contents.whereType<ToolMessageContent>().length,
    );
    final completedToolCount = visibleMessages.fold<int>(
      0,
      (count, message) =>
          count +
          message.contents
              .whereType<ToolMessageContent>()
              .where(
                (content) =>
                    coerceToolStatus(content.status, content.input) !=
                    'processing',
              )
              .length,
    );
    final hasProcessing = visibleMessages.any(
      (message) => message.contents.whereType<ToolMessageContent>().any(
        toolMessageHasProcessing,
      ),
    );
    final latestTool = _latestToolMeta(visibleMessages);
    final summaryText = toolCount > 0
        ? (hasProcessing
              ? 'Running $completedToolCount/$toolCount tools'
              : 'Completed $toolCount tools')
        : 'Tool results · $renderableCount items';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.24 : 0.48,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Color.alphaBlend(
                      theme.colorScheme.primary.withValues(
                        alpha: hasProcessing
                            ? (theme.brightness == Brightness.dark
                                  ? 0.12
                                  : 0.08)
                            : 0.0,
                      ),
                      theme.colorScheme.outlineVariant.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.42
                            : 0.62,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.82,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        summaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.88,
                          ),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    if (latestTool != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          child: Row(
                            key: ValueKey(latestTool.key),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                latestTool.icon,
                                size: 12,
                                color: latestTool.iconColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  latestTool.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.80),
                                    fontWeight: FontWeight.w500,
                                    fontFamily: latestTool.monospace
                                        ? 'monospace'
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (hasProcessing) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: _open ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.34
                              : 0.48,
                        ),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: visibleMessages
                          .map((message) {
                            return MessageBubble(
                              message: message,
                              isUser: message.role == 'user',
                              overrideContents: message.contents,
                              plainLayout: true,
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isToolLikeContent(MessageContent content) {
  if (content is ToolMessageContent) return true;
  if (content is CodeMessageContent) {
    return (content.subtype ?? '').toLowerCase().trim() == 'tool_result';
  }
  return false;
}

class _ToolMeta {
  final String key;
  final String title;
  final IconData icon;
  final Color iconColor;
  final bool monospace;

  const _ToolMeta({
    required this.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.monospace,
  });
}

_ToolMeta? _latestToolMeta(List<ChatMessage> messages) {
  for (var mi = messages.length - 1; mi >= 0; mi--) {
    final contents = messages[mi].contents;
    for (var ci = contents.length - 1; ci >= 0; ci--) {
      final content = contents[ci];
      if (content is! ToolMessageContent) continue;
      final normalized = content.name.toLowerCase().trim();
      return _ToolMeta(
        key:
            '${messages[mi].id}:${content.id ?? ci}:${content.status ?? 'done'}',
        title: _toolHeadline(content),
        icon: _toolIcon(normalized),
        iconColor: _toolIconColor(normalized),
        monospace: _toolUsesMonospace(normalized),
      );
    }
  }
  return null;
}

String _toolHeadline(ToolMessageContent content) {
  final normalized = content.name.toLowerCase().trim();
  final input = content.input;
  switch (normalized) {
    case 'read':
    case 'read_file':
      return _truncateToolTitle(
        input is Map
            ? (shortenToolFilePath(
                    input['file_path']?.toString() ?? '',
                    maxSegments: 4,
                  ).isNotEmpty
                  ? shortenToolFilePath(
                      input['file_path']?.toString() ?? '',
                      maxSegments: 4,
                    )
                  : 'Read file')
            : 'Read file',
      );
    case 'edit':
      return _truncateToolTitle(
        input is Map
            ? (shortenToolFilePath(
                    input['file_path']?.toString() ?? '',
                    maxSegments: 4,
                  ).isNotEmpty
                  ? shortenToolFilePath(
                      input['file_path']?.toString() ?? '',
                      maxSegments: 4,
                    )
                  : 'Edit file')
            : 'Edit file',
      );
    case 'multiedit':
    case 'multi_edit':
      if (input is Map) {
        final file = shortenToolFilePath(
          input['file_path']?.toString() ?? '',
          maxSegments: 4,
        );
        final edits = input['edits'];
        final count = edits is List ? edits.length : null;
        final title =
            '${file.isNotEmpty ? file : 'Batch edit'}${count != null ? ' ($count)' : ''}';
        return _truncateToolTitle(title);
      }
      return 'Batch edit';
    case 'write':
    case 'write_file':
      return _truncateToolTitle(
        input is Map
            ? (shortenToolFilePath(
                    input['file_path']?.toString() ?? '',
                    maxSegments: 4,
                  ).isNotEmpty
                  ? shortenToolFilePath(
                      input['file_path']?.toString() ?? '',
                      maxSegments: 4,
                    )
                  : 'Write file')
            : 'Write file',
      );
    case 'bash':
    case 'exec_command':
    case 'functions.exec_command':
      return _truncateToolTitle(
        input is Map
            ? (input['command'] ?? input['cmd'] ?? 'Run command').toString()
            : 'Run command',
      );
    case 'glob':
    case 'grep':
      return _truncateToolTitle(
        input is Map
            ? (input['pattern']?.toString() ?? normalized)
            : normalized,
      );
    case 'todowrite':
    case 'todo_write':
      final header = todoWriteHeader(input);
      if (header == null) return 'Todo';
      return _truncateToolTitle(
        header.taskText.isNotEmpty
            ? header.taskText
            : 'Todo · ${header.progressText}',
      );
    case 'task':
      if (input is Map) {
        final desc = [
          input['description']?.toString().trim() ?? '',
          input['goal']?.toString().trim() ?? '',
          input['title']?.toString().trim() ?? '',
          input['prompt']?.toString().trim() ?? '',
          input['task_type']?.toString().trim() ?? '',
        ].firstWhere((value) => value.isNotEmpty, orElse: () => 'Task');
        return _truncateToolTitle(desc);
      }
      return 'Task';
    default:
      return _truncateToolTitle(
        content.name.trim().isNotEmpty ? content.name.trim() : 'Tool',
      );
  }
}

String _truncateToolTitle(String text, {int maxLen = 58}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return '';
  if (normalized.length <= maxLen) return normalized;
  return '${normalized.substring(0, maxLen - 1)}…';
}

IconData _toolIcon(String normalized) {
  switch (normalized) {
    case 'bash':
    case 'exec_command':
    case 'functions.exec_command':
      return Icons.terminal;
    case 'read':
    case 'read_file':
      return Icons.description_outlined;
    case 'write':
    case 'write_file':
      return Icons.edit_outlined;
    case 'edit':
    case 'multiedit':
    case 'multi_edit':
      return Icons.edit_note;
    case 'glob':
      return Icons.search;
    case 'grep':
      return Icons.find_replace;
    case 'websearch':
    case 'web_search':
      return Icons.travel_explore;
    case 'webfetch':
    case 'web_fetch':
      return Icons.link;
    case 'todowrite':
    case 'todo_write':
      return Icons.checklist;
    case 'task':
      return Icons.task_alt;
    default:
      return Icons.build;
  }
}

Color _toolIconColor(String normalized) {
  switch (normalized) {
    case 'bash':
    case 'exec_command':
    case 'functions.exec_command':
      return const Color(0xFF2E7D32);
    case 'read':
    case 'read_file':
      return const Color(0xFF1565C0);
    case 'write':
    case 'write_file':
    case 'edit':
    case 'multiedit':
    case 'multi_edit':
      return const Color(0xFF7B1FA2);
    case 'glob':
    case 'grep':
      return const Color(0xFFEF6C00);
    case 'websearch':
    case 'web_search':
    case 'webfetch':
    case 'web_fetch':
      return const Color(0xFF00838F);
    case 'todowrite':
    case 'todo_write':
      return const Color(0xFF6A1B9A);
    case 'task':
      return const Color(0xFF5D4037);
    default:
      return const Color(0xFF546E7A);
  }
}

bool _toolUsesMonospace(String normalized) {
  switch (normalized) {
    case 'bash':
    case 'read':
    case 'read_file':
    case 'write':
    case 'write_file':
    case 'edit':
    case 'multiedit':
    case 'multi_edit':
    case 'glob':
    case 'grep':
    case 'webfetch':
    case 'web_fetch':
      return true;
    default:
      return false;
  }
}
