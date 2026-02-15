class DatabaseTable {
  final String name;
  final String schema;
  final int? rowCount;
  final List<String> columns;
  final List<DatabaseForeignKey> foreignKeys;
  final String? type; // 'table' or 'view'

  DatabaseTable({
    required this.name,
    required this.schema,
    this.rowCount,
    required this.columns,
    this.foreignKeys = const [],
    this.type,
  });

  factory DatabaseTable.fromJson(Map<String, dynamic> json) {
    final fkListRaw = json['foreign_keys'];
    final foreignKeys = (fkListRaw is List)
        ? fkListRaw
              .whereType<Map>()
              .map(
                (e) =>
                    DatabaseForeignKey.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : const <DatabaseForeignKey>[];

    final kind = (json['kind'] ?? json['table_type'] ?? json['type'] ?? 'table')
        .toString()
        .toLowerCase();
    final resolvedType = (kind == 'view' || kind == 'view table' || kind == 'v')
        ? 'view'
        : (kind.contains('view') ? 'view' : 'table');

    return DatabaseTable(
      name: json['table_name'] ?? json['name'] ?? '',
      schema: json['schema_name'] ?? json['schema'] ?? 'public',
      rowCount: json['row_count'] != null
          ? (json['row_count'] as num).toInt()
          : null,
      columns: json['columns'] != null
          ? List<String>.from(json['columns'].map((col) => col['name'] ?? col))
          : [],
      foreignKeys: foreignKeys,
      type: resolvedType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'table_name': name,
      'schema_name': schema,
      'row_count': rowCount,
      'columns': columns,
      'foreign_keys': foreignKeys.map((x) => x.toJson()).toList(),
      'table_type': type,
    };
  }

  String get displayName => type == 'view' ? '$name (view)' : name;
  String get fullName => '$schema.$name';
}

class DatabaseForeignKey {
  final String constraintName;
  final String columnName;
  final String refSchema;
  final String refTable;
  final String refColumn;

  const DatabaseForeignKey({
    required this.constraintName,
    required this.columnName,
    required this.refSchema,
    required this.refTable,
    required this.refColumn,
  });

  factory DatabaseForeignKey.fromJson(Map<String, dynamic> json) {
    return DatabaseForeignKey(
      constraintName: (json['constraint_name'] ?? '').toString(),
      columnName: (json['column_name'] ?? '').toString(),
      refSchema: (json['ref_schema'] ?? '').toString(),
      refTable: (json['ref_table'] ?? '').toString(),
      refColumn: (json['ref_column'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'constraint_name': constraintName,
      'column_name': columnName,
      'ref_schema': refSchema,
      'ref_table': refTable,
      'ref_column': refColumn,
    };
  }

  String get refFullTable => '$refSchema.$refTable';
}
