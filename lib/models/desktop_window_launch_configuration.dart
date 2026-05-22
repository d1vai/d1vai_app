import 'package:flutter/foundation.dart';

enum DesktopWindowKind { main, workspace }

@immutable
class DesktopWorkspaceLaunchRequest {
  final String path;
  final String source;

  const DesktopWorkspaceLaunchRequest({
    required this.path,
    required this.source,
  });
}

@immutable
class DesktopWindowLaunchConfiguration {
  final DesktopWindowKind kind;
  final DesktopWorkspaceLaunchRequest? workspaceRequest;

  const DesktopWindowLaunchConfiguration({
    required this.kind,
    this.workspaceRequest,
  });

  bool get opensWorkspaceWindow =>
      kind == DesktopWindowKind.workspace && workspaceRequest != null;

  static DesktopWindowLaunchConfiguration fromArgs(List<String> args) {
    String? explicitKind;
    String? path;
    String? source;

    for (final rawArg in args) {
      final arg = rawArg.trim();
      if (arg.isEmpty) continue;

      if (arg.startsWith('--desktop-window=')) {
        explicitKind = arg.substring('--desktop-window='.length).trim();
        continue;
      }
      if (arg.startsWith('--open-path=')) {
        path = arg.substring('--open-path='.length).trim();
        continue;
      }
      if (arg.startsWith('--open-source=')) {
        source = arg.substring('--open-source='.length).trim();
        continue;
      }
      if (!arg.startsWith('--') && (path ?? '').isEmpty) {
        path = arg;
      }
    }

    final normalizedPath = (path ?? '').trim();
    final normalizedKind = (explicitKind ?? '').trim().toLowerCase();
    final shouldOpenWorkspace =
        normalizedKind == DesktopWindowKind.workspace.name ||
        normalizedPath.isNotEmpty;

    if (!shouldOpenWorkspace || normalizedPath.isEmpty) {
      return const DesktopWindowLaunchConfiguration(
        kind: DesktopWindowKind.main,
      );
    }

    return DesktopWindowLaunchConfiguration(
      kind: DesktopWindowKind.workspace,
      workspaceRequest: DesktopWorkspaceLaunchRequest(
        path: normalizedPath,
        source: (source ?? '').trim().isEmpty ? 'commandLine' : source!.trim(),
      ),
    );
  }

  static List<String> workspaceArguments({
    required String path,
    required String source,
  }) {
    final trimmedPath = path.trim();
    final trimmedSource = source.trim().isEmpty ? 'picker' : source.trim();
    return <String>[
      '--desktop-window=${DesktopWindowKind.workspace.name}',
      '--open-path=$trimmedPath',
      '--open-source=$trimmedSource',
    ];
  }
}
