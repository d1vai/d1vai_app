import 'package:flutter/material.dart';

/// Real-time analytics data models

/// Real-time metric data point
class MetricDataPoint {
  final DateTime timestamp;
  final double value;
  final String? label;

  const MetricDataPoint({
    required this.timestamp,
    required this.value,
    this.label,
  });

  factory MetricDataPoint.fromJson(Map<String, dynamic> json) {
    return MetricDataPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      value: (json['value'] as num).toDouble(),
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'value': value,
      'label': label,
    };
  }
}

/// Real-time metric
class RealtimeMetric {
  final String id;
  final String name;
  final String description;
  final String unit;
  final double currentValue;
  final double previousValue;
  final List<MetricDataPoint> data;
  final MetricType type;
  final DateTime lastUpdated;

  const RealtimeMetric({
    required this.id,
    required this.name,
    required this.description,
    required this.unit,
    required this.currentValue,
    required this.previousValue,
    required this.data,
    required this.type,
    required this.lastUpdated,
  });

  /// Calculate percentage change
  double get percentageChange {
    if (previousValue == 0) return 0.0;
    return ((currentValue - previousValue) / previousValue) * 100;
  }

  /// Get color based on trend
  bool get isPositiveTrend {
    return currentValue >= previousValue;
  }

  factory RealtimeMetric.fromJson(Map<String, dynamic> json) {
    return RealtimeMetric(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      unit: json['unit'] as String,
      currentValue: (json['current_value'] as num).toDouble(),
      previousValue: (json['previous_value'] as num).toDouble(),
      data: (json['data'] as List<dynamic>)
          .map((e) => MetricDataPoint.fromJson(e))
          .toList(),
      type: MetricType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'unit': unit,
      'current_value': currentValue,
      'previous_value': previousValue,
      'data': data.map((e) => e.toJson()).toList(),
      'type': type.toString().split('.').last,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

/// Metric type
enum MetricType { counter, gauge, rate, duration, percentage }

/// Comparison data for analytics
class ComparisonData {
  final String label;
  final double value;
  final Color color;

  const ComparisonData({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Analytics summary
class AnalyticsSummary {
  final String projectId;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final int totalUsers;
  final int activeUsers;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final double averageResponseTime;
  final double uptime;
  final Map<String, dynamic> customMetrics;
  final List<RealtimeMetric> metrics;

  const AnalyticsSummary({
    required this.projectId,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalUsers,
    required this.activeUsers,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageResponseTime,
    required this.uptime,
    required this.customMetrics,
    required this.metrics,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      projectId: json['project_id'] as String,
      period: json['period'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalUsers: json['total_users'] as int,
      activeUsers: json['active_users'] as int,
      totalRequests: json['total_requests'] as int,
      successfulRequests: json['successful_requests'] as int,
      failedRequests: json['failed_requests'] as int,
      averageResponseTime: (json['average_response_time'] as num).toDouble(),
      uptime: (json['uptime'] as num).toDouble(),
      customMetrics: json['custom_metrics'] as Map<String, dynamic>? ?? {},
      metrics:
          (json['metrics'] as List<dynamic>?)
              ?.map((e) => RealtimeMetric.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// Real-time stream data
class StreamData {
  final String metricId;
  final DateTime timestamp;
  final double value;
  final Map<String, dynamic> metadata;

  const StreamData({
    required this.metricId,
    required this.timestamp,
    required this.value,
    required this.metadata,
  });

  factory StreamData.fromJson(Map<String, dynamic> json) {
    return StreamData(
      metricId: json['metric_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      value: (json['value'] as num).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metric_id': metricId,
      'timestamp': timestamp.toIso8601String(),
      'value': value,
      'metadata': metadata,
    };
  }
}

/// Geographic data for world map visualization
class GeographicData {
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;
  final int value;
  final String? region;

  const GeographicData({
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.value,
    this.region,
  });

  factory GeographicData.fromJson(Map<String, dynamic> json) {
    return GeographicData(
      country: json['country'] as String,
      countryCode: json['country_code'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      value: json['value'] as int,
      region: json['region'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'country_code': countryCode,
      'latitude': latitude,
      'longitude': longitude,
      'value': value,
      'region': region,
    };
  }
}

/// Time range for analytics
enum TimeRange {
  lastHour('Last Hour', Duration(hours: 1)),
  last6Hours('Last 6 Hours', Duration(hours: 6)),
  last24Hours('Last 24 Hours', Duration(hours: 24)),
  last7Days('Last 7 Days', Duration(days: 7)),
  last30Days('Last 30 Days', Duration(days: 30)),
  last90Days('Last 90 Days', Duration(days: 90));

  const TimeRange(this.label, this.duration);

  final String label;
  final Duration duration;
}

/// Chart data series
class ChartSeries {
  final String name;
  final List<MetricDataPoint> data;
  final Color color;

  const ChartSeries({
    required this.name,
    required this.data,
    required this.color,
  });
}

/// KPI card data
class KPICard {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Trend trend;

  const KPICard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trend,
  });
}

/// Trend direction
enum Trend { up, down, stable }
