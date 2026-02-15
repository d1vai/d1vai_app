import 'package:flutter/material.dart';

/// Tooltip for displaying timestamp on hover/tap
class TimestampTooltip extends StatelessWidget {
  final DateTime timestamp;
  final Widget child;

  const TimestampTooltip({
    super.key,
    required this.timestamp,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(message: _formatFullDateTime(timestamp), child: child);
  }

  String _formatFullDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    String dateStr;
    if (difference.inDays == 0) {
      dateStr = 'Today';
    } else if (difference.inDays == 1) {
      dateStr = 'Yesterday';
    } else if (difference.inDays < 7) {
      dateStr = '${difference.inDays} days ago';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';

    return '$dateStr at $time';
  }
}
