import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/workspace_cli_result.dart';

class WorkspaceCliExecutor {
  const WorkspaceCliExecutor();

  Future<WorkspaceCliResult<Map<String, dynamic>>> workspaceStatus(
    String rootPath,
  ) async {
    return _runWorkspaceCommand(['status', rootPath, '--format', 'json']);
  }

  Future<WorkspaceCliResult<Map<String, dynamic>>> workspaceInit(
    String rootPath,
  ) async {
    return _runWorkspaceCommand(['init', rootPath, '--format', 'json']);
  }

  Future<WorkspaceCliResult<Map<String, dynamic>>> _runWorkspaceCommand(
    List<String> args,
  ) async {
    if (kIsWeb || !Platform.isMacOS) {
      return const WorkspaceCliResult(
        ok: false,
        code: 'workspace_cli_unsupported_platform',
        message: 'CLI workspace execution is only available on macOS.',
      );
    }

    try {
      final result = await Process.run('d1v', ['workspace', ...args]);

      if (result.exitCode != 0) {
        return WorkspaceCliResult(
          ok: false,
          code: 'workspace_cli_failed',
          message: (result.stderr ?? '').toString().trim().isNotEmpty
              ? result.stderr.toString().trim()
              : 'd1v workspace command failed with exit code ${result.exitCode}.',
        );
      }

      final stdout = result.stdout.toString().trim();
      final decoded = jsonDecode(stdout);
      if (decoded is! Map<String, dynamic>) {
        return const WorkspaceCliResult(
          ok: false,
          code: 'workspace_cli_invalid_json',
          message: 'CLI returned a non-object JSON payload.',
        );
      }

      return WorkspaceCliResult(
        ok: decoded['ok'] == true,
        code: (decoded['code'] ?? 'workspace_cli_unknown').toString(),
        message: (decoded['message'] ?? '').toString(),
        data: decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : null,
      );
    } on ProcessException catch (e) {
      return WorkspaceCliResult(
        ok: false,
        code: 'workspace_cli_missing',
        message: 'd1v CLI is not available: ${e.message}',
      );
    } on FormatException catch (e) {
      return WorkspaceCliResult(
        ok: false,
        code: 'workspace_cli_invalid_json',
        message: 'CLI returned invalid JSON: ${e.message}',
      );
    } catch (e) {
      return WorkspaceCliResult(
        ok: false,
        code: 'workspace_cli_unexpected_error',
        message: e.toString(),
      );
    }
  }
}
