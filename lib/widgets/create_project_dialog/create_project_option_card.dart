import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateProjectOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badgeText;
  final Color? badgeColor;
  final bool attention;

  const CreateProjectOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
    this.attention = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CreateProjectOptionCardAnimated(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      badgeText: badgeText,
      badgeColor: badgeColor,
      attention: attention,
    );
  }
}

class _CreateProjectOptionCardAnimated extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badgeText;
  final Color? badgeColor;
  final bool attention;

  const _CreateProjectOptionCardAnimated({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.badgeText,
    required this.badgeColor,
    required this.attention,
  });

  @override
  State<_CreateProjectOptionCardAnimated> createState() =>
      _CreateProjectOptionCardAnimatedState();
}

class _CreateProjectOptionCardAnimatedState
    extends State<_CreateProjectOptionCardAnimated>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _shineController;
  AnimationController? _breatheController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _syncBreatheController();
  }

  @override
  void didUpdateWidget(_CreateProjectOptionCardAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attention != widget.attention) {
      _syncBreatheController();
    }
  }

  void _syncBreatheController() {
    if (!widget.attention) {
      _breatheController?.dispose();
      _breatheController = null;
      return;
    }

    _breatheController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _shineController.dispose();
    _breatheController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final enabled = widget.onTap != null;
    final attention = widget.attention;
    final accent = widget.badgeColor ?? colorScheme.primary;

    final scale = Tween<double>(
      begin: 1,
      end: 0.992,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));

    final glowT = _breatheController?.value ?? 0.0;
    final borderColor = attention && enabled
        ? Color.alphaBlend(
            accent.withValues(alpha: isDark ? 0.32 : 0.22),
            colorScheme.outlineVariant,
          )
        : colorScheme.outlineVariant;
    final surface = colorScheme.surfaceContainerHighest.withValues(
      alpha: enabled ? 1 : 0.5,
    );
    final glowAlpha = attention && enabled
        ? (isDark ? 0.22 : 0.14) * (0.35 + 0.65 * glowT)
        : 0.0;

    return ScaleTransition(
      scale: scale,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onTap?.call();
                }
              : null,
          onTapDown: enabled
              ? (_) {
                  _pressController.forward();
                  if (!_shineController.isAnimating) {
                    _shineController.forward(from: 0);
                  }
                }
              : null,
          onTapCancel: enabled ? () => _pressController.reverse() : null,
          onTapUp: enabled ? (_) => _pressController.reverse() : null,
          child: Ink(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: attention && enabled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: glowAlpha),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            accent.withValues(alpha: 0.12),
                            colorScheme.surface,
                          ).withValues(alpha: enabled ? 1 : 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(
                              alpha: attention && enabled ? 0.22 : 0.14,
                            ),
                          ),
                        ),
                        child: Icon(widget.icon, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: enabled
                                          ? colorScheme.onSurface
                                          : colorScheme.onSurface.withValues(
                                              alpha: 0.6,
                                            ),
                                    ),
                                  ),
                                ),
                                if (widget.badgeText != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      widget.badgeText!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ],
                  ),
                ),
                if (attention && enabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _breatheController!,
                        builder: (context, _) {
                          final a =
                              (isDark ? 0.12 : 0.085) * (0.25 + 0.75 * glowT);
                          return Opacity(
                            opacity: a.clamp(0.0, 1.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(-0.4, -0.25),
                                  radius: 1.25,
                                  colors: [
                                    accent.withValues(alpha: 0.75),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, _) {
                        final t = Curves.easeOutCubic.transform(
                          _shineController.value,
                        );
                        final opacity = enabled ? (0.12 * (1 - t)) : 0.0;
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset((t - 0.5) * 260, 0),
                            child: Transform.rotate(
                              angle: -0.35,
                              child: Container(
                                width: 160,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.55),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
