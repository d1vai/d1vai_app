import 'package:flutter/material.dart';
import 'timestamp_tooltip.dart';

/// Message metadata widget showing status, timestamp, etc.
class MessageMetadata extends StatelessWidget {
  final String role;
  final String? status;
  final DateTime createdAt;
  final VoidCallback? onRetry;
  final bool showTimestamp;

  const MessageMetadata({
    super.key,
    required this.role,
    required this.createdAt,
    this.status,
    this.onRetry,
    this.showTimestamp = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = role == 'user';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Role indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isUser ? 'You' : 'AI',
            style: TextStyle(
              fontSize: 10,
              color: isUser
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Status indicator
        if (status != null) ...[
          if (status == 'pending')
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            )
          else if (status == 'failed')
            GestureDetector(
              onTap: onRetry,
              child: Icon(
                Icons.error_outline,
                size: 14,
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(width: 4),
        ],
        // Timestamp with tooltip
        if (showTimestamp)
          TimestampTooltip(
            timestamp: createdAt,
            child: Text(
              _formatTime(createdAt),
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        // Retry button
        if (status == 'failed' && onRetry != null) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
