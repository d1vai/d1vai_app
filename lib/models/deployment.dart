/// 部署历史数据模型
class DeploymentHistory {
  final String id;
  final String environment;
  final String status;
  final String? startedAt;
  final String? completedAt;
  final String? createdAt;
  final String? url;
  final String? commitHash;
  final String? vercelDeploymentId;
  final String? vercelDeploymentUrl;
  final String? vercelDomain;
  final String? vercelFramework;
  final String? gitBranch;
  final String? gitCommitSha;
  final String? gitCommitMessage;
  final String? gitCommitAuthor;
  final String? deployedBy;
  final String? errorMessage;

  DeploymentHistory({
    required this.id,
    required this.environment,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.url,
    this.commitHash,
    this.vercelDeploymentId,
    this.vercelDeploymentUrl,
    this.vercelDomain,
    this.vercelFramework,
    this.gitBranch,
    this.gitCommitSha,
    this.gitCommitMessage,
    this.gitCommitAuthor,
    this.deployedBy,
    this.errorMessage,
  });

  factory DeploymentHistory.fromJson(Map<String, dynamic> json) {
    return DeploymentHistory(
      id: json['id'] ?? '',
      environment: json['environment'] ?? '',
      status: json['status'] ?? '',
      startedAt: json['started_at'],
      completedAt: json['completed_at'],
      createdAt: json['created_at'],
      url: json['url']?.toString(),
      commitHash: json['commit_hash']?.toString(),
      vercelDeploymentId: json['vercel_deployment_id']?.toString(),
      vercelDeploymentUrl: json['vercel_deployment_url']?.toString(),
      vercelDomain: json['vercel_domain']?.toString(),
      vercelFramework: json['vercel_framework']?.toString(),
      gitBranch: json['git_branch']?.toString(),
      gitCommitSha: json['git_commit_sha']?.toString(),
      gitCommitMessage: json['git_commit_message']?.toString(),
      gitCommitAuthor: json['git_commit_author']?.toString(),
      deployedBy: json['deployed_by']?.toString(),
      errorMessage: json['error_message']?.toString(),
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
      'commit_hash': commitHash,
      'vercel_deployment_id': vercelDeploymentId,
      'vercel_deployment_url': vercelDeploymentUrl,
      'vercel_domain': vercelDomain,
      'vercel_framework': vercelFramework,
      'git_branch': gitBranch,
      'git_commit_sha': gitCommitSha,
      'git_commit_message': gitCommitMessage,
      'git_commit_author': gitCommitAuthor,
      'deployed_by': deployedBy,
      'error_message': errorMessage,
    };
  }

  @override
  String toString() {
    return 'DeploymentHistory(id: $id, environment: $environment, status: $status)';
  }
}

extension DeploymentHistoryX on DeploymentHistory {
  /// Human readable status label
  String get statusLabel {
    switch (status) {
      case 'success':
        return 'Success';
      case 'pending':
        return 'Pending';
      case 'building':
        return 'Building';
      case 'deploying':
        return 'Deploying';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Optional descriptive status message
  String? get statusMessage {
    if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      return errorMessage!.trim();
    }
    switch (status) {
      case 'success':
        return 'Deployment completed successfully';
      case 'pending':
        return 'Deployment is in progress';
      case 'building':
        return 'Building deployment';
      case 'deploying':
        return 'Deploying to target environment';
      case 'failed':
        return 'Deployment failed';
      case 'cancelled':
        return 'Deployment cancelled';
      default:
        return null;
    }
  }

  String get environmentLabel {
    switch (environment.toLowerCase()) {
      case 'dev':
      case 'preview':
        return 'Preview';
      case 'prod':
      case 'production':
        return 'Production';
      default:
        if (environment.trim().isEmpty) return 'Deployment';
        return environment[0].toUpperCase() + environment.substring(1);
    }
  }

  String? get primaryCommitSha {
    final sha = (gitCommitSha ?? commitHash)?.trim();
    return (sha == null || sha.isEmpty) ? null : sha;
  }

  String? get primaryUrl {
    final v = (vercelDeploymentUrl ?? url)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
