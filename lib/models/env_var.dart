import 'package:flutter/material.dart';

class EnvVar {
  final int? id;
  final String key;
  final String? value;
  final String? valuePreview;
  final String? description;
  final String? environment; // production, preview, development
  final bool isEncrypted;
  final String? createdAt;
  final String? updatedAt;

  EnvVar({
    this.id,
    required this.key,
    this.value,
    this.valuePreview,
    this.description,
    this.environment,
    this.isEncrypted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory EnvVar.fromJson(Map<String, dynamic> json) {
    return EnvVar(
      id: json['id'] != null ? (json['id'] as num).toInt() : null,
      key: json['key'] ?? '',
      value: json['value'],
      valuePreview: json['value_preview']?.toString(),
      description: json['description'],
      environment: json['environment'],
      // Backend uses `is_sensitive`; some newer payloads may use `is_encrypted`.
      isEncrypted:
          (json['is_encrypted'] ?? json['is_sensitive'] ?? false) as bool,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'value': value,
      'value_preview': valuePreview,
      'description': description,
      'environment': environment,
      'is_encrypted': isEncrypted,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  EnvVar copyWith({
    int? id,
    String? key,
    String? value,
    String? valuePreview,
    String? description,
    String? environment,
    bool? isEncrypted,
    String? createdAt,
    String? updatedAt,
  }) {
    return EnvVar(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      valuePreview: valuePreview ?? this.valuePreview,
      description: description ?? this.description,
      environment: environment ?? this.environment,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isSensitive => isEncrypted;

  String get displayValue {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '';
    // When backend masks, value is usually "***" and preview is "sk-***" etc.
    if (v == '***' && (valuePreview ?? '').trim().isNotEmpty) {
      return valuePreview!.trim();
    }
    return v;
  }

  String get environmentLabel {
    switch (environment) {
      case 'production':
        return 'Production';
      case 'preview':
        return 'Preview';
      case 'development':
        return 'Development';
      default:
        return 'All';
    }
  }

  Color get environmentColor {
    switch (environment) {
      case 'production':
        return Colors.green;
      case 'preview':
        return Colors.blue;
      case 'development':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
