import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/local_workspace.dart';

class WorkspaceLocalService {
  const WorkspaceLocalService();

  Future<LocalWorkspaceState> inspectDirectory(String rootPath) async {
    final normalizedRoot = rootPath.trim();
    final d1vDirPath = '$normalizedRoot/.d1v';
    final configPath = '$d1vDirPath/project.toml';

    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows)) {
      return LocalWorkspaceState(
        status: LocalWorkspaceStatus.unsupportedPlatform,
        rootPath: normalizedRoot,
        d1vDirectoryPath: d1vDirPath,
        configPath: configPath,
        errorMessage:
            'Local workspace inspection is only enabled on macOS and Windows.',
      );
    }

    if (normalizedRoot.isEmpty) {
      return LocalWorkspaceState(
        status: LocalWorkspaceStatus.missingDirectory,
        rootPath: normalizedRoot,
        d1vDirectoryPath: d1vDirPath,
        configPath: configPath,
        errorMessage: 'Directory path is empty.',
      );
    }

    final rootDir = Directory(normalizedRoot);
    if (!await rootDir.exists()) {
      return LocalWorkspaceState(
        status: LocalWorkspaceStatus.missingDirectory,
        rootPath: normalizedRoot,
        d1vDirectoryPath: d1vDirPath,
        configPath: configPath,
        errorMessage: 'Directory does not exist.',
      );
    }

    final configFile = File(configPath);
    if (!await configFile.exists()) {
      return LocalWorkspaceState(
        status: LocalWorkspaceStatus.unbound,
        rootPath: normalizedRoot,
        d1vDirectoryPath: d1vDirPath,
        configPath: configPath,
      );
    }

    try {
      final raw = await configFile.readAsString();
      final config = _parseProjectToml(raw);
      return LocalWorkspaceState(
        status: LocalWorkspaceStatus.bound,
        rootPath: normalizedRoot,
        d1vDirectoryPath: d1vDirPath,
        configPath: configPath,
        config: config,
      );
    } catch (e) {
      return LocalWorkspaceState(
        status: LocalWorkspaceStatus.invalidConfig,
        rootPath: normalizedRoot,
        d1vDirectoryPath: d1vDirPath,
        configPath: configPath,
        errorMessage: e.toString(),
      );
    }
  }

  LocalWorkspaceConfig _parseProjectToml(String content) {
    final values = <String, String>{};
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      values[key] = _stripTomlString(value);
    }

    final version = int.tryParse(values['version'] ?? '');
    final projectId = values['project_id'] ?? '';
    final workspaceId = values['workspace_id'] ?? '';
    final root = values['root'] ?? '.';

    if (version == null || projectId.isEmpty || workspaceId.isEmpty) {
      throw const FormatException(
        'Invalid .d1v/project.toml: missing required fields.',
      );
    }

    return LocalWorkspaceConfig(
      version: version,
      projectId: projectId,
      workspaceId: workspaceId,
      projectName: _nullable(values['project_name']),
      root: root,
      defaultBranch: _nullable(values['default_branch']),
      remoteUrl: _nullable(values['remote_url']),
      backendBaseUrl: _nullable(values['backend_base_url']),
      createdAt: _parseDateTime(values['created_at']),
      updatedAt: _parseDateTime(values['updated_at']),
    );
  }

  String _stripTomlString(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  String? _nullable(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DateTime? _parseDateTime(String? value) {
    final normalized = _nullable(value);
    if (normalized == null) return null;
    return DateTime.tryParse(normalized);
  }
}
