class BuilderUsageProjectItem {
  final String projectId;
  final String projectName;
  final String? projectEmoji;
  final int deploymentCount;
  final double totalBuildSeconds;
  final double estimatedCostUsd;
  final String? lastDeploymentAt;

  const BuilderUsageProjectItem({
    required this.projectId,
    required this.projectName,
    this.projectEmoji,
    required this.deploymentCount,
    required this.totalBuildSeconds,
    required this.estimatedCostUsd,
    this.lastDeploymentAt,
  });

  factory BuilderUsageProjectItem.fromJson(Map<String, dynamic> json) {
    return BuilderUsageProjectItem(
      projectId: (json['project_id'] ?? '').toString(),
      projectName: (json['project_name'] ?? '').toString(),
      projectEmoji: json['project_emoji']?.toString(),
      deploymentCount: (json['deployment_count'] as num?)?.toInt() ?? 0,
      totalBuildSeconds: (json['total_build_seconds'] ?? 0).toDouble(),
      estimatedCostUsd: (json['estimated_cost_usd'] ?? 0).toDouble(),
      lastDeploymentAt: json['last_deployment_at']?.toString(),
    );
  }
}

class BuilderUsageSummary {
  final List<BuilderUsageProjectItem> projects;
  final int totalProjects;
  final double totalBuildSeconds;
  final double totalEstimatedCostUsd;
  final double billingRateUsdPerMinute;

  const BuilderUsageSummary({
    required this.projects,
    required this.totalProjects,
    required this.totalBuildSeconds,
    required this.totalEstimatedCostUsd,
    required this.billingRateUsdPerMinute,
  });

  factory BuilderUsageSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['projects'];
    final projects = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (it) => BuilderUsageProjectItem.fromJson(
                  it.cast<String, dynamic>(),
                ),
              )
              .toList()
        : <BuilderUsageProjectItem>[];

    return BuilderUsageSummary(
      projects: projects,
      totalProjects:
          (json['total_projects'] as num?)?.toInt() ?? projects.length,
      totalBuildSeconds: (json['total_build_seconds'] ?? 0).toDouble(),
      totalEstimatedCostUsd: (json['total_estimated_cost_usd'] ?? 0).toDouble(),
      billingRateUsdPerMinute: (json['billing_rate_usd_per_minute'] ?? 0.1)
          .toDouble(),
    );
  }
}
