/// 部署历史数据模型
class DeploymentHistory {
  final String id;
  final String environment;
  final String status;
  final String? startedAt;
  final String? completedAt;
  final String? createdAt;
  final String? url;

  DeploymentHistory({
    required this.id,
    required this.environment,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.url,
  });

  factory DeploymentHistory.fromJson(Map<String, dynamic> json) {
    return DeploymentHistory(
      id: json['id'] ?? '',
      environment: json['environment'] ?? '',
      status: json['status'] ?? '',
      startedAt: json['started_at'],
      completedAt: json['completed_at'],
      createdAt: json['created_at'],
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'environment': environment,
      'status': status,
      'started_at': startedAt,
      'completed_at': completedAt,
      'created_at': createdAt,
      'url': url,
    };
  }

  @override
  String toString() {
    return 'DeploymentHistory(id: $id, environment: $environment, status: $status)';
  }
}
