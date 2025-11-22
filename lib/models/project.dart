/// 用户项目数据模型
class UserProject {
  final String id;
  final String projectName;
  final String projectDescription;
  final String createdAt;
  final String updatedAt;
  final int userId;
  final int projectPort;
  final String? emoji;
  final String? latestPreviewUrl;
  final List<String> tags;
  final String status;
  final bool? analyticsEnabled;
  final int? projectDatabaseId;
  final int? projectPayId;
  final String? vercelProdDomain;
  final String? latestProdDeploymentUrl;

  const UserProject({
    required this.id,
    required this.projectName,
    required this.projectDescription,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.projectPort,
    this.emoji,
    this.latestPreviewUrl,
    this.tags = const [],
    this.status = 'active',
    this.analyticsEnabled,
    this.projectDatabaseId,
    this.projectPayId,
    this.vercelProdDomain,
    this.latestProdDeploymentUrl,
  });

  factory UserProject.fromJson(Map<String, dynamic> json) {
    return UserProject(
      id: json['id'],
      projectName: json['project_name'] ?? '',
      projectDescription: json['project_description'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      userId: json['user_id'] ?? 0,
      projectPort: json['project_port'] ?? 0,
      emoji: json['emoji'],
      latestPreviewUrl: json['latest_preview_url'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      status: json['status'] ?? 'active',
      analyticsEnabled: json['analytics_enabled'],
      projectDatabaseId: json['project_database_id'],
      projectPayId: json['project_pay_id'],
      vercelProdDomain: json['vercel_prod_domain'],
      latestProdDeploymentUrl: json['latest_prod_deployment_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_name': projectName,
      'project_description': projectDescription,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'user_id': userId,
      'project_port': projectPort,
      'emoji': emoji,
      'latest_preview_url': latestPreviewUrl,
      'tags': tags,
      'status': status,
      'analytics_enabled': analyticsEnabled,
      'project_database_id': projectDatabaseId,
      'project_pay_id': projectPayId,
      'vercel_prod_domain': vercelProdDomain,
      'latest_prod_deployment_url': latestProdDeploymentUrl,
    };
  }

  /// 创建副本
  UserProject copyWith({
    String? id,
    String? projectName,
    String? projectDescription,
    String? createdAt,
    String? updatedAt,
    int? userId,
    int? projectPort,
    String? emoji,
    String? latestPreviewUrl,
    List<String>? tags,
    String? status,
    bool? analyticsEnabled,
    int? projectDatabaseId,
    int? projectPayId,
    String? vercelProdDomain,
    String? latestProdDeploymentUrl,
  }) {
    return UserProject(
      id: id ?? this.id,
      projectName: projectName ?? this.projectName,
      projectDescription: projectDescription ?? this.projectDescription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      projectPort: projectPort ?? this.projectPort,
      emoji: emoji ?? this.emoji,
      latestPreviewUrl: latestPreviewUrl ?? this.latestPreviewUrl,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      projectDatabaseId: projectDatabaseId ?? this.projectDatabaseId,
      projectPayId: projectPayId ?? this.projectPayId,
      vercelProdDomain: vercelProdDomain ?? this.vercelProdDomain,
      latestProdDeploymentUrl: latestProdDeploymentUrl ?? this.latestProdDeploymentUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProject &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 项目状态常量
class ProjectStatus {
  static const String draft = 'draft';
  static const String active = 'active';
  static const String archived = 'archived';
  static const String deleted = 'deleted';
}

/// 项目查询参数
class ProjectsQuery {
  final String? q;
  final int? limit;
  final int? offset;
  final String? sort;
  final String? order;
  final String? status;

  const ProjectsQuery({
    this.q,
    this.limit,
    this.offset,
    this.sort,
    this.order,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      if (q != null) 'q': q,
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
      if (sort != null) 'sort': sort,
      if (order != null) 'order': order,
      if (status != null) 'status': status,
    };
  }
}

/// 项目列表响应
class ProjectsResponse {
  final int code;
  final String message;
  final List<UserProject> data;
  final int total;

  const ProjectsResponse({
    required this.code,
    required this.message,
    required this.data,
    required this.total,
  });

  factory ProjectsResponse.fromJson(Map<String, dynamic> json) {
    return ProjectsResponse(
      code: json['code'] ?? 0,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? List<UserProject>.from(
              json['data'].map((item) => UserProject.fromJson(item)),
            )
          : [],
      total: json['total'] ?? 0,
    );
  }
}

/// 创建项目响应
class CreateProjectResponse {
  final int code;
  final String message;
  final UserProject data;

  const CreateProjectResponse({
    required this.code,
    required this.message,
    required this.data,
  });

  factory CreateProjectResponse.fromJson(Map<String, dynamic> json) {
    return CreateProjectResponse(
      code: json['code'] ?? 0,
      message: json['message'] ?? '',
      data: UserProject.fromJson(json['data'] ?? {}),
    );
  }
}
