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

  AnalyticsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Stream of real-time metrics
  Stream<List<RealtimeMetric>> get metricsStream => _metricsController.stream;

  /// Stream of real-time metric data
  Stream<StreamData> get streamData => _streamController.stream;

  /// Get analytics summary for a project
  Future<AnalyticsSummary> getAnalyticsSummary({
    required String projectId,
    TimeRange timeRange = TimeRange.last24Hours,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/projects/$projectId/analytics/summary?period=${timeRange.name}',
      );

      return AnalyticsSummary.fromJson(response);
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
      final queryParams = <String, String>{};
      if (metricIds != null && metricIds.isNotEmpty) {
        queryParams['metric_ids'] = metricIds.join(',');
      }

      final response = await _apiClient.get(
        '/api/projects/$projectId/analytics/metrics?${Uri(queryParameters: queryParams).query}',
      );

      final List<dynamic> data = response['metrics'] ?? response;
      return data.map((json) => RealtimeMetric.fromJson(json)).toList();
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
      final response = await _apiClient.get(
        '/api/projects/$projectId/analytics/metrics/$metricId/history?period=${timeRange.name}',
      );

      final List<dynamic> data = response['data'] ?? response;
      return data.map((json) => MetricDataPoint.fromJson(json)).toList();
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
      final response = await _apiClient.get(
        '/api/projects/$projectId/analytics/geographic?period=${timeRange.name}',
      );

      final List<dynamic> data = response['data'] ?? response;
      return data.map((json) => GeographicData.fromJson(json)).toList();
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
      final response = await _apiClient
          .post('/api/projects/$projectId/analytics/compare', {
            'primary_metric': primaryMetric,
            'compare_with': compareWith ?? [],
            'period': timeRange.name,
          });

      final List<dynamic> data = response['data'] ?? response;
      return data
          .map(
            (json) => ComparisonData(
              label: json['label'] as String,
              value: (json['value'] as num).toDouble(),
              color: const Color(0xFF000000),
            ),
          )
          .toList();
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
    // Emit initial data
    _loadInitialMetrics(projectId, metricIds);

    // Set up periodic updates
    Timer.periodic(interval, (_) {
      _updateMetrics(projectId, metricIds);
    });
  }

  /// Stop real-time data stream
  void stopRealtimeStream() {
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
    try {
      final response = await _apiClient.post(
        '/api/projects/$projectId/analytics/export',
        {
          'format': format, // 'csv', 'json', 'pdf'
          'period': timeRange.name,
        },
      );

      return response['download_url'] as String;
    } catch (e) {
      throw AnalyticsException('Failed to export analytics: $e');
    }
  }

  /// Get custom metrics
  Future<Map<String, dynamic>> getCustomMetrics({
    required String projectId,
    TimeRange timeRange = TimeRange.last24Hours,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/projects/$projectId/analytics/custom?period=${timeRange.name}',
      );

      return response as Map<String, dynamic>;
    } catch (e) {
      throw AnalyticsException('Failed to get custom metrics: $e');
    }
  }

  /// Create custom metric
  Future<RealtimeMetric> createCustomMetric({
    required String projectId,
    required String name,
    required String description,
    required String unit,
    required String type,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/projects/$projectId/analytics/custom-metrics',
        {'name': name, 'description': description, 'unit': unit, 'type': type},
      );

      return RealtimeMetric.fromJson(response['metric'] ?? response);
    } catch (e) {
      throw AnalyticsException('Failed to create custom metric: $e');
    }
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
