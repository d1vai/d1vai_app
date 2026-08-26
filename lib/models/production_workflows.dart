enum DbEnvironment { dev, prod }

extension DbEnvironmentWire on DbEnvironment {
  String get wireValue => this == DbEnvironment.dev ? 'dev' : 'prod';
  String get label => this == DbEnvironment.dev ? 'Development' : 'Production';
}

class ProductionEnvironmentStatus {
  final String status;
  final String? databaseProjectName;

  const ProductionEnvironmentStatus({
    required this.status,
    this.databaseProjectName,
  });

  bool get isReady => status == 'ready';
  bool get isLegacyShared => status == 'legacy_shared';
  bool get canOpen => isReady || isLegacyShared;

  factory ProductionEnvironmentStatus.fromJson(Map<String, dynamic> json) =>
      ProductionEnvironmentStatus(
        status: json['status']?.toString() ?? 'not_created',
        databaseProjectName: json['database_project_name']?.toString(),
      );
}

class DatabasePromotionPreflight {
  final Map<String, dynamic> schemaDiff;
  final bool destructive;
  final List<String> tablesWithoutPrimaryKey;
  final Map<String, dynamic> source;
  final Map<String, dynamic> target;

  const DatabasePromotionPreflight({
    required this.schemaDiff,
    required this.destructive,
    required this.tablesWithoutPrimaryKey,
    required this.source,
    required this.target,
  });

  int get addedTables => (schemaDiff['added_tables'] as List?)?.length ?? 0;
  int get changedTables => (schemaDiff['changed_tables'] as List?)?.length ?? 0;
  int get removedTables => (schemaDiff['removed_tables'] as List?)?.length ?? 0;

  factory DatabasePromotionPreflight.fromJson(Map<String, dynamic> json) =>
      DatabasePromotionPreflight(
        schemaDiff: Map<String, dynamic>.from(
          json['schema_diff'] as Map? ?? const {},
        ),
        destructive: json['destructive'] == true,
        tablesWithoutPrimaryKey:
            (json['tables_without_primary_key'] as List? ?? const [])
                .map((value) => value.toString())
                .toList(growable: false),
        source: Map<String, dynamic>.from(json['source'] as Map? ?? const {}),
        target: Map<String, dynamic>.from(json['target'] as Map? ?? const {}),
      );
}

class DatabasePromotionJob {
  final String id;
  final String status;
  final String phase;
  final Map<String, dynamic> counts;
  final List<dynamic> conflicts;
  final String? schemaFingerprint;
  final String? errorMessage;

  const DatabasePromotionJob({
    required this.id,
    required this.status,
    required this.phase,
    required this.counts,
    required this.conflicts,
    this.schemaFingerprint,
    this.errorMessage,
  });

  bool get isActive => status == 'pending' || status == 'running';
  bool get isSucceeded => status == 'succeeded';

  factory DatabasePromotionJob.fromJson(Map<String, dynamic> json) =>
      DatabasePromotionJob(
        id: (json['promotion_id'] ?? json['job_id'] ?? json['id'] ?? '')
            .toString(),
        status: json['status']?.toString() ?? 'pending',
        phase: json['phase']?.toString() ?? 'pending',
        counts: Map<String, dynamic>.from(json['counts'] as Map? ?? const {}),
        conflicts: List<dynamic>.from(json['conflicts'] as List? ?? const []),
        schemaFingerprint: json['schema_fingerprint']?.toString(),
        errorMessage: (json['error_message'] ?? json['error'])?.toString(),
      );
}

class ReleaseEnvDecision {
  final String key;
  final String action;
  final String? value;

  const ReleaseEnvDecision({
    required this.key,
    required this.action,
    this.value,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'action': action,
    if (value != null) 'value': value,
  };
}

class ReleasePreflight {
  final bool firstRelease;
  final Map<String, dynamic> database;
  final List<Map<String, dynamic>> variables;

  const ReleasePreflight({
    required this.firstRelease,
    required this.database,
    required this.variables,
  });

  factory ReleasePreflight.fromJson(Map<String, dynamic> json) =>
      ReleasePreflight(
        firstRelease: json['first_release'] == true,
        database: Map<String, dynamic>.from(
          json['database'] as Map? ?? const {},
        ),
        variables: (json['variables'] as List? ?? const [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false),
      );
}

class ProductionRelease {
  final String id;
  final String status;
  final String phase;
  final String? errorMessage;

  const ProductionRelease({
    required this.id,
    required this.status,
    required this.phase,
    this.errorMessage,
  });

  bool get isActive => status == 'pending' || status == 'running';
  bool get isSucceeded => status == 'succeeded';

  factory ProductionRelease.fromJson(Map<String, dynamic> json) =>
      ProductionRelease(
        id: (json['release_id'] ?? json['id'] ?? '').toString(),
        status: json['status']?.toString() ?? 'pending',
        phase: json['phase']?.toString() ?? 'pending',
        errorMessage: (json['error_message'] ?? json['error'])?.toString(),
      );
}
