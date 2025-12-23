import 'package:flutter/material.dart';

/// Container for tool messages with consistent styling
class ToolContainer extends StatelessWidget {
  final Widget child;
  final String toolType;
  final bool compact;
  final String? status;

  const ToolContainer({
    super.key,
    required this.child,
    required this.toolType,
    this.compact = false,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = status?.toLowerCase().trim();

    Widget leading;
    if (st == 'processing' || st == 'running' || st == 'pending') {
      leading = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
        ),
      );
    } else if (st == 'error' || st == 'failed' || st == 'failure') {
      leading = Icon(
        Icons.error_outline,
        size: 14,
        color: theme.colorScheme.error,
      );
    } else if (st == 'warning' || st == 'warn') {
      leading = Icon(
        Icons.warning_amber_rounded,
        size: 14,
        color: theme.brightness == Brightness.dark
            ? Colors.amber.shade300
            : Colors.amber.shade700,
      );
    } else {
      leading = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
