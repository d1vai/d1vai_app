import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/model_config.dart';

class ModelConfigService {
  static const String cacheKey = 'd1v_selected_model';

  final ApiClient _apiClient;

  ModelConfigService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ModelConfigResponse> getModelConfig({int retries = 0}) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      '/api/model-config',
      retries: retries,
    );
    return ModelConfigResponse.fromJson(data);
  }

  Future<UpdateModelResponse> setModelConfig(
    String model, {
    int retries = 0,
  }) async {
    final trimmed = model.trim();
    if (trimmed.isEmpty) {
      throw Exception('Model id is empty');
    }
    final data = await _apiClient.put<Map<String, dynamic>>(
      '/api/model-config',
      {'model': trimmed},
      retries: retries,
    );
    return UpdateModelResponse.fromJson(data);
  }

  Future<String?> getCachedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(cacheKey)?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setCachedModel(String model) async {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, trimmed);
  }
}
