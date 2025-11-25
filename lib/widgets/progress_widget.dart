import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ProgressWidget - A linear progress with dynamic tips control
class ProgressWidget extends StatefulWidget {
  final List<String>? tipList;
  final bool completed;
  final VoidCallback? onDone;
  final double width;

  const ProgressWidget({
    super.key,
    this.tipList,
    this.completed = false,
    this.onDone,
    this.width = double.infinity,
  });

  @override
  State<ProgressWidget> createState() => _ProgressWidgetState();
}

class _ProgressWidgetState extends State<ProgressWidget>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showFireworks = false;
  int _tipIndex = 0;

  List<String> get tips =>
      widget.tipList != null && widget.tipList!.isNotEmpty
          ? widget.tipList!
          : ['Starting…', 'Working…', 'Finalizing…'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    if (!widget.completed) {
      _startProgressAnimation();
    }
  }

  @override
  void didUpdateWidget(ProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.completed != widget.completed && widget.completed) {
      _onCompleted();
    }
  }

  void _startProgressAnimation() {
    // Animate progress through different phases
    _animateProgress(0, 30, const Duration(seconds: 6));
  }

  void _animateProgress(double from, double to, Duration duration) {
    Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!mounted || widget.completed) {
        timer.cancel();
        return;
      }

      final elapsed = timer.tick * 16;
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = _easeInOut(t);

      setState(() {
        _progress = from + (to - from) * eased;

        // Update tip based on progress
        if (tips.length <= 1) {
          _tipIndex = 0;
        } else if (tips.length == 2) {
          _tipIndex = _progress < 30 ? 0 : 1;
        } else {
          if (_progress < 30) {
            _tipIndex = 0;
          } else if (_progress < 89) {
            _tipIndex = 1;
          } else {
            _tipIndex = math.min(tips.length - 1, 2);
          }
        }
      });

      if (t >= 1.0) {
        timer.cancel();

        // Continue to next phase or hold at 89%
        if (to == 30) {
          _animateProgress(30, 89, const Duration(seconds: 3));
        } else if (to < 89) {
          _animateProgress(to, 89, const Duration(seconds: 3));
        }
        // If we reached 89%, stop here until completed
      }
    });
  }

  double _easeInOut(double t) {
    return t < 0.5 ? 2 * t * t : 1 - (2 * (1 - t) * (1 - t));
  }

  void _onCompleted() {
    // First animate to 89% if not already there
    if (_progress < 89) {
      _animateProgress(_progress, 89, const Duration(milliseconds: 500));
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _animateTo100();
      });
    } else {
      _animateTo100();
    }
  }

  void _animateTo100() {
    final start = _progress;
    const duration = Duration(milliseconds: 450);

    Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final elapsed = timer.tick * 16;
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = 1 - (1 - t) * (1 - t) * (1 - t); // Ease out cubic

      setState(() {
        _progress = start + (100 - start) * eased;
      });

      if (t >= 1.0) {
        timer.cancel();
        setState(() {
          _showFireworks = true;
        });
        _animationController.forward();

        Timer(const Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            _showFireworks = false;
          });
          widget.onDone?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: widget.width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with tip and percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    tips[_tipIndex],
                    key: ValueKey(_tipIndex),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              Text(
                '${_progress.floor()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFeatures: [
                    const FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: (widget.width == double.infinity
                        ? widget.width
                        : widget.width * (_progress / 100)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Fireworks animation on completion
          if (_showFireworks) ...[
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: SizedBox(
                    height: 30,
                    width: 100,
                    child: Stack(
                      children: List.generate(10, (index) {
                        final angle = (index / 10) * 3.14159 * 2;
                        final radius = 12 + (index % 3) * 6;
                        final x = 50 + (angle == 0 ? 0 : 0) + (angle > 0 && angle < 3.14159 ? radius : -radius * 0.5);
                        final y = 15 + (angle < 3.14159 ? -radius * 0.3 : radius * 0.5);

                        final colors = [
                          Colors.red.shade500,
                          Colors.yellow.shade400,
                          Colors.green.shade500,
                          Colors.blue.shade500,
                          Colors.pink.shade500,
                          Colors.purple.shade500,
                        ];

                        return Positioned(
                          left: x.toDouble(),
                          top: y.toDouble(),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 800),
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              shape: BoxShape.circle,
                            ),
                            width: 6,
                            height: 6,
                            child: const Icon(
                              Icons.star,
                              size: 4,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
