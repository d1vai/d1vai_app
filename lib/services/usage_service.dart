import '../core/api_client.dart';
import '../models/llm_usage.dart';
import '../models/db_usage.dart';

class UsageService {
  final ApiClient _apiClient;

  UsageService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// 获取 LLM 使用量统计
  /// [months] 月份数，默认 12
  Future<LlmUsageResponse> getLlmUsage([int months = 12]) async {
    return _apiClient.get<LlmUsageResponse>(
      '/api/billing/usage',
      fromJsonT: (json) => LlmUsageResponse.fromJson(json),
      queryParams: {'months': months.toString()},
    );
  }

  /// 获取数据库使用量统计 (Neon consumption API)
  /// 默认查询最近 30 天，按天聚合
  Future<DbUsageResponse> getDbUsage({
    required String fromIso,
    required String toIso,
    String granularity = 'daily',
  }) async {
    return _apiClient.get<DbUsageResponse>(
      '/api/projects/consumption',
      fromJsonT: (json) => DbUsageResponse.fromJson(json),
      queryParams: {
        'from_iso': fromIso,
        'to_iso': toIso,
        'granularity': granularity,
      },
    );
  }
}
