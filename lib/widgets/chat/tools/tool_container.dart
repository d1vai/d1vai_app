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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
