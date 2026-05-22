import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/desktop_window_launch_configuration.dart';
import 'macos_open_service.dart';

class DesktopWindowService {
  const DesktopWindowService();

  static const DesktopWindowService instance = DesktopWindowService();

  bool get supportsProjectWindows {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows;
  }

  Future<bool> openWorkspaceWindow(
    String path, {
    MacosOpenRequestSource source = MacosOpenRequestSource.menu,
  }) async {
    if (!supportsProjectWindows) return false;
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) return false;

    if (Platform.isMacOS) {
      return MacosOpenService.instance.openPathInNewWindow(
        trimmedPath,
        source: source,
        forceNewWindow: true,
      );
    }

    if (Platform.isWindows) {
      return _openWindowsWorkspaceProcess(trimmedPath, source: source.name);
    }

    return false;
  }

  Future<bool> _openWindowsWorkspaceProcess(
    String path, {
    required String source,
  }) async {
    final executable = Platform.resolvedExecutable.trim();
    if (executable.isEmpty) return false;

    try {
      await Process.start(
        executable,
        DesktopWindowLaunchConfiguration.workspaceArguments(
          path: path,
          source: source,
        ),
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (e, st) {
      debugPrint(
        '[d1vai-open] failed to spawn windows workspace process '
        'path=$path source=$source error=$e',
      );
      debugPrintStack(stackTrace: st);
      return false;
    }
  }
}
