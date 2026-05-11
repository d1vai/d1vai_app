class D1vProjectFile {
  final int version;
  final String projectId;
  final String workspaceId;
  final String? projectName;
  final String root;
  final bool gitEnabled;
  final String? defaultBranch;
  final String? remoteUrl;
  final String? backendBaseUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const D1vProjectFile({
    required this.version,
    required this.projectId,
    required this.workspaceId,
    required this.root,
    required this.gitEnabled,
    this.projectName,
    this.defaultBranch,
    this.remoteUrl,
    this.backendBaseUrl,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'project_id': projectId,
      'workspace_id': workspaceId,
      'project_name': projectName,
      'root': root,
      'git_enabled': gitEnabled,
      'default_branch': defaultBranch,
      'remote_url': remoteUrl,
      'backend_base_url': backendBaseUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static const String sampleToml = '''
version = 1

project_id = "proj_abc123"
workspace_id = "ws_abc123"
project_name = "d1vai_app"
root = "."
git_enabled = true
default_branch = "main"
remote_url = "git@github.com:d1vai/d1vai_app.git"
backend_base_url = "https://api.d1v.ai"
created_at = "2026-05-11T15:00:00Z"
updated_at = "2026-05-11T15:00:00Z"
''';
}
