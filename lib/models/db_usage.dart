class DbUsageResponse {
  final List<DbUsagePeriod> consumption;
  final List<DbUsagePeriod> periods;
  final List<String> projects;

  DbUsageResponse({
    required this.consumption,
    required this.periods,
    required this.projects,
  });

  factory DbUsageResponse.fromJson(Map<String, dynamic> json) {
    final consumptionJson = json['consumption'] as List<dynamic>? ?? [];
    final periodsJson = json['periods'] as List<dynamic>? ?? [];
    final projectsJson = json['projects'] as List<dynamic>? ?? [];

    return DbUsageResponse(
      consumption: consumptionJson
          .map((e) => DbUsagePeriod.fromJson(e as Map<String, dynamic>))
          .toList(),
      periods: periodsJson
          .map((e) => DbUsagePeriod.fromJson(e as Map<String, dynamic>))
          .toList(),
      projects: projectsJson.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consumption': consumption.map((e) => e.toJson()).toList(),
      'periods': periods.map((e) => e.toJson()).toList(),
      'projects': projects,
    };
  }
}

class DbUsagePeriod {
  final String projectId;
  final String periodStart;
  final String? periodEnd;
  final double computeTimeSeconds;
  final double activeTimeSeconds;
  final double writtenDataBytes;
  final double dataTransferBytes;
  final double dataStorageBytesHour;
  final double syntheticStorageSizeBytes;

  DbUsagePeriod({
    required this.projectId,
    required this.periodStart,
    this.periodEnd,
    required this.computeTimeSeconds,
    required this.activeTimeSeconds,
    required this.writtenDataBytes,
    required this.dataTransferBytes,
    required this.dataStorageBytesHour,
    required this.syntheticStorageSizeBytes,
  });

  factory DbUsagePeriod.fromJson(Map<String, dynamic> json) {
    return DbUsagePeriod(
      projectId: json['project_id']?.toString() ?? '',
      periodStart: json['period_start']?.toString() ?? '',
      periodEnd: json['period_end']?.toString(),
      computeTimeSeconds:
          (json['compute_time_seconds'] as num?)?.toDouble() ?? 0.0,
      activeTimeSeconds:
          (json['active_time_seconds'] as num?)?.toDouble() ?? 0.0,
      writtenDataBytes:
          (json['written_data_bytes'] as num?)?.toDouble() ?? 0.0,
      dataTransferBytes:
          (json['data_transfer_bytes'] as num?)?.toDouble() ?? 0.0,
      dataStorageBytesHour:
          (json['data_storage_bytes_hour'] as num?)?.toDouble() ?? 0.0,
      syntheticStorageSizeBytes:
          (json['synthetic_storage_size_bytes'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'period_start': periodStart,
      'period_end': periodEnd,
      'compute_time_seconds': computeTimeSeconds,
      'active_time_seconds': activeTimeSeconds,
      'written_data_bytes': writtenDataBytes,
      'data_transfer_bytes': dataTransferBytes,
      'data_storage_bytes_hour': dataStorageBytesHour,
      'synthetic_storage_size_bytes': syntheticStorageSizeBytes,
    };
  }
}
