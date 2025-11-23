import 'package:flutter/material.dart';
import 'tool_container.dart';

/// Bash tool message renderer
class BashTool extends StatelessWidget {
  final dynamic input;

  const BashTool({
    super.key,
    required this.input,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Parse input
    String command = '';
    String? description;
    int? timeout;
    bool? runInBackground;

    if (input is Map) {
      command = input['command']?.toString() ?? '';
      description = input['description']?.toString();
      timeout = input['timeout'] as int?;
      runInBackground = input['run_in_background'] as bool?;
    }

    return ToolContainer(
      toolType: 'Bash',
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Command
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '\$ ',
                      style: TextStyle(
                        color: Colors.green[400],
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        command,
                        style: TextStyle(
                          color: Colors.green[400],
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Description and options
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null && description.isNotEmpty)
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (timeout != null || runInBackground == true) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (timeout != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${timeout}ms',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (runInBackground == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'background',
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
