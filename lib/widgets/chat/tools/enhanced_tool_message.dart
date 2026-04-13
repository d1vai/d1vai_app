import 'package:flutter/material.dart';
import '../../../models/message.dart';
import 'tool_detail_sheet.dart';
import 'tool_utils.dart';

/// Enhanced tool message renderer with specialized components for different tool types
class EnhancedToolMessage extends StatelessWidget {
  final ToolMessageContent content;

  const EnhancedToolMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = content.name;
    final status = coerceToolStatus(content.status, content.input);
    final summary = toolSummary(name, content.input);

    final normalized = name.toLowerCase().trim();
    final title = _toolTitle(normalized, fallback: name);
    final subtitle = _toolSubtitle(
      normalized,
      content.input,
      summaryFallback: summary,
    );

    IconData icon;
    switch (normalized) {
      case 'bash':
        icon = Icons.terminal;
        break;
      case 'read':
        icon = Icons.description_outlined;
        break;
      case 'write':
        icon = Icons.edit_outlined;
        break;
      case 'edit':
      case 'multi_edit':
      case 'multiedit':
        icon = Icons.edit_note;
        break;
      case 'glob':
        icon = Icons.search;
        break;
      case 'grep':
        icon = Icons.find_replace;
        break;
      case 'websearch':
      case 'web_search':
        icon = Icons.travel_explore;
        break;
      case 'webfetch':
      case 'web_fetch':
        icon = Icons.link;
        break;
      case 'todowrite':
      case 'todo_write':
        icon = Icons.checklist;
        break;
      case 'task':
        icon = Icons.task_alt;
        break;
      default:
        icon = Icons.build;
        break;
    }

    final statusWidget = _StatusRight(status: status);

    return InkWell(
      onTap: () {
        ToolDetailSheet.show(context, content: content);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.48 : 0.62,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.55 : 0.65,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: theme.colorScheme.primary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.9,
                        ),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    TextSpan(
                      text: '  ·  ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.95,
                        ),
                        fontWeight: FontWeight.w600,
                        fontFamily: _subtitleFontFamily(normalized),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            statusWidget,
          ],
        ),
      ),
    );
  }
}

class _StatusRight extends StatelessWidget {
  final String status;

  const _StatusRight({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = status.toLowerCase();

    Color fg;
    Color bg;
    Widget icon;
    final bool showLabel;
    String label = '';

    if (st == 'processing') {
      fg = theme.colorScheme.primary;
      bg = theme.colorScheme.primary.withValues(alpha: 0.12);
      icon = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
      showLabel = true;
      label = 'Running';
    } else if (st == 'error') {
      fg = theme.colorScheme.error;
      bg = theme.colorScheme.error.withValues(alpha: 0.12);
      icon = Icon(Icons.error_outline, size: 16, color: fg);
      showLabel = true;
      label = 'Error';
    } else if (st == 'warning') {
      fg = _warningTint(theme);
      bg = _warningTint(
        theme,
      ).withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.14);
      icon = Icon(Icons.warning_amber_rounded, size: 16, color: fg);
      showLabel = true;
      label = 'Warn';
    } else {
      fg = theme.colorScheme.onSurfaceVariant;
      bg = theme.colorScheme.surfaceContainerHighest;
      icon = Icon(Icons.check_circle_outline, size: 16, color: fg);
      showLabel = false;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 10 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: showLabel
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          : icon,
    );
  }
}

Color _warningTint(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? Colors.amber.shade300
      : Colors.amber.shade800;
}

String _toolTitle(String normalized, {required String fallback}) {
  switch (normalized) {
    case 'bash':
      return 'Bash';
    case 'read':
      return 'Read';
    case 'write':
      return 'Write';
    case 'edit':
      return 'Edit';
    case 'multi_edit':
    case 'multiedit':
      return 'MultiEdit';
    case 'glob':
      return 'Glob';
    case 'grep':
      return 'Grep';
    case 'websearch':
    case 'web_search':
      return 'WebSearch';
    case 'webfetch':
    case 'web_fetch':
      return 'WebFetch';
    case 'todowrite':
    case 'todo_write':
      return 'TodoWrite';
    case 'task':
      return 'Task';
    default:
      return fallback.isNotEmpty ? fallback : 'Tool';
  }
}

String _toolSubtitle(
  String normalized,
  dynamic input, {
  required String summaryFallback,
}) {
  try {
    if (input is Map) {
      switch (normalized) {
        case 'bash':
          {
            final cmd = input['command']?.toString().trim() ?? '';
            return cmd.isNotEmpty
                ? '\$ ${truncateText(cmd, maxLen: 64)}'
                : summaryFallback;
          }
        case 'read':
        case 'write':
        case 'edit':
          {
            final p = input['file_path']?.toString().trim() ?? '';
            final s = shortenToolFilePath(p, maxSegments: 4);
            return s.isNotEmpty ? s : summaryFallback;
          }
        case 'multi_edit':
        case 'multiedit':
          {
            final p = input['file_path']?.toString().trim() ?? '';
            final edits = input['edits'];
            final n = edits is List ? edits.length : null;
            final base = shortenToolFilePath(p, maxSegments: 4);
            final left = base.isNotEmpty ? base : '(unknown)';
            return n != null ? '$left · $n edits' : left;
          }
        case 'glob':
        case 'grep':
          {
            final pat = input['pattern']?.toString().trim() ?? '';
            return pat.isNotEmpty
                ? truncateText(pat, maxLen: 64)
                : summaryFallback;
          }
        case 'websearch':
        case 'web_search':
          {
            final q = input['query']?.toString().trim() ?? '';
            return q.isNotEmpty ? truncateText(q, maxLen: 64) : summaryFallback;
          }
        case 'webfetch':
        case 'web_fetch':
          {
            final url = input['url']?.toString().trim() ?? '';
            return url.isNotEmpty
                ? truncateText(url, maxLen: 64)
                : summaryFallback;
          }
        case 'todowrite':
        case 'todo_write':
          {
            final header = todoWriteHeader(input);
            if (header == null) return summaryFallback;
            if (header.state == 'done_all') {
              return 'Done · ${header.progressText}';
            }
            if (header.state == 'pending') {
              return 'Pending · ${header.progressText}';
            }
            if (header.state == 'partial') {
              return '${header.progressText} complete';
            }
            return header.taskText.isNotEmpty
                ? 'In progress · ${header.progressText} · ${header.taskText}'
                : 'In progress · ${header.progressText}';
          }
        case 'task':
          {
            final t = input['task_type']?.toString().trim() ?? '';
            final desc = [
              input['description']?.toString().trim() ?? '',
              input['goal']?.toString().trim() ?? '',
              input['title']?.toString().trim() ?? '',
              input['prompt']?.toString().trim() ?? '',
            ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
            final bits = <String>[
              if (t.isNotEmpty) t,
              if (desc.isNotEmpty) truncateText(desc, maxLen: 56),
            ];
            return bits.isNotEmpty ? bits.join(' · ') : summaryFallback;
          }
      }
    }
  } catch (_) {
    // fall through
  }
  return summaryFallback;
}

String? _subtitleFontFamily(String normalized) {
  switch (normalized) {
    case 'bash':
    case 'read':
    case 'write':
    case 'edit':
    case 'multi_edit':
    case 'multiedit':
    case 'glob':
    case 'grep':
    case 'webfetch':
    case 'web_fetch':
      return 'monospace';
    default:
      return null;
  }
}
