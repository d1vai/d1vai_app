class DbUsageResponse {
  final double storageUsedGb;
  final int totalQueries;
  final int activeConnections;
  final double storageLimitGb;
  final double storageUsedPercentage;
  final List<DbUsageBreakdown> breakdowns;

  DbUsageResponse({
    required this.storageUsedGb,
    required this.totalQueries,
    required this.activeConnections,
    required this.storageLimitGb,
    required this.storageUsedPercentage,
    required this.breakdowns,
  });

  factory DbUsageResponse.fromJson(Map<String, dynamic> json) {
    final storageUsed = (json['storage_used_bytes'] ?? 0) / (1024 * 1024 * 1024);
    final storageLimit = (json['storage_limit_bytes'] ?? 0) / (1024 * 1024 * 1024);

    return DbUsageResponse(
      storageUsedGb: (storageUsed ?? 0.0).toDouble(),
      totalQueries: json['total_queries']?.toInt() ?? 0,
      activeConnections: json['active_connections']?.toInt() ?? 0,
      storageLimitGb: (storageLimit ?? 0.0).toDouble(),
      storageUsedPercentage: storageLimit > 0 ? (storageUsed / storageLimit) * 100 : 0.0,
      breakdowns: (json['breakdowns'] as List<dynamic>?)
              ?.map((b) => DbUsageBreakdown.fromJson(b))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storage_used_gb': storageUsedGb,
      'total_queries': totalQueries,
      'active_connections': activeConnections,
      'storage_limit_gb': storageLimitGb,
      'storage_used_percentage': storageUsedPercentage,
      'breakdowns': breakdowns.map((b) => b.toJson()).toList(),
    };
  }
}

class DbUsageBreakdown {
  final String projectId;
  final String projectName;
  final double storageUsedGb;
  final int totalQueries;
  final String? emoji;

  DbUsageBreakdown({
    required this.projectId,
    required this.projectName,
    required this.storageUsedGb,
    required this.totalQueries,
    this.emoji,
  });

  factory DbUsageBreakdown.fromJson(Map<String, dynamic> json) {
    final storageUsed = (json['storage_used_bytes'] ?? 0) / (1024 * 1024 * 1024);

    return DbUsageBreakdown(
      projectId: json['project_id'] ?? '',
      projectName: json['project_name'] ?? '',
      storageUsedGb: (storageUsed ?? 0.0).toDouble(),
      totalQueries: json['total_queries']?.toInt() ?? 0,
      emoji: json['emoji'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'project_name': projectName,
      'storage_used_gb': storageUsedGb,
      'total_queries': totalQueries,
      'emoji': emoji,
    };
  }
}
