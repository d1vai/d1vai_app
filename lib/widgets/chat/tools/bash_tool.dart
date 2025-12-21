import 'package:flutter/material.dart';
import 'tool_container.dart';

/// Bash tool message renderer
class BashTool extends StatelessWidget {
  final dynamic input;
  final String? status;

  const BashTool({super.key, required this.input, this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Parse input
    String command = '';

    if (input is Map) {
      command = input['command']?.toString() ?? '';
    }

    return ToolContainer(
      toolType: 'Bash',
      compact: true,
      status: status,
      child: Row(
        children: [
          Icon(
            Icons.terminal,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            '\$ ',
            style: TextStyle(
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              command,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
