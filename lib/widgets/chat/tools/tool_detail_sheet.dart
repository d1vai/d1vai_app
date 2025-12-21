import 'package:flutter/material.dart';
import '../../../models/message.dart';
import 'tool_utils.dart';

class ToolDetailSheet {
  static Future<void> show(
    BuildContext context, {
    required ToolMessageContent content,
  }) async {
    final theme = Theme.of(context);
    final status = coerceToolStatus(content.status, content.input);
    final toolName = content.name;
    final summary = toolSummary(toolName, content.input);
    final details = _ToolDetails.from(toolName, content.input);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ListView(
                  controller: scrollController,
                  children: [
                    _Header(
                      toolName: toolName,
                      status: status,
                      summary: summary,
                    ),
                    const SizedBox(height: 12),
                    if (details.primaryLines.isNotEmpty)
                      _Section(
                        title: 'Details',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in details.primaryLines)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _KeyValueLine(
                                  label: line.label,
                                  value: line.value,
                                ),
                              ),
                            if (details.todos != null) ...[
                              const SizedBox(height: 8),
                              _TodoList(todos: details.todos!),
                            ],
                          ],
                        ),
                      ),
                    if (details.primaryLines.isNotEmpty) const SizedBox(height: 12),
                    _Section(
                      title: 'Input',
                      child: _CodeBlock(text: prettyJson(content.input)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String toolName;
  final String status;
  final String summary;

  const _Header({
    required this.toolName,
    required this.status,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = _StatusChip(status: status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                toolName.isEmpty ? 'Tool' : toolName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            chip,
          ],
        ),
        const SizedBox(height: 6),
        Text(
          summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = status.toLowerCase();
    final bg = switch (st) {
      'processing' => theme.colorScheme.primary.withValues(alpha: 0.12),
      'error' => theme.colorScheme.error.withValues(alpha: 0.12),
      'warning' => Colors.amber.withValues(alpha: 0.14),
      _ => theme.colorScheme.surfaceContainerHighest,
    };
    final fg = switch (st) {
      'processing' => theme.colorScheme.primary,
      'error' => theme.colorScheme.error,
      'warning' => Colors.amber.shade800,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final label = switch (st) {
      'processing' => 'Running',
      'error' => 'Error',
      'warning' => 'Warning',
      _ => 'Done',
    };

    Widget leading;
    if (st == 'processing') {
      leading = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else if (st == 'error') {
      leading = Icon(Icons.error_outline, size: 16, color: fg);
    } else if (st == 'warning') {
      leading = Icon(Icons.warning_amber_rounded, size: 16, color: fg);
    } else {
      leading = Icon(Icons.check_circle_outline, size: 16, color: fg);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: fg.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TodoList extends StatelessWidget {
  final List<_TodoItem> todos;

  const _TodoList({required this.todos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Todos',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final t in todos)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  t.status == 'done'
                      ? Icons.check_circle
                      : t.status == 'in_progress'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  size: 18,
                  color: t.status == 'done'
                      ? Colors.green
                      : t.status == 'in_progress'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;

  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          height: 1.25,
        ),
      ),
    );
  }
}

class _ToolDetails {
  final List<({String label, String value})> primaryLines;
  final List<_TodoItem>? todos;

  const _ToolDetails({required this.primaryLines, this.todos});

  static _ToolDetails from(String toolName, dynamic input) {
    final name = toolName.toLowerCase();
    final lines = <({String label, String value})>[];

    String getStr(String key) {
      if (input is Map) {
        final v = input[key];
        if (v == null) return '';
        return v.toString();
      }
      return '';
    }

    switch (name) {
      case 'read':
      case 'write':
      case 'edit':
      case 'multi_edit':
      case 'multiedit': {
        final p = getStr('file_path');
        if (p.isNotEmpty) lines.add((label: 'File', value: p));
        break;
      }
      case 'bash': {
        final cmd = getStr('command');
        if (cmd.isNotEmpty) lines.add((label: 'Command', value: cmd));
        break;
      }
      case 'glob':
      case 'grep': {
        final pat = getStr('pattern');
        if (pat.isNotEmpty) lines.add((label: 'Pattern', value: pat));
        final path = getStr('path');
        if (path.isNotEmpty) lines.add((label: 'Path', value: path));
        break;
      }
      case 'websearch':
      case 'web_search': {
        final q = getStr('query');
        if (q.isNotEmpty) lines.add((label: 'Query', value: q));
        break;
      }
      case 'webfetch':
      case 'web_fetch': {
        final url = getStr('url');
        if (url.isNotEmpty) lines.add((label: 'URL', value: url));
        break;
      }
      case 'todowrite':
      case 'todo_write': {
        final header = todoWriteHeader(input);
        if (header != null) {
          lines.add((label: 'Progress', value: header.progressText));
          if (header.state == 'in_progress' && header.taskText.isNotEmpty) {
            lines.add((label: 'Current', value: header.taskText));
          }
        }
        final todos = <_TodoItem>[];
        if (input is Map && input['todos'] is List) {
          for (final t in (input['todos'] as List)) {
            if (t is! Map) continue;
            final content = t['content']?.toString().trim() ?? '';
            if (content.isEmpty) continue;
            final st = t['status']?.toString().trim() ?? '';
            todos.add(_TodoItem(content: content, status: st));
          }
        }
        return _ToolDetails(primaryLines: lines, todos: todos.isEmpty ? null : todos);
      }
      default:
        break;
    }

    return _ToolDetails(primaryLines: lines, todos: null);
  }
}

class _TodoItem {
  final String content;
  final String status;

  const _TodoItem({required this.content, required this.status});
}
