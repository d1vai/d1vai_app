import 'package:flutter/material.dart';
import 'project_chat/status_dot.dart';

bool chatStatusIsPulsing(String label) {
  final lower = label.toLowerCase().trim();
  if (lower.contains('work')) return true;
  if (lower.contains('think')) return true;
  if (lower.contains('deploy')) return true;
  return false;
}

Color chatStatusDotColor(ThemeData theme, String label, {required bool isError}) {
  final lower = label.toLowerCase().trim();
  if (isError) {
    return theme.colorScheme.error;
  }
  if (lower.contains('deploy')) {
    return theme.colorScheme.primary;
  }
  if (lower.contains('work')) {
    return Colors.amber;
  }
  if (lower.contains('think')) {
    return Colors.purple;
  }
  if (lower.contains('done') || lower.contains('ready')) {
    return Colors.green;
  }
  return theme.colorScheme.onSurfaceVariant;
}

class ChatStatusPill extends StatelessWidget {
  final String label;
  final bool isError;

  const ChatStatusPill({
    super.key,
    required this.label,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = chatStatusDotColor(theme, label, isError: isError);
    final isPulsing = chatStatusIsPulsing(label);

    final bg = Color.alphaBlend(
      color.withValues(alpha: 0.10),
      theme.colorScheme.surface,
    );
    final border = Color.alphaBlend(
      color.withValues(alpha: 0.32),
      theme.colorScheme.outlineVariant,
    );

    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.longPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProjectChatStatusDot(
              color: color,
              size: 8,
              enablePulse: isPulsing,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.95,
                    ),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ) ??
                  TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.95,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

