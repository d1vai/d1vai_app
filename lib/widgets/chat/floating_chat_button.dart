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

    return Positioned(
      bottom: 12,
      right: 12,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1500),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: (isDeploying || isWorking || isThinking)
                      ? AnimatedOpacity(
                          opacity: 0.0,
                          duration: const Duration(milliseconds: 750),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
