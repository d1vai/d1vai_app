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

    // Determine status dot color
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

    final bg = widget.isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final fg = widget.isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;
    final isDark = theme.brightness == Brightness.dark;
    final glowColor = widget.isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    final shadow = isDark
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
      child: AnimatedBuilder(
        animation: _pressScale,
        builder: (context, child) {
          final glow = isActive || _pressController.value > 0
              ? [
                  BoxShadow(
                    color: glowColor.withValues(
                      alpha: isDark
                          ? 0.16 + 0.08 * _pressController.value
                          : 0.08 + 0.06 * _pressController.value,
                    ),
                    blurRadius: isDark ? 18 : 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const <BoxShadow>[];

          return Transform.scale(
            scale: _pressScale.value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onPressed();
                },
                onTapDown: (_) => _pressController.forward(),
                onTapCancel: () => _pressController.reverse(),
                onTapUp: (_) => _pressController.reverse(),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [...shadow, ...glow],
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: isDark ? 0.72 : 0.65,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: isActive ? 0.14 : 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          offset: _pressController.value > 0
                              ? const Offset(0, -0.04)
                              : Offset.zero,
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: fg.withValues(alpha: 0.95),
                          ),
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
                            widget.statusLabel,
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
                        emphasized: _pressController.value > 0.01,
                      ),
                    ],
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
