import 'package:flutter/material.dart';
import '../../models/analytics.dart';

/// Real-time line chart widget
class RealtimeChart extends StatefulWidget {
  final String title;
  final List<ChartSeries> series;
  final TimeRange timeRange;
  final double height;
  final bool showLegend;
  final bool showGrid;
  final ValueChanged<TimeRange>? onTimeRangeChanged;

  const RealtimeChart({
    super.key,
    required this.title,
    required this.series,
    this.timeRange = TimeRange.last24Hours,
    this.height = 300,
    this.showLegend = true,
    this.showGrid = true,
    this.onTimeRangeChanged,
  });

  @override
  State<RealtimeChart> createState() => _RealtimeChartState();
}

class _RealtimeChartState extends State<RealtimeChart> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                DropdownButton<TimeRange>(
                  value: widget.timeRange,
                  icon: const Icon(Icons.arrow_drop_down),
                  elevation: 16,
                  style: theme.textTheme.bodyMedium,
                  underline: Container(
                    height: 0,
                  ),
                  onChanged: (TimeRange? newValue) {
                    if (newValue != null && widget.onTimeRangeChanged != null) {
                      widget.onTimeRangeChanged!(newValue);
                    }
                  },
                  items: TimeRange.values
                      .map<DropdownMenuItem<TimeRange>>((TimeRange value) {
                    return DropdownMenuItem<TimeRange>(
                      value: value,
                      child: Text(value.label),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Chart area
            Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildChart(theme),
            ),
            // Legend
            if (widget.showLegend && widget.series.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildLegend(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChart(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _LineChartPainter(
            series: widget.series,
            showGrid: widget.showGrid,
            gridColor: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          child: GestureDetector(
            onTapDown: (details) {
              // Handle chart tap
            },
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: widget.series.map((series) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: series.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              series.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartSeries> series;
  final bool showGrid;
  final Color gridColor;

  _LineChartPainter({
    required this.series,
    required this.showGrid,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw grid if enabled
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // Find global min and max values
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;

    for (final series in series) {
      for (final point in series.data) {
        if (point.value < globalMin) globalMin = point.value;
        if (point.value > globalMax) globalMax = point.value;
      }
    }

    // Draw each series
    for (final series in series) {
      final path = Path();
      paint.color = series.color;

      for (int i = 0; i < series.data.length; i++) {
        final point = series.data[i];
        final x = (i / (series.data.length - 1)) * size.width;
        final y = globalMax > globalMin
            ? size.height -
                ((point.value - globalMin) / (globalMax - globalMin)) *
                    size.height
            : size.height / 2;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Draw horizontal lines
    for (int i = 1; i < 5; i++) {
      final y = (size.height / 5) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw vertical lines
    for (int i = 1; i < 5; i++) {
      final x = (size.width / 5) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Comparison bar chart
class ComparisonChart extends StatelessWidget {
  final List<ComparisonData> data;
  final String title;
  final double height;

  const ComparisonChart({
    super.key,
    required this.data,
    required this.title,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = data.fold<double>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((item) {
                  final barHeight = maxValue > 0
                      ? (item.value / maxValue) * (height - 40)
                      : 0.0;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Value label
                        Text(
                          item.value.toStringAsFixed(2),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        // Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Label
                        Text(
                          item.label,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
