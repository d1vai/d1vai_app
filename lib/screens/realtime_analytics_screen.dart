import 'dart:async';
import 'package:flutter/material.dart';
import '../models/analytics.dart';
import '../services/analytics_service.dart';
import '../widgets/analytics/metric_card.dart';
import '../widgets/analytics/realtime_chart.dart';
import '../widgets/snackbar_helper.dart';

/// Real-time analytics dashboard screen
class RealtimeAnalyticsScreen extends StatefulWidget {
  final String projectId;

  const RealtimeAnalyticsScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<RealtimeAnalyticsScreen> createState() =>
      _RealtimeAnalyticsScreenState();
}

class _RealtimeAnalyticsScreenState
    extends State<RealtimeAnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  late StreamSubscription<List<RealtimeMetric>> _metricsSubscription;

  TimeRange _selectedTimeRange = TimeRange.last24Hours;
  AnalyticsSummary? _summary;
  List<RealtimeMetric> _metrics = [];
  List<ChartSeries> _chartSeries = [];
  bool _isLoading = true;
  bool _isRealTimeEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeStream();
  }

  @override
  void dispose() {
    _metricsSubscription.cancel();
    _analyticsService.stopRealtimeStream();
    super.dispose();
  }

  /// Load initial analytics data
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load analytics summary
      final summary = await _analyticsService.getAnalyticsSummary(
        projectId: widget.projectId,
        timeRange: _selectedTimeRange,
      );

      // Load real-time metrics
      final metrics = await _analyticsService.getRealtimeMetrics(
        projectId: widget.projectId,
      );

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _metrics = metrics;
        _chartSeries = _createChartSeries(metrics);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      SnackBarHelper.showError(context, title: 'Error', message: 'Failed to load analytics: $e');
    }
  }

  /// Setup real-time data stream
  void _setupRealtimeStream() {
    _metricsSubscription = _analyticsService.metricsStream.listen(
      (metrics) {
        if (mounted) {
          setState(() {
            _metrics = metrics;
            _chartSeries = _createChartSeries(metrics);
          });
        }
      },
    );

    // Start real-time updates
    _analyticsService.startRealtimeStream(
      projectId: widget.projectId,
      interval: const Duration(seconds: 5),
    );
  }

  /// Create chart series from metrics
  List<ChartSeries> _createChartSeries(List<RealtimeMetric> metrics) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    return metrics.asMap().entries.map((entry) {
      final index = entry.key;
      final metric = entry.value;
      return ChartSeries(
        name: metric.name,
        data: metric.data,
        color: colors[index % colors.length],
      );
    }).toList();
  }

  /// Toggle real-time updates
  void _toggleRealtime() {
    setState(() {
      _isRealTimeEnabled = !_isRealTimeEnabled;
    });

    if (_isRealTimeEnabled) {
      _analyticsService.startRealtimeStream(
        projectId: widget.projectId,
        interval: const Duration(seconds: 5),
      );
    } else {
      _analyticsService.stopRealtimeStream();
    }
  }

  /// Export analytics data
  Future<void> _exportData(String format) async {
    try {
      final downloadUrl = await _analyticsService.exportAnalytics(
        projectId: widget.projectId,
        format: format,
        timeRange: _selectedTimeRange,
      );

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Export started. Download will begin shortly.',
      );

      // TODO: Open download URL
      debugPrint('Download URL: $downloadUrl');
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, title: 'Error', message: 'Failed to export: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Analytics'),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isRealTimeEnabled ? Icons.pause : Icons.play_arrow,
                key: ValueKey(_isRealTimeEnabled),
              ),
            ),
            onPressed: _toggleRealtime,
            tooltip: _isRealTimeEnabled ? 'Pause' : 'Resume',
          ),
          PopupMenuButton<String>(
            onSelected: _exportData,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'json',
                child: Text('Export as JSON'),
              ),
              const PopupMenuItem(
                value: 'csv',
                child: Text('Export as CSV'),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Text('Export as PDF'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(),
            ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Time range selector
        _buildTimeRangeSelector(),
        const SizedBox(height: 16),
        // Real-time indicator
        _buildRealtimeIndicator(),
        const SizedBox(height: 24),
        // Summary cards
        if (_summary != null) ...[
          _buildSummaryCards(),
          const SizedBox(height: 16),
        ],
        // Metric cards
        _buildMetricCards(),
        const SizedBox(height: 24),
        // Charts
        if (_chartSeries.isNotEmpty) ...[
          _buildCharts(),
          const SizedBox(height: 24),
        ],
        // Geographic data placeholder
        _buildGeographicSection(),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Time Range:'),
            DropdownButton<TimeRange>(
              value: _selectedTimeRange,
              icon: const Icon(Icons.arrow_drop_down),
              elevation: 16,
              underline: Container(),
              onChanged: (TimeRange? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedTimeRange = newValue;
                  });
                  _loadData();
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
      ),
    );
  }

  Widget _buildRealtimeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isRealTimeEnabled
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isRealTimeEnabled
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              Icons.circle,
              key: ValueKey(_isRealTimeEnabled),
              size: 12,
              color: _isRealTimeEnabled ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isRealTimeEnabled ? 'Live Updates' : 'Paused',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_summary == null) return const SizedBox.shrink();

    final cards = [
      KPICard(
        title: 'Total Users',
        value: _summary!.totalUsers.toString(),
        subtitle: '${_summary!.activeUsers} active',
        icon: Icons.people,
        color: Colors.blue,
        trend: Trend.up,
      ),
      KPICard(
        title: 'Requests',
        value: _summary!.totalRequests.toString(),
        subtitle: '${_summary!.successfulRequests} successful',
        icon: Icons.http,
        color: Colors.green,
        trend: Trend.up,
      ),
      KPICard(
        title: 'Avg Response',
        value: '${_summary!.averageResponseTime.toStringAsFixed(0)}ms',
        subtitle: 'Average time',
        icon: Icons.speed,
        color: Colors.orange,
        trend: Trend.stable,
      ),
      KPICard(
        title: 'Uptime',
        value: '${(_summary!.uptime * 100).toStringAsFixed(2)}%',
        subtitle: 'Last ${_selectedTimeRange.label}',
        icon: Icons.check_circle,
        color: Colors.purple,
        trend: Trend.up,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _buildKPICard(card);
      },
    );
  }

  Widget _buildKPICard(KPICard card) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(card.icon, color: card.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              card.value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCards() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _metrics.length,
      itemBuilder: (context, index) {
        final metric = _metrics[index];
        return MetricCard(
          metric: metric,
          onTap: () {
            // TODO: Navigate to metric detail
          },
        );
      },
    );
  }

  Widget _buildCharts() {
    return Column(
      children: [
        RealtimeChart(
          title: 'Performance Metrics',
          series: _chartSeries,
          timeRange: _selectedTimeRange,
          onTimeRangeChanged: (timeRange) {
            setState(() {
              _selectedTimeRange = timeRange;
            });
            _loadData();
          },
        ),
        const SizedBox(height: 16),
        // Placeholder for comparison chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Metric Comparison',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const Text(
                    'Comparison chart will appear here',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeographicSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Geographic Distribution',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () {
                    // TODO: Navigate to world map screen
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                'World map visualization will appear here',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
