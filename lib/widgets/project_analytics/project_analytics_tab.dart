import 'package:flutter/material.dart';

import '../../models/analytics.dart';
import '../../services/analytics_service.dart';
import '../analytics/realtime_chart.dart';

/// 项目详情页 - Analytics Tab
class ProjectAnalyticsTab extends StatefulWidget {
  final String projectId;
  final void Function(String prompt)? onAskAi;

  const ProjectAnalyticsTab({
    super.key,
    required this.projectId,
    this.onAskAi,
  });

  @override
  State<ProjectAnalyticsTab> createState() => _ProjectAnalyticsTabState();
}

class _ProjectAnalyticsTabState extends State<ProjectAnalyticsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  AnalyticsSummary? _summary;
  List<ChartSeries> _chartSeries = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  TimeRange _timeRange = TimeRange.last24Hours;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load summary and metrics in parallel
      final results = await Future.wait([
        _analyticsService.getAnalyticsSummary(
          projectId: widget.projectId,
          timeRange: _timeRange,
        ),
        _analyticsService.getRealtimeMetrics(
          projectId: widget.projectId,
        ),
      ]);

      if (!mounted) return;

      final summary = results[0] as AnalyticsSummary;
      final metrics = results[1] as List<RealtimeMetric>;

      setState(() {
        _summary = summary;
        _chartSeries = _createChartSeries(metrics);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading analytics: $e');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No analytics data',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Analytics data will appear here once your project is live',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final analytics = _summary!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodCard(analytics),
          const SizedBox(height: 16),
          if (_chartSeries.isNotEmpty) ...[
            RealtimeChart(
              title: 'Performance Overview',
              series: _chartSeries,
              timeRange: _timeRange,
              height: 250,
              showLegend: true,
              onTimeRangeChanged: (range) {
                setState(() {
                  _timeRange = range;
                });
                _loadAnalytics();
              },
            ),
            const SizedBox(height: 16),
          ],
          _buildKeyMetricsRow(analytics),
          const SizedBox(height: 16),
          _buildStatusCard(analytics),
          const SizedBox(height: 16),
          _buildActionsCard(),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(AnalyticsSummary analytics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.deepPurple, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Period: ${_timeRange.label}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From ${analytics.startDate.toLocal()} to ${analytics.endDate.toLocal()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsRow(AnalyticsSummary analytics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Total Requests',
                value: analytics.totalRequests.toString(),
                icon: Icons.swap_vert,
                color: Colors.blue,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze the "Total Requests" metric for my project and provide insights on what it means and how to improve it?',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Avg Response',
                value: '${analytics.averageResponseTime.toStringAsFixed(0)}ms',
                icon: Icons.speed,
                color: Colors.purple,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze the "Average Response Time" metric for my project and provide insights on what it means and how to improve it?',
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Uptime',
                value: '${(analytics.uptime * 100).toStringAsFixed(1)}%',
                icon: Icons.check_circle,
                color: Colors.teal,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze the "Uptime" metric for my project and provide insights on what it means and how to improve it?',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Success Rate',
                value:
                    '${((analytics.successfulRequests / analytics.totalRequests) * 100).toStringAsFixed(1)}%',
                icon: Icons.thumb_up,
                color: Colors.indigo,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze the "Success Rate" metric for my project and provide insights on what it means and how to improve it?',
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(AnalyticsSummary analytics) {
    final errorRate = analytics.totalRequests == 0
        ? 0.0
        : (analytics.failedRequests / analytics.totalRequests) * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Users',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${analytics.activeUsers}/${analytics.totalUsers} active',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Errors',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${analytics.failedRequests} (${errorRate.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.blue),
              title: const Text('View Detailed Dashboard'),
              subtitle: const Text('See comprehensive analytics'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                widget.onAskAi?.call(
                  'Can you help me understand my analytics data and suggest ways to improve user engagement, performance, and overall metrics?',
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.track_changes, color: Colors.orange),
              title: const Text('Track Custom Events'),
              subtitle: const Text('Add custom tracking'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                widget.onAskAi?.call(
                  'Can you guide me on setting up custom event tracking for my project? What are the most important events I should track to improve my product?',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _AnalyticsMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}
