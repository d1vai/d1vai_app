import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating chat button for mobile devices
/// Shows current chat status and opens bottom sheet when tapped
class FloatingChatButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String statusLabel;
  final bool isError;
  final bool isDone;
  final bool isWorking;
  final bool isThinking;
  final bool isDeploying;
  final String? secondaryLabel;

  const FloatingChatButton({
    super.key,
    required this.onPressed,
    required this.statusLabel,
    this.isError = false,
    this.isDone = false,
    this.isWorking = false,
    this.isThinking = false,
    this.isDeploying = false,
    this.secondaryLabel,
  });

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive =
        widget.isDeploying || widget.isWorking || widget.isThinking;
    Color statusColor;
    if (widget.isDeploying || widget.isWorking || widget.isThinking) {
      statusColor = widget.isDeploying
          ? (theme.brightness == Brightness.dark
                ? Colors.amber.shade300
                : Colors.amber.shade500)
          : widget.isThinking
          ? Colors.blue.shade500
          : theme.colorScheme.primary;
    } else if (widget.isError) {
      statusColor = theme.colorScheme.error;
    } else if (widget.isDone) {
      statusColor = Colors.green;
    } else {
      statusColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    }

    final background = widget.isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primary;
    final foreground = widget.isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimary;

    return Semantics(
      button: true,
      label: 'Open chat, ${widget.statusLabel}',
      child: AnimatedBuilder(
        animation: _pressScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _pressScale.value,
            child: Tooltip(
              message: widget.statusLabel,
              child: Material(
                color: background,
                elevation: 5,
                shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onPressed();
                  },
                  onTapDown: (_) => _pressController.forward(),
                  onTapCancel: () => _pressController.reverse(),
                  onTapUp: (_) => _pressController.reverse(),
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 23,
                          color: foreground,
                        ),
                        Positioned(
                          top: -5,
                          right: -5,
                          child: _StatusDot(
                            color: statusColor,
                            background: theme.colorScheme.surface,
                            pulsing: isActive,
                            emphasized: _pressController.value > 0.01,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final Color background;
  final bool pulsing;
  final bool emphasized;

  const _StatusDot({
    required this.color,
    required this.background,
    required this.pulsing,
    this.emphasized = false,
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
          width: emphasized ? 15 : 14,
          height: emphasized ? 15 : 14,
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
