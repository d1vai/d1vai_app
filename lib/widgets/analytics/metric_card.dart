import 'package:flutter/material.dart';
import '../../models/analytics.dart';

/// KPI card widget displaying key metrics
class MetricCard extends StatelessWidget {
  final RealtimeMetric metric;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.metric,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = metric.isPositiveTrend;
    final trendColor = isPositive ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
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
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    metric.unit,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: trendColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${metric.percentageChange.abs().toStringAsFixed(1)}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: trendColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'vs previous period',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _getProgressValue(),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(trendColor),
                minHeight: 4,
              ),
              const SizedBox(height: 8),
              Text(
                metric.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getProgressValue() {
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
        painter: _LineChartPainter(
          data: data,
          color: color,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<MetricDataPoint> data;
  final Color color;

  _LineChartPainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final maxValue = data
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);
    final minValue = data
        .map((e) => e.value)
        .reduce((a, b) => a < b ? a : b);
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
