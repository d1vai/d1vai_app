class DatabaseTable {
  final String name;
  final String schema;
  final int? rowCount;
  final List<String> columns;
  final String? type; // 'table' or 'view'

  DatabaseTable({
    required this.name,
    required this.schema,
    this.rowCount,
    required this.columns,
    this.type,
  });

  factory DatabaseTable.fromJson(Map<String, dynamic> json) {
    return DatabaseTable(
      name: json['table_name'] ?? json['name'] ?? '',
      schema: json['schema_name'] ?? json['schema'] ?? 'public',
      rowCount: json['row_count'] != null ? (json['row_count'] as num).toInt() : null,
      columns: json['columns'] != null
          ? List<String>.from(json['columns'].map((col) => col['name'] ?? col))
          : [],
      type: json['table_type'] ?? json['type'] ?? 'table',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'table_name': name,
      'schema_name': schema,
      'row_count': rowCount,
      'columns': columns,
      'table_type': type,
    };
  }

  String get displayName => type == 'view' ? '$name (view)' : name;
  String get fullName => '$schema.$name';
}
