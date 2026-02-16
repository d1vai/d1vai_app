import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:async';
import '../models/analytics.dart';
import '../core/api_client.dart';

/// Service for managing real-time analytics data
class AnalyticsService {
  final ApiClient _apiClient;
  final StreamController<List<RealtimeMetric>> _metricsController =
      StreamController.broadcast();
  final StreamController<StreamData> _streamController =
      StreamController.broadcast();
  Timer? _realtimeTimer;

  AnalyticsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Stream of real-time metrics
  Stream<List<RealtimeMetric>> get metricsStream => _metricsController.stream;

  /// Stream of real-time metric data
  Stream<StreamData> get streamData => _streamController.stream;

  Map<String, int> _rangeBounds(TimeRange range) {
    final end = DateTime.now();
    final start = end.subtract(range.duration);
    return {
      'startAt': start.millisecondsSinceEpoch,
      'endAt': end.millisecondsSinceEpoch,
    };
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  List<MetricDataPoint> _parseSeries(dynamic raw) {
    if (raw is! List) return const [];
    final out = <MetricDataPoint>[];
    for (final it in raw) {
      if (it is! Map) continue;
      final x = it['x'] ?? it['t'];
      final y = it['y'] ?? it['value'];
      DateTime? ts;
      if (x is int) {
        ts = DateTime.fromMillisecondsSinceEpoch(x);
      } else if (x is num) {
        ts = DateTime.fromMillisecondsSinceEpoch(x.toInt());
      } else if (x is String && x.trim().isNotEmpty) {
        ts = DateTime.tryParse(x.trim());
      }
      out.add(
        MetricDataPoint(
          timestamp: ts ?? DateTime.now(),
          value: _asDouble(y),
          label: x?.toString(),
        ),
      );
    }
    return out;
  }

  /// Get analytics summary for a project
  Future<AnalyticsSummary> getAnalyticsSummary({
    required String projectId,
    TimeRange timeRange = TimeRange.last24Hours,
  }) async {
    try {
      final range = _rangeBounds(timeRange);
      final startAt = range['startAt']!;
      final endAt = range['endAt']!;

      final results = await Future.wait([
        _apiClient.get<Map<String, dynamic>>(
          '/api/analytics/data/$projectId/website/values',
          queryParams: {
            'startAt': startAt.toString(),
            'endAt': endAt.toString(),
          },
        ),
        _apiClient.get<Map<String, dynamic>>(
          '/api/analytics/data/$projectId/website/active',
        ),
        _apiClient.get<Map<String, dynamic>>(
          '/api/analytics/data/$projectId/pageviews',
          queryParams: {
            'unit': 'hour',
            'timezone': 'UTC',
            'startAt': startAt.toString(),
            'endAt': endAt.toString(),
          },
        ),
      ]);

      final values = results[0];
      final active = results[1];
      final pageviews = results[2];
      final pageviewsSeries = _parseSeries(pageviews['pageviews']);
      final sessionsSeries = _parseSeries(pageviews['sessions']);
      final totalPageviews = pageviewsSeries.fold<double>(
        0,
        (sum, p) => sum + p.value,
      );
      final totalSessions = sessionsSeries.fold<double>(
        0,
        (sum, p) => sum + p.value,
      );
      final activeUsers = _asInt(active['x'] ?? active['visitors']);

      final metrics = <RealtimeMetric>[
        RealtimeMetric(
          id: 'pageviews',
          name: 'Pageviews',
          description: 'Total pageviews in selected range',
          unit: 'count',
          currentValue: totalPageviews,
          previousValue: 0,
          data: pageviewsSeries,
          type: MetricType.counter,
          lastUpdated: DateTime.now(),
        ),
        RealtimeMetric(
          id: 'sessions',
          name: 'Sessions',
          description: 'Total sessions in selected range',
          unit: 'count',
          currentValue: totalSessions,
          previousValue: 0,
          data: sessionsSeries,
          type: MetricType.counter,
          lastUpdated: DateTime.now(),
        ),
        RealtimeMetric(
          id: 'active_users',
          name: 'Active Users',
          description: 'Current active users',
          unit: 'count',
          currentValue: activeUsers.toDouble(),
          previousValue: 0,
          data: [
            MetricDataPoint(
              timestamp: DateTime.now(),
              value: activeUsers.toDouble(),
              label: 'now',
            ),
          ],
          type: MetricType.gauge,
          lastUpdated: DateTime.now(),
        ),
      ];

      return AnalyticsSummary(
        projectId: projectId,
        period: timeRange.name,
        startDate: DateTime.fromMillisecondsSinceEpoch(startAt),
        endDate: DateTime.fromMillisecondsSinceEpoch(endAt),
        totalUsers: _asInt(values['visitors'] ?? values['users']),
        activeUsers: activeUsers,
        totalRequests: totalPageviews.toInt(),
        successfulRequests: totalPageviews.toInt(),
        failedRequests: 0,
        averageResponseTime: 0,
        uptime: 100,
        customMetrics: {
          'sessions': totalSessions.toInt(),
          'bounces': _asInt(values['bounces']),
          'totaltime': _asInt(values['totaltime'] ?? values['totalTime']),
        },
        metrics: metrics,
      );
    } catch (e) {
      throw AnalyticsException('Failed to get analytics summary: $e');
    }
  }

  /// Get real-time metrics for a project
  Future<List<RealtimeMetric>> getRealtimeMetrics({
    required String projectId,
    List<String>? metricIds,
  }) async {
    try {
      final range = _rangeBounds(TimeRange.last24Hours);
      final startAt = range['startAt']!;
      final endAt = range['endAt']!;
      final results = await Future.wait([
        _apiClient.get<Map<String, dynamic>>(
          '/api/analytics/data/$projectId/pageviews',
          queryParams: {
            'unit': 'hour',
            'timezone': 'UTC',
            'startAt': startAt.toString(),
            'endAt': endAt.toString(),
          },
        ),
        _apiClient.get<Map<String, dynamic>>(
          '/api/analytics/data/$projectId/website/active',
        ),
      ]);

      final pageviews = results[0];
      final active = results[1];
      final pageviewsSeries = _parseSeries(pageviews['pageviews']);
      final sessionsSeries = _parseSeries(pageviews['sessions']);
      final activeNow = _asInt(active['x'] ?? active['visitors']).toDouble();

      final allMetrics = <RealtimeMetric>[
        RealtimeMetric(
          id: 'pageviews',
          name: 'Pageviews',
          description: 'Pageviews trend',
          unit: 'count',
          currentValue: pageviewsSeries.fold<double>(
            0,
            (sum, p) => sum + p.value,
          ),
          previousValue: 0,
          data: pageviewsSeries,
          type: MetricType.counter,
          lastUpdated: DateTime.now(),
        ),
        RealtimeMetric(
          id: 'sessions',
          name: 'Sessions',
          description: 'Sessions trend',
          unit: 'count',
          currentValue: sessionsSeries.fold<double>(
            0,
            (sum, p) => sum + p.value,
          ),
          previousValue: 0,
          data: sessionsSeries,
          type: MetricType.counter,
          lastUpdated: DateTime.now(),
        ),
        RealtimeMetric(
          id: 'active_users',
          name: 'Active Users',
          description: 'Current active visitors',
          unit: 'count',
          currentValue: activeNow,
          previousValue: 0,
          data: [
            MetricDataPoint(
              timestamp: DateTime.now(),
              value: activeNow,
              label: 'now',
            ),
          ],
          type: MetricType.gauge,
          lastUpdated: DateTime.now(),
        ),
      ];

      if (metricIds == null || metricIds.isEmpty) return allMetrics;
      final idSet = metricIds.toSet();
      return allMetrics.where((m) => idSet.contains(m.id)).toList();
    } catch (e) {
      throw AnalyticsException('Failed to get real-time metrics: $e');
    }
  }

  /// Get metric history
  Future<List<MetricDataPoint>> getMetricHistory({
    required String projectId,
    required String metricId,
    TimeRange timeRange = TimeRange.last24Hours,
  }) async {
    try {
      final range = _rangeBounds(timeRange);
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/analytics/data/$projectId/pageviews',
        queryParams: {
          'unit': 'hour',
          'timezone': 'UTC',
          'startAt': range['startAt']!.toString(),
          'endAt': range['endAt']!.toString(),
        },
      );
      if (metricId == 'sessions') {
        return _parseSeries(response['sessions']);
      }
      return _parseSeries(response['pageviews']);
    } catch (e) {
      throw AnalyticsException('Failed to get metric history: $e');
    }
  }

