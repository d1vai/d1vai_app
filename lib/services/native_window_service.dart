import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart' as nativeapi;

class NativeWindowService {
  NativeWindowService._();

  static final NativeWindowService instance = NativeWindowService._();

  final Set<int> _expandedWorkspaceWindowIds = <int>{};

  Future<void> configureCurrentWorkspaceWindow({
    required String title,
    bool ensureComfortableSize = true,
  }) async {
    if (kIsWeb || !Platform.isMacOS) return;

    try {
      final windowManager = nativeapi.WindowManager.instance;
      final currentWindow =
          windowManager.getCurrent() ??
          (windowManager.getAll().isNotEmpty ? windowManager.getAll().first : null);
      if (currentWindow == null) return;

      final trimmedTitle = title.trim();
      if (trimmedTitle.isNotEmpty) {
        currentWindow.title = 'd1v $trimmedTitle';
      }

      currentWindow.setMinimumSize(980, 680);

      if (!ensureComfortableSize) return;

      final size = currentWindow.size;
      final needsExpansion = size.width < 1180 || size.height < 760;
      if (!needsExpansion || _expandedWorkspaceWindowIds.contains(currentWindow.id)) {
        debugPrint(
          '[native-window] workspace window ready '
          'id=${currentWindow.id} title="${currentWindow.title}" '
          'size=${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
        );
        return;
      }

      currentWindow.setSize(1400, 900, animate: true);
      currentWindow.center();
      currentWindow.focus();
      _expandedWorkspaceWindowIds.add(currentWindow.id);
      debugPrint(
        '[native-window] expanded workspace window '
        'id=${currentWindow.id} title="${currentWindow.title}"',
      );
    } catch (e, st) {
      debugPrint('[native-window] failed to configure workspace window: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}
