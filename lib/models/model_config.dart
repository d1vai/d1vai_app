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

  String get _rawDisplaySource {
    final normalizedId = id.trim();
    final normalizedName = name.trim();
    if (normalizedId.contains('/') ||
        normalizedId.toLowerCase().endsWith('-free')) {
      return normalizedId;
    }
    if (normalizedName.isNotEmpty) return normalizedName;
    return normalizedId.isNotEmpty ? normalizedId : 'unknown';
  }

  String get displayName {
    final source = _rawDisplaySource;
    final leaf = source.split('/').last.trim();
    final lowerLeaf = leaf.toLowerCase();
    if (lowerLeaf.endsWith('-free')) {
      return leaf.substring(0, leaf.length - 5);
    }
    if (lowerLeaf.endsWith(' free')) {
      return leaf.substring(0, leaf.length - 5);
    }
    return leaf.isEmpty ? source : leaf;
  }

  bool get isFreeTier {
    final lower = _rawDisplaySource.toLowerCase();
    return lower.endsWith('-free') || lower.endsWith(' free');
  }

  String? get badgeLabel => isFreeTier ? 'Free' : null;

  String get spokenLabel {
    final base = displayName.trim().isEmpty ? _rawDisplaySource : displayName;
    final badge = badgeLabel;
    return badge == null ? base : '$base $badge';
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
