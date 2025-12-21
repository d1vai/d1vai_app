import 'package:flutter/material.dart';
import 'tool_container.dart';

/// Write tool message renderer
class WriteTool extends StatelessWidget {
  final dynamic input;
  final String? status;

  const WriteTool({super.key, required this.input, this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String filePath = '';

    if (input is Map) {
      filePath = input['file_path']?.toString() ?? '';
    }

    return ToolContainer(
      toolType: 'Write',
      status: status,
      child: Row(
        children: [
          Icon(
            Icons.edit_outlined,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              filePath,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w400,
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
