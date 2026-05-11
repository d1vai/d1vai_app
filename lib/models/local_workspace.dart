import 'd1v_project_file.dart';

class LocalWorkspaceConfig {
  final int version;
  final String projectId;
  final String workspaceId;
  final String? projectName;
  final String root;
  final String? defaultBranch;
  final String? remoteUrl;
  final String? backendBaseUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LocalWorkspaceConfig({
    required this.version,
    required this.projectId,
    required this.workspaceId,
    required this.root,
    this.projectName,
    this.defaultBranch,
    this.remoteUrl,
    this.backendBaseUrl,
    this.createdAt,
    this.updatedAt,
  });
}

enum LocalWorkspaceStatus {
  unsupportedPlatform,
  missingDirectory,
  unbound,
  bound,
  invalidConfig,
}

class LocalWorkspaceState {
  final LocalWorkspaceStatus status;
  final String rootPath;
  final String d1vDirectoryPath;
  final String configPath;
  final LocalWorkspaceConfig? config;
  final String? errorMessage;

  const LocalWorkspaceState({
    required this.status,
    required this.rootPath,
    required this.d1vDirectoryPath,
    required this.configPath,
    this.config,
    this.errorMessage,
  });

  bool get isBound => status == LocalWorkspaceStatus.bound && config != null;
}

extension LocalWorkspaceConfigMapping on LocalWorkspaceConfig {
  D1vProjectFile toProjectFile() {
    return D1vProjectFile(
      version: version,
      projectId: projectId,
      workspaceId: workspaceId,
      projectName: projectName,
      root: root,
      gitEnabled: true,
      defaultBranch: defaultBranch,
      remoteUrl: remoteUrl,
      backendBaseUrl: backendBaseUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
