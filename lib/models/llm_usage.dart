class LlmUsageResponse {
  final List<ProjectMonthlyUsage> projects;

  LlmUsageResponse({required this.projects});

  factory LlmUsageResponse.fromJson(Map<String, dynamic> json) {
    final projectsJson = json['projects'] as List<dynamic>? ?? [];
    return LlmUsageResponse(
      projects: projectsJson
          .map((p) => ProjectMonthlyUsage.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'projects': projects.map((p) => p.toJson()).toList()};
  }
}

class ProjectMonthlyUsage {
  final String projectId;
  final String projectName;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCache5mTokens;
  final int totalCache1hTokens;
  final int totalCacheReadTokens;
  final double totalCostUsd;
  final Map<String, ModelAggregate>? modelBreakdown;
  final List<MonthlyBreakdown> monthly;
  final bool archived;
  final String? emoji;

  ProjectMonthlyUsage({
    required this.projectId,
    required this.projectName,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalCache5mTokens,
    required this.totalCache1hTokens,
    required this.totalCacheReadTokens,
    required this.totalCostUsd,
    this.modelBreakdown,
    required this.monthly,
    this.archived = false,
    this.emoji,
  });

  factory ProjectMonthlyUsage.fromJson(Map<String, dynamic> json) {
    final modelBreakdownJson = json['model_breakdown'] as Map<String, dynamic>?;
    return ProjectMonthlyUsage(
      projectId: json['project_id'] ?? '',
      projectName: json['project_name'] ?? '',
      totalInputTokens: json['total_input_tokens']?.toInt() ?? 0,
      totalOutputTokens: json['total_output_tokens']?.toInt() ?? 0,
      totalCache5mTokens: json['total_cache_5m_tokens']?.toInt() ?? 0,
      totalCache1hTokens: json['total_cache_1h_tokens']?.toInt() ?? 0,
      totalCacheReadTokens: json['total_cache_read_tokens']?.toInt() ?? 0,
      totalCostUsd: (json['total_cost_usd'] ?? 0.0).toDouble(),
      modelBreakdown: modelBreakdownJson?.map(
        (key, value) => MapEntry(key, ModelAggregate.fromJson(value)),
      ),
      monthly:
          (json['monthly'] as List<dynamic>?)
              ?.map((m) => MonthlyBreakdown.fromJson(m))
              .toList() ??
          [],
      archived: json['archived'] ?? false,
      emoji: json['emoji'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'project_name': projectName,
      'total_input_tokens': totalInputTokens,
      'total_output_tokens': totalOutputTokens,
      'total_cache_5m_tokens': totalCache5mTokens,
      'total_cache_1h_tokens': totalCache1hTokens,
      'total_cache_read_tokens': totalCacheReadTokens,
      'total_cost_usd': totalCostUsd,
      'model_breakdown': modelBreakdown?.map((k, v) => MapEntry(k, v.toJson())),
      'monthly': monthly.map((m) => m.toJson()).toList(),
      'archived': archived,
      'emoji': emoji,
    };
  }
}

class ModelAggregate {
  final int calls;
  final int inputTokens;
  final int outputTokens;
  final int cacheCreationTokens;
  final int cacheReadTokens;
  final double costUsd;

  ModelAggregate({
    required this.calls,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheCreationTokens,
    required this.cacheReadTokens,
    required this.costUsd,
  });

  factory ModelAggregate.fromJson(Map<String, dynamic> json) {
    return ModelAggregate(
      calls: json['calls']?.toInt() ?? 0,
      inputTokens: json['input_tokens']?.toInt() ?? 0,
      outputTokens: json['output_tokens']?.toInt() ?? 0,
      cacheCreationTokens: json['cache_creation_tokens']?.toInt() ?? 0,
      cacheReadTokens: json['cache_read_tokens']?.toInt() ?? 0,
      costUsd: (json['cost_usd'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calls': calls,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'cache_creation_tokens': cacheCreationTokens,
      'cache_read_tokens': cacheReadTokens,
      'cost_usd': costUsd,
    };
  }
}

class MonthlyBreakdown {
  final int year;
  final int month;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCache5mTokens;
  final int totalCache1hTokens;
  final int totalCacheReadTokens;
  final double totalCostUsd;

  MonthlyBreakdown({
    required this.year,
    required this.month,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalCache5mTokens,
    required this.totalCache1hTokens,
    required this.totalCacheReadTokens,
    required this.totalCostUsd,
  });

  factory MonthlyBreakdown.fromJson(Map<String, dynamic> json) {
    return MonthlyBreakdown(
      year: json['year']?.toInt() ?? 0,
      month: json['month']?.toInt() ?? 0,
      totalInputTokens: json['total_input_tokens']?.toInt() ?? 0,
      totalOutputTokens: json['total_output_tokens']?.toInt() ?? 0,
      totalCache5mTokens: json['total_cache_5m_tokens']?.toInt() ?? 0,
      totalCache1hTokens: json['total_cache_1h_tokens']?.toInt() ?? 0,
      totalCacheReadTokens: json['total_cache_read_tokens']?.toInt() ?? 0,
      totalCostUsd: (json['total_cost_usd'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'total_input_tokens': totalInputTokens,
      'total_output_tokens': totalOutputTokens,
      'total_cache_5m_tokens': totalCache5mTokens,
      'total_cache_1h_tokens': totalCache1hTokens,
      'total_cache_read_tokens': totalCacheReadTokens,
      'total_cost_usd': totalCostUsd,
    };
  }
}
