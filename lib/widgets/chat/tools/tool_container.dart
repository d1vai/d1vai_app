import 'package:flutter/material.dart';

/// Container for tool messages with consistent styling
class ToolContainer extends StatelessWidget {
  final Widget child;
  final String toolType;
  final bool compact;

  const ToolContainer({
    super.key,
    required this.child,
    required this.toolType,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: EdgeInsets.all(compact ? 8.0 : 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tool: $toolType',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          child,
        ],
      ),
    );
  }
}