  /// Get geographic data for world map
  Future<List<GeographicData>> getGeographicData({
    required String projectId,
    TimeRange timeRange = TimeRange.last24Hours,
  }) async {
    try {
      final range = _rangeBounds(timeRange);
      final response = await _apiClient.get<List<dynamic>>(
        '/api/analytics/data/$projectId/metrics',
        queryParams: {
          'type': 'country',
          'limit': '20',
          'startAt': range['startAt']!.toString(),
          'endAt': range['endAt']!.toString(),
        },
      );

      return response.map((json) {
        final item = json is Map<String, dynamic> ? json : <String, dynamic>{};
        final country = (item['x'] ?? item['name'] ?? 'Unknown').toString();
        final code = country.length >= 2
            ? country.substring(0, 2).toUpperCase()
            : 'UN';
        return GeographicData(
          country: country,
          countryCode: code,
          latitude: 0,
          longitude: 0,
          value: _asInt(item['y'] ?? item['value']),
        );
      }).toList();
    } catch (e) {
      throw AnalyticsException('Failed to get geographic data: $e');
    }
  }

  /// Get comparison data for analytics
  Future<List<ComparisonData>> getComparisonData({
    required String projectId,
    required String primaryMetric,
    List<String>? compareWith,
    TimeRange timeRange = TimeRange.last24Hours,
  }) async {
    try {
      final range = _rangeBounds(timeRange);
      final type = (primaryMetric == 'events' || primaryMetric == 'event')
          ? 'event'
          : primaryMetric == 'referrer'
          ? 'referrer'
          : 'url';
      final response = await _apiClient.get<List<dynamic>>(
        '/api/analytics/data/$projectId/metrics',
        queryParams: {
          'type': type,
          'limit': '10',
          'startAt': range['startAt']!.toString(),
          'endAt': range['endAt']!.toString(),
        },
      );

      return response.map((json) {
        final item = json is Map<String, dynamic> ? json : <String, dynamic>{};
        return ComparisonData(
          label: (item['x'] ?? item['name'] ?? 'Unknown').toString(),
          value: _asDouble(item['y'] ?? item['value']),
          color: const Color(0xFF000000),
        );
      }).toList();
    } catch (e) {
      throw AnalyticsException('Failed to get comparison data: $e');
    }
  }

