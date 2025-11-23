import 'package:flutter/material.dart';
import 'tool_container.dart';

/// Read tool message renderer
class ReadTool extends StatelessWidget {
  final dynamic input;

  const ReadTool({
    super.key,
    required this.input,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String filePath = '';

    if (input is Map) {
      filePath = input['file_path']?.toString() ?? '';
    }

    return ToolContainer(
      toolType: 'Read',
      child: Row(
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              filePath,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
