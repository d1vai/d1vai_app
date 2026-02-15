import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/analytics.dart';
import '../card.dart';

/// KPI card widget displaying key metrics
class MetricCard extends StatefulWidget {
  final RealtimeMetric metric;
  final VoidCallback? onTap;

  const MetricCard({super.key, required this.metric, this.onTap});

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _shineController;
  late final AnimationController _progressController;
  Animation<double> _progress = const AlwaysStoppedAnimation(0);

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
      duration: const Duration(milliseconds: 900),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _syncProgress();
  }

  @override
  void didUpdateWidget(covariant MetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metric.currentValue != widget.metric.currentValue ||
        oldWidget.metric.previousValue != widget.metric.previousValue) {
      _syncProgress();
    }
  }

  void _syncProgress() {
    final target = _getProgressValue(widget.metric);
    _progress = Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
    _progressController.forward(from: 0);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _shineController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final metric = widget.metric;
    final isPositive = metric.isPositiveTrend;
    final trendColor = isPositive ? colorScheme.primary : colorScheme.error;

    final scale = Tween<double>(
      begin: 1,
      end: 0.992,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));

    final surface = Color.alphaBlend(
      trendColor.withValues(alpha: isDark ? 0.07 : 0.04),
      colorScheme.surface,
    );

    return ScaleTransition(
      scale: scale,
      child: CustomCard(
        padding: EdgeInsets.zero,
        backgroundColor: surface,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    widget.onTap?.call();
                  },
            onTapDown: widget.onTap == null
                ? null
                : (_) {
                    _pressController.forward();
                    if (!_shineController.isAnimating) {
                      _shineController.forward(from: 0);
                    }
                  },
            onTapCancel: widget.onTap == null
                ? null
                : () => _pressController.reverse(),
            onTapUp: widget.onTap == null
                ? null
                : (_) => _pressController.reverse(),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              metric.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Color.alphaBlend(
                                trendColor.withValues(
                                  alpha: isDark ? 0.18 : 0.12,
                                ),
                                colorScheme.surface,
                              ),
                              border: Border.all(
                                color: trendColor.withValues(
                                  alpha: isDark ? 0.28 : 0.20,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: trendColor.withValues(
                                    alpha: isDark ? 0.20 : 0.10,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: trendColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            metric.currentValue.toStringAsFixed(2),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            metric.unit,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.9,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 16,
                            color: trendColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${metric.percentageChange.abs().toStringAsFixed(1)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: trendColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'vs previous period',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _progress.value,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                trendColor,
                              ),
                              minHeight: 6,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        metric.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.9,
                          ),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            trendColor.withValues(alpha: 0.65),
                            colorScheme.secondary.withValues(alpha: 0.28),
                            Colors.transparent,
                          ],
                        ),
                      ),
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
                        final opacity = (isDark ? 0.12 : 0.09) * (1 - t);
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

  double _getProgressValue(RealtimeMetric metric) {
    if (metric.previousValue == 0) {
      return metric.currentValue > 0 ? 1.0 : 0.0;
    }
    final ratio = metric.currentValue / metric.previousValue;
    return ratio.clamp(0.0, 1.0);
  }
}

/// Mini chart widget for showing metric trends
class MetricMiniChart extends StatelessWidget {
  final List<MetricDataPoint> data;
  final Color color;
  final double height;

  const MetricMiniChart({
    super.key,
    required this.data,
    required this.color,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _LineChartPainter(data: data, color: color),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<MetricDataPoint> data;
  final Color color;

  _LineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minValue = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final x = (i / (data.length - 1)) * size.width;
      final y = range > 0
          ? size.height - ((point.value - minValue) / range) * size.height
          : size.height / 2;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
