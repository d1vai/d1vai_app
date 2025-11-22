class ApiKey {
  final String id;
  final String name;
  final String key; // 以 sk- 开头的密钥
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final bool isActive;

  const ApiKey({
    required this.id,
    required this.name,
    required this.key,
    required this.createdAt,
    this.lastUsedAt,
    required this.isActive,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    return ApiKey(
      id: json['id'] as String,
      name: json['name'] as String,
      key: json['key'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'key': key,
      'created_at': createdAt.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  /// 获取掩码显示的密钥（例如：sk-abc...xyz）
  String get maskedKey {
    if (key.length <= 12) return key;
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
  }

  /// 复制并更新字段
  ApiKey copyWith({
    String? id,
    String? name,
    String? key,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    bool? isActive,
  }) {
    return ApiKey(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// 检查是否已过期（根据创建时间和有效期判断）
  bool isExpired({Duration validity = const Duration(days: 365)}) {
    return DateTime.now().isAfter(createdAt.add(validity));
  }

  /// 获取创建至今的时间描述
  String get createdAtAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  /// 获取最后使用时间描述
  String? get lastUsedAgo {
    if (lastUsedAt == null) return null;

    final now = DateTime.now();
    final diff = now.difference(lastUsedAt!);

    if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() {
    return 'ApiKey(id: $id, name: $name, key: $maskedKey, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiKey && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
