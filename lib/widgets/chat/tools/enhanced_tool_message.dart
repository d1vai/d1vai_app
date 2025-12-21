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

    IconData icon;
    switch (name.toLowerCase()) {
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
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
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
    String label;
    Widget icon;

    if (st == 'processing') {
      fg = theme.colorScheme.primary;
      label = 'Running';
      icon = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else if (st == 'error') {
      fg = theme.colorScheme.error;
      label = 'Error';
      icon = Icon(Icons.error_outline, size: 16, color: fg);
    } else if (st == 'warning') {
      fg = Colors.amber.shade800;
      label = 'Warn';
      icon = Icon(Icons.warning_amber_rounded, size: 16, color: fg);
    } else {
      fg = theme.colorScheme.onSurfaceVariant;
      label = 'Done';
      icon = Icon(Icons.check_circle_outline, size: 16, color: fg);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
