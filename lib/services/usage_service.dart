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
      '/api/llm/usage',
      fromJsonT: (json) => LlmUsageResponse.fromJson(json),
      queryParams: {'months': months.toString()},
    );
  }

  /// 获取数据库使用量统计
  Future<DbUsageResponse> getDbUsage() async {
    return _apiClient.get<DbUsageResponse>(
      '/api/db/usage',
      fromJsonT: (json) => DbUsageResponse.fromJson(json),
    );
  }
}
