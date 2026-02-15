import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:d1vai_app/models/analytics.dart';
import 'package:d1vai_app/services/analytics_service.dart';
import 'package:d1vai_app/widgets/analytics/metric_card.dart';
import 'package:d1vai_app/widgets/analytics/realtime_chart.dart';
import 'package:d1vai_app/widgets/snackbar_helper.dart';

/// Real-time analytics dashboard screen
class RealtimeAnalyticsScreen extends StatefulWidget {
  final String projectId;

  const RealtimeAnalyticsScreen({super.key, required this.projectId});

  @override
  State<RealtimeAnalyticsScreen> createState() =>
      _RealtimeAnalyticsScreenState();
}

class _RealtimeAnalyticsScreenState extends State<RealtimeAnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  late StreamSubscription<List<RealtimeMetric>> _metricsSubscription;

  TimeRange _selectedTimeRange = TimeRange.last24Hours;
  AnalyticsSummary? _summary;
  List<RealtimeMetric> _metrics = [];
  List<ChartSeries> _chartSeries = [];
  List<GeographicData> _geographicData = [];
  bool _isLoading = true;
  bool _isRealTimeEnabled = true;
  bool _isLoadingGeographic = false;
  bool _dismissedAnomalyCard = false;

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

      // Load geographic data
      await _loadGeographicData();

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
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to load analytics: $e',
      );
    }
  }

  /// Load geographic data
  Future<void> _loadGeographicData() async {
    setState(() {
      _isLoadingGeographic = true;
    });

    try {
      final data = await _analyticsService.getGeographicData(
        projectId: widget.projectId,
        timeRange: _selectedTimeRange,
      );

      if (!mounted) return;

      setState(() {
        _geographicData = data;
        _isLoadingGeographic = false;
      });
    } catch (e) {
      // Silently fail for geographic data as it's not critical
      debugPrint('Failed to load geographic data: $e');
      if (!mounted) return;
      setState(() {
        _geographicData = [];
        _isLoadingGeographic = false;
      });
    }
  }

  /// Setup real-time data stream
  void _setupRealtimeStream() {
    _metricsSubscription = _analyticsService.metricsStream.listen((metrics) {
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _chartSeries = _createChartSeries(metrics);
        });
      }
    });

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

      // Open download URL
      final uri = Uri.tryParse(downloadUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Download URL: $downloadUrl');
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to export: $e',
      );
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
              const PopupMenuItem(value: 'json', child: Text('Export as JSON')),
              const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
              const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(onRefresh: _loadData, child: _buildContent()),
    );
  }

  Widget _buildLoadingState() {
    return _buildShimmer();
  }

  Widget _buildContent() {
    final anomalies = _detectAnomalies();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Time range selector
        _buildTimeRangeSelector(),
        const SizedBox(height: 16),
        // Real-time indicator
        _buildRealtimeIndicator(),
        if (!_dismissedAnomalyCard && anomalies.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildAnomalyCard(anomalies),
        ],
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
              items: TimeRange.values.map<DropdownMenuItem<TimeRange>>((
                TimeRange value,
              ) {
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

  List<_RealtimeAnomaly> _detectAnomalies() {
    final out = <_RealtimeAnomaly>[];
    for (final m in _metrics) {
      final name = m.name.toLowerCase();
      final change = m.percentageChange;

      // Heuristics: flag large jumps. Use name hints when possible.
      final isErrorish = name.contains('error') || name.contains('fail');
      final isLatencyish =
          name.contains('latency') || name.contains('response');

      if (isErrorish &&
          m.currentValue > 0 &&
          (change >= 50 || m.currentValue >= m.previousValue * 2)) {
        out.add(
          _RealtimeAnomaly(
            title: 'Error spike',
            detail:
                '${m.name}: ${m.currentValue.toStringAsFixed(2)}${m.unit} (was ${m.previousValue.toStringAsFixed(2)}${m.unit})',
            color: Colors.red,
            icon: Icons.error_outline,
          ),
        );
        continue;
      }

      if (isLatencyish &&
          m.currentValue > 0 &&
          (change >= 50 || m.currentValue >= m.previousValue * 2)) {
        out.add(
          _RealtimeAnomaly(
            title: 'Latency spike',
            detail:
                '${m.name}: ${m.currentValue.toStringAsFixed(2)}${m.unit} (was ${m.previousValue.toStringAsFixed(2)}${m.unit})',
            color: Colors.orange,
            icon: Icons.timelapse,
          ),
        );
        continue;
      }

      if (m.currentValue > 0 && change.abs() >= 120) {
        out.add(
          _RealtimeAnomaly(
            title: 'Unusual change',
            detail:
                '${m.name}: ${m.currentValue.toStringAsFixed(2)}${m.unit} (${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%)',
            color: Colors.purple,
            icon: Icons.insights,
          ),
        );
      }
    }
    return out.take(3).toList(growable: false);
  }

  Widget _buildAnomalyCard(List<_RealtimeAnomaly> anomalies) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final prompt = anomalies.map((a) => '- ${a.title}: ${a.detail}').join('\n');

    return Card(
      color: cs.errorContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: cs.error),
                const SizedBox(width: 8),
                Text(
                  'Anomaly detected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _dismissedAnomalyCard = true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final a in anomalies) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(a.icon, size: 16, color: a.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${a.title}: ${a.detail}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/projects/${widget.projectId}?tab=deploy'),
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Deploy logs'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/projects/${widget.projectId}?tab=api'),
                  icon: const Icon(Icons.api, size: 18),
                  label: const Text('Env vars'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/projects/${widget.projectId}/chat?autoprompt=${Uri.encodeQueryComponent("My realtime analytics shows anomalies:\\n$prompt\\n\\nPlease help me debug step-by-step and propose fixes.")}',
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Ask AI'),
                ),
              ],
            ),
          ],
        ),
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
            _showMetricDetail(metric);
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const Text(
                    'Comparison chart will appear here',
                    style: TextStyle(color: Colors.grey),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: _isLoadingGeographic
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isLoadingGeographic
                      ? null
                      : () {
                          _loadGeographicData();
                        },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Show geographic data list or empty state
            if (_geographicData.isEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.public_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No geographic data available',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _geographicData.length,
                itemBuilder: (context, index) {
                  final data = _geographicData[index];
                  final percentage = _geographicData.isNotEmpty
                      ? (data.value /
                            _geographicData.fold<int>(
                              0,
                              (sum, item) => sum + item.value,
                            ) *
                            100)
                      : 0.0;

                  return _buildGeographicItem(data, percentage);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Build geographic data item
  Widget _buildGeographicItem(GeographicData data, double percentage) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Country flag emoji (simple representation)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              _getFlagEmoji(data.countryCode),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Country info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.country,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${data.value} visits',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Progress bar showing percentage
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage / 100,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${percentage.toStringAsFixed(1)}% of total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get flag emoji from country code
  String _getFlagEmoji(String countryCode) {
    if (countryCode.isEmpty) return '🌍';

    // Convert ASCII country code to regional indicator symbols
    String flag = '';
    for (int i = 0; i < countryCode.length; i++) {
      final code = countryCode.codeUnitAt(i);
      // Convert 'A' (65) to regional indicator '🇦' (0x1F1E6)
      flag += String.fromCharCode(0x1F1E6 + (code - 65));
    }
    return flag;
  }

  /// 显示指标详情
  void _showMetricDetail(RealtimeMetric metric) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${metric.name} Details',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow(
                  'Current Value',
                  '${metric.currentValue} ${metric.unit}',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Change',
                  '${metric.percentageChange >= 0 ? '+' : ''}${metric.percentageChange.toStringAsFixed(2)}%',
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Description', metric.description),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Last Updated',
                  '${metric.lastUpdated.year}-${metric.lastUpdated.month.toString().padLeft(2, '0')}-${metric.lastUpdated.day.toString().padLeft(2, '0')} ${metric.lastUpdated.hour.toString().padLeft(2, '0')}:${metric.lastUpdated.minute.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// 构建骨架屏加载效果
  Widget _buildShimmer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[600]! : Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI 卡片行
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.3,
              children: List.generate(4, (index) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // 图表区域
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 24),

            // 地理分布区域
            Container(
              width: double.infinity,
              height: 350,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RealtimeAnomaly {
  final String title;
  final String detail;
  final Color color;
  final IconData icon;

  const _RealtimeAnomaly({
    required this.title,
    required this.detail,
    required this.color,
    required this.icon,
  });
}