  /// Start real-time data stream
  void startRealtimeStream({
    required String projectId,
    List<String>? metricIds,
    Duration interval = const Duration(seconds: 5),
  }) {
    _realtimeTimer?.cancel();
    // Emit initial data
    _loadInitialMetrics(projectId, metricIds);

    // Set up periodic updates
    _realtimeTimer = Timer.periodic(interval, (_) {
      _updateMetrics(projectId, metricIds);
    });
  }

  /// Stop real-time data stream
  void stopRealtimeStream() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
  }

  /// Release resources when service instance is no longer needed.
  void dispose() {
    _realtimeTimer?.cancel();
    _metricsController.close();
    _streamController.close();
  }

  /// Update metrics periodically
  Future<void> _updateMetrics(String projectId, List<String>? metricIds) async {
    try {
      final metrics = await getRealtimeMetrics(
        projectId: projectId,
        metricIds: metricIds,
      );

      _metricsController.add(metrics);

      // Emit stream data for each metric
      for (final metric in metrics) {
        final streamData = StreamData(
          metricId: metric.id,
          timestamp: DateTime.now(),
          value: metric.currentValue,
          metadata: {
            'name': metric.name,
            'unit': metric.unit,
            'type': metric.type.toString(),
          },
        );
        _streamController.add(streamData);
      }
    } catch (e) {
      // Silently fail for periodic updates
      debugPrint('Failed to update metrics: $e');
    }
  }

  /// Load initial metrics
  Future<void> _loadInitialMetrics(
    String projectId,
    List<String>? metricIds,
  ) async {
    try {
      final metrics = await getRealtimeMetrics(
        projectId: projectId,
        metricIds: metricIds,
      );
      _metricsController.add(metrics);
    } catch (e) {
      debugPrint('Failed to load initial metrics: $e');
    }
  }

  /// Export analytics data
  Future<String> exportAnalytics({
    required String projectId,
    required String format,
    TimeRange timeRange = TimeRange.last24Hours,
  }) async {
    throw const AnalyticsException(
      'Export endpoint is not available on the current /api/analytics/data routes.',
    );
  }

  /// Get custom metrics
  Future<Map<String, dynamic>> getCustomMetrics({
    required String projectId,
    TimeRange timeRange = TimeRange.last24Hours,
  }) async {
    throw const AnalyticsException('Custom metrics are not supported yet.');
  }

  /// Create custom metric
  Future<RealtimeMetric> createCustomMetric({
    required String projectId,
    required String name,
    required String description,
    required String unit,
    required String type,
  }) async {
    throw const AnalyticsException(
      'Creating custom metrics is not supported yet.',
    );
  }
}

/// Custom exception for analytics operations
class AnalyticsException implements Exception {
  final String message;

  const AnalyticsException(this.message);

  @override
  String toString() => 'AnalyticsException: $message';
}

/// Analytics cache for storing frequently accessed data
class AnalyticsCache {
  static final Map<String, AnalyticsSummary> _summaryCache = {};
  static final Map<String, List<RealtimeMetric>> _metricsCache = {};

  static void cacheSummary(String key, AnalyticsSummary summary) {
    _summaryCache[key] = summary;
  }

  static AnalyticsSummary? getSummary(String key) {
    return _summaryCache[key];
  }

  static void cacheMetrics(String key, List<RealtimeMetric> metrics) {
    _metricsCache[key] = metrics;
  }

  static List<RealtimeMetric>? getMetrics(String key) {
    return _metricsCache[key];
  }

  static void clear() {
    _summaryCache.clear();
    _metricsCache.clear();
  }

  static void clearProject(String projectId) {
    _summaryCache.removeWhere((key, _) => key.startsWith(projectId));
    _metricsCache.removeWhere((key, _) => key.startsWith(projectId));
  }
}
