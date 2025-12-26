import 'package:flutter/material.dart';

/// Floating chat button for mobile devices
/// Shows current chat status and opens bottom sheet when tapped
class FloatingChatButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String statusLabel;
  final bool isError;
  final bool isDone;
  final bool isWorking;
  final bool isThinking;
  final bool isDeploying;

  const FloatingChatButton({
    super.key,
    required this.onPressed,
    required this.statusLabel,
    this.isError = false,
    this.isDone = false,
    this.isWorking = false,
    this.isThinking = false,
    this.isDeploying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = isDeploying || isWorking || isThinking;

    // Determine status dot color
    Color statusColor;
    if (isDeploying || isWorking || isThinking) {
      statusColor = isDeploying
          ? (theme.brightness == Brightness.dark
                ? Colors.amber.shade300
                : Colors.amber.shade500)
          : isThinking
          ? Colors.blue.shade500
          : theme.colorScheme.primary;
    } else if (isError) {
      statusColor = theme.colorScheme.error;
    } else if (isDone) {
      statusColor = Colors.green;
    } else {
      statusColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    }

    final bg = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final fg = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    final shadow = theme.brightness == Brightness.dark
        ? <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ]
        : <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ];

    return Semantics(
      button: true,
      label: 'Open chat',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              boxShadow: shadow,
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: fg.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: fg.withValues(alpha: 0.95),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                _StatusDot(
                  color: statusColor,
                  background: fg.withValues(alpha: 0.10),
                  pulsing: isActive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final Color background;
  final bool pulsing;

  const _StatusDot({
    required this.color,
    required this.background,
    required this.pulsing,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: pulsing ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        final ring = pulsing ? (0.15 + 0.25 * t) : 0.0;
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: pulsing ? 0.55 : 0.85),
              width: 1,
            ),
            boxShadow: ring > 0
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: ring),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}
