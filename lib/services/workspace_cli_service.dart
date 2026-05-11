import '../models/local_workspace.dart';
import '../models/workspace_cli_result.dart';
import 'workspace_local_service.dart';

class WorkspaceCliService {
  final WorkspaceLocalService _localService;

  const WorkspaceCliService({
    WorkspaceLocalService localService = const WorkspaceLocalService(),
  }) : _localService = localService;

  Future<WorkspaceCliResult<Map<String, dynamic>>> inspect(
    String rootPath,
  ) async {
    final state = await _localService.inspectDirectory(rootPath);
    final payload = {
      'root_path': state.rootPath,
      'd1v_directory_path': state.d1vDirectoryPath,
      'config_path': state.configPath,
      'status': state.status.name,
      'error_message': state.errorMessage,
      'config': state.config == null
          ? null
          : {
              'version': state.config!.version,
              'project_id': state.config!.projectId,
              'workspace_id': state.config!.workspaceId,
              'project_name': state.config!.projectName,
              'root': state.config!.root,
              'default_branch': state.config!.defaultBranch,
              'remote_url': state.config!.remoteUrl,
              'backend_base_url': state.config!.backendBaseUrl,
              'created_at': state.config!.createdAt?.toIso8601String(),
              'updated_at': state.config!.updatedAt?.toIso8601String(),
            },
    };

    switch (state.status) {
      case LocalWorkspaceStatus.bound:
        return WorkspaceCliResult(
          ok: true,
          code: 'workspace_bound',
          message: 'Workspace is bound to a d1v cloud project.',
          data: payload,
        );
      case LocalWorkspaceStatus.unbound:
        return WorkspaceCliResult(
          ok: true,
          code: 'workspace_unbound',
          message: 'Workspace is not initialized for d1v yet.',
          data: payload,
        );
      case LocalWorkspaceStatus.unsupportedPlatform:
        return WorkspaceCliResult(
          ok: false,
          code: 'workspace_unsupported_platform',
          message: state.errorMessage ?? 'Unsupported platform.',
          data: payload,
        );
      case LocalWorkspaceStatus.missingDirectory:
        return WorkspaceCliResult(
          ok: false,
          code: 'workspace_missing_directory',
          message: state.errorMessage ?? 'Directory does not exist.',
          data: payload,
        );
      case LocalWorkspaceStatus.invalidConfig:
        return WorkspaceCliResult(
          ok: false,
          code: 'workspace_invalid_config',
          message: state.errorMessage ?? 'Invalid .d1v/project.toml.',
          data: payload,
        );
    }
  }
}
