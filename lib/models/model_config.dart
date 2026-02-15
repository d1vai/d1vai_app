class ModelInfo {
  final String id;
  final String name;
  final String? description;

  const ModelInfo({required this.id, required this.name, this.description});

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final fallbackName = id.isEmpty ? 'unknown' : id;
    return ModelInfo(
      id: id,
      name: (json['name'] ?? fallbackName).toString(),
      description: json['description']?.toString(),
    );
  }
}

class ModelConfigResponse {
  final String model;
  final List<ModelInfo> availableModels;

  const ModelConfigResponse({
    required this.model,
    required this.availableModels,
  });

  factory ModelConfigResponse.fromJson(Map<String, dynamic> json) {
    final rawModels = json['available_models'];
    final models = <ModelInfo>[];
    if (rawModels is List) {
      for (final item in rawModels) {
        if (item is Map<String, dynamic>) {
          final parsed = ModelInfo.fromJson(item);
          if (parsed.id.trim().isNotEmpty) {
            models.add(parsed);
          }
        } else if (item is Map) {
          final normalized = item.map((k, v) => MapEntry(k.toString(), v));
          final parsed = ModelInfo.fromJson(normalized);
          if (parsed.id.trim().isNotEmpty) {
            models.add(parsed);
          }
        }
      }
    }

    return ModelConfigResponse(
      model: (json['model'] ?? '').toString(),
      availableModels: models,
    );
  }
}

class UpdateModelResponse {
  final String model;
  final String message;

  const UpdateModelResponse({required this.model, required this.message});

  factory UpdateModelResponse.fromJson(Map<String, dynamic> json) {
    return UpdateModelResponse(
      model: (json['model'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}
