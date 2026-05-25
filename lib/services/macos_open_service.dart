import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';

enum MacosOpenRequestSource {
  dock,
  openDocument,
  windowDrop,
  menu,
  recentWorkspace,
  picker,
  commandLine,
  unknown;

  static MacosOpenRequestSource fromRaw(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'dock':
        return MacosOpenRequestSource.dock;
      case 'opendocument':
      case 'open_document':
      case 'open-file':
      case 'openfile':
        return MacosOpenRequestSource.openDocument;
      case 'windowdrop':
      case 'window_drop':
      case 'drop':
        return MacosOpenRequestSource.windowDrop;
      case 'menu':
        return MacosOpenRequestSource.menu;
      case 'recentworkspace':
      case 'recent_workspace':
      case 'recent':
        return MacosOpenRequestSource.recentWorkspace;
      case 'picker':
      case 'filepicker':
      case 'directorypicker':
        return MacosOpenRequestSource.picker;
      case 'commandline':
      case 'command_line':
      case 'argv':
        return MacosOpenRequestSource.commandLine;
      default:
        return MacosOpenRequestSource.unknown;
    }
  }
}

class MacosOpenRequest {
  final String path;
  final bool isDirectory;
  final bool openInNewWindow;
  final MacosOpenRequestSource source;

  const MacosOpenRequest({
    required this.path,
    required this.isDirectory,
    required this.openInNewWindow,
    required this.source,
  });

  bool get isFile => !isDirectory;

  factory MacosOpenRequest.fromChannelArguments(dynamic arguments) {
    if (arguments is Map) {
      final map = arguments.cast<Object?, Object?>();
      final path = (map['path'] ?? '').toString().trim();
      final isDirectory = map['isDirectory'] == true;
      final openInNewWindow = map['openInNewWindow'] == true;
      final source = MacosOpenRequestSource.fromRaw(
        (map['source'] ?? '').toString(),
      );
      return MacosOpenRequest(
        path: path,
        isDirectory: isDirectory,
        openInNewWindow: openInNewWindow,
        source: source,
      );
    }

    final path = (arguments ?? '').toString().trim();
    return MacosOpenRequest(
      path: path,
      isDirectory: true,
      openInNewWindow: false,
      source: MacosOpenRequestSource.unknown,
    );
  }

  @override
  String toString() {
    return 'MacosOpenRequest(path: $path, isDirectory: $isDirectory, '
        'openInNewWindow: $openInNewWindow, source: ${source.name})';
  }
}

class MacosWorkspaceWindowInfo {
  final String hostIdentifier;
  final String workspacePath;
  final String entryPath;
  final String title;
  final bool focused;
  final bool visible;

  const MacosWorkspaceWindowInfo({
    required this.hostIdentifier,
    required this.workspacePath,
    required this.entryPath,
    required this.title,
    required this.focused,
    required this.visible,
  });

  factory MacosWorkspaceWindowInfo.fromChannelArguments(dynamic arguments) {
    if (arguments is! Map) {
      return const MacosWorkspaceWindowInfo(
        hostIdentifier: '',
        workspacePath: '',
        entryPath: '',
        title: '',
        focused: false,
        visible: false,
      );
    }
    final map = arguments.cast<Object?, Object?>();
    return MacosWorkspaceWindowInfo(
      hostIdentifier: (map['hostIdentifier'] ?? '').toString().trim(),
      workspacePath: (map['workspacePath'] ?? '').toString().trim(),
      entryPath: (map['entryPath'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      focused: map['focused'] == true,
      visible: map['visible'] != false,
    );
  }

  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (workspacePath.isNotEmpty) {
      final normalized = workspacePath.replaceAll(RegExp(r'[/\\]+$'), '');
      final parts = normalized.split(RegExp(r'[/\\]'));
      if (parts.isNotEmpty && parts.last.trim().isNotEmpty) {
        return parts.last.trim();
      }
    }
    return 'Local Workspace';
  }
}

class MacosOpenService extends ChangeNotifier {
  MacosOpenService._();

  static final MacosOpenService instance = MacosOpenService._();

  static const MethodChannel _channel = MethodChannel('ai.d1v.d1vai/open');

  final List<MacosOpenRequest> _pendingRequests = <MacosOpenRequest>[];
  final List<String> _pendingRoutes = <String>[];
  List<MacosWorkspaceWindowInfo> _workspaceWindows =
      const <MacosWorkspaceWindowInfo>[];
  String? _currentHostIdentifier;
  Future<void>? _initializeFuture;

  MacosOpenRequest? get pendingRequest =>
      _pendingRequests.isEmpty ? null : _pendingRequests.first;
  String? get pendingRoute =>
      _pendingRoutes.isEmpty ? null : _pendingRoutes.first;
  List<MacosWorkspaceWindowInfo> get workspaceWindows => _workspaceWindows;
  String? get currentHostIdentifier => _currentHostIdentifier;

  Future<void> initialize() async {
    if (_initializeFuture != null) {
      await _initializeFuture;
      return;
    }
    _initializeFuture = _initializeInternal();
    await _initializeFuture;
  }

  Future<void> _initializeInternal() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'openRequest':
        case 'openImportPath':
          final request = MacosOpenRequest.fromChannelArguments(call.arguments);
          debugPrint('[d1vai-open] flutter request raw=${call.arguments}');
          enqueueRequest(request);
          return;
        case 'openRoute':
          final route = _routeFromChannelArguments(call.arguments);
          if (route.isEmpty) return;
          debugPrint('[d1vai-open] flutter route raw=${call.arguments}');
          enqueueRoute(route);
          return;
        case 'workspaceWindowsChanged':
          _updateWorkspaceWindows(call.arguments);
          return;
        default:
          return;
      }
    });

    try {
      final nextHostIdentifier = await _channel.invokeMethod<String>(
        'getHostIdentifier',
      );
      if (_currentHostIdentifier != nextHostIdentifier) {
        _currentHostIdentifier = nextHostIdentifier;
        ApiClient.setRuntimeLogScope(nextHostIdentifier);
        debugPrint('[d1vai-open] flutter host=$nextHostIdentifier');
        notifyListeners();
      }
    } catch (_) {}

    await _takeInitialOpenRequest();
    await refreshWorkspaceWindows();
  }

  Future<void> _takeInitialOpenRequest() async {
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'takeInitialOpenRequest',
      );
      if (result == null) return;
      debugPrint('[d1vai-open] flutter initial request raw=$result');
      enqueueRequest(MacosOpenRequest.fromChannelArguments(result));
    } catch (e, st) {
      debugPrint('[d1vai-open] failed to take initial open request error=$e');
      debugPrintStack(stackTrace: st);
    }
  }

  String _routeFromChannelArguments(dynamic arguments) {
    if (arguments is Map) {
      final map = arguments.cast<Object?, Object?>();
      return (map['route'] ?? '').toString().trim();
    }
    return (arguments ?? '').toString().trim();
  }

  Future<bool> openPathInNewWindow(
    String path, {
    MacosOpenRequestSource source = MacosOpenRequestSource.menu,
    bool forceNewWindow = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return false;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;

    try {
      final opened =
          await _channel.invokeMethod<bool>(
            'openPathInNewWindow',
            <String, Object?>{
              'path': trimmed,
              'source': source.name,
              'forceNewWindow': forceNewWindow,
            },
          ) ??
          false;
      debugPrint(
        '[d1vai-open] flutter openPathInNewWindow result=$opened '
        'path=$trimmed source=${source.name} force=$forceNewWindow',
      );
      return opened;
    } catch (e, st) {
      debugPrint(
        '[d1vai-open] failed to open new window for path=$trimmed error=$e',
      );
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  Future<bool> openRouteInMainWindow(
    String route, {
    bool activate = true,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return false;
    final trimmed = route.trim();
    if (trimmed.isEmpty) return false;

    try {
      final opened =
          await _channel.invokeMethod<bool>(
            'openRouteInMainWindow',
            <String, Object?>{'route': trimmed, 'activate': activate},
          ) ??
          false;
      debugPrint(
        '[d1vai-open] flutter openRouteInMainWindow result=$opened '
        'route=$trimmed activate=$activate',
      );
      return opened;
    } catch (e, st) {
      debugPrint(
        '[d1vai-open] failed to open route in main window route=$trimmed error=$e',
      );
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  Future<void> setWorkspaceWindowState({
    required String workspacePath,
    required String entryPath,
    required String title,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    final normalizedWorkspacePath = workspacePath.trim();
    final normalizedEntryPath = entryPath.trim();
    if (normalizedWorkspacePath.isEmpty || normalizedEntryPath.isEmpty) return;
    try {
      await _channel
          .invokeMethod<void>('setWorkspaceWindowState', <String, Object?>{
            'workspacePath': normalizedWorkspacePath,
            'entryPath': normalizedEntryPath,
            'title': title.trim(),
          });
    } catch (e, st) {
      debugPrint(
        '[d1vai-open] failed to register workspace window '
        'workspace=$normalizedWorkspacePath entry=$normalizedEntryPath error=$e',
      );
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> clearWorkspaceWindowState() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _channel.invokeMethod<void>('clearWorkspaceWindowState');
    } catch (_) {}
  }

  Future<void> refreshWorkspaceWindows() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'listWorkspaceWindows',
      );
      _updateWorkspaceWindows(result);
    } catch (_) {}
  }

  Future<bool> activateWorkspaceWindow(String hostIdentifier) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return false;
    final trimmed = hostIdentifier.trim();
    if (trimmed.isEmpty) return false;
    try {
      final activated =
          await _channel.invokeMethod<bool>(
            'activateWorkspaceWindow',
            <String, Object?>{'hostIdentifier': trimmed},
          ) ??
          false;
      return activated;
    } catch (e, st) {
      debugPrint(
        '[d1vai-open] failed to activate workspace window host=$trimmed error=$e',
      );
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  void enqueueRequest(MacosOpenRequest request) {
    final trimmed = request.path.trim();
    if (trimmed.isEmpty) return;
    final normalized = MacosOpenRequest(
      path: trimmed,
      isDirectory: request.isDirectory,
      openInNewWindow: request.openInNewWindow,
      source: request.source,
    );
    _pendingRequests.add(normalized);
    debugPrint(
      '[d1vai-open] flutter queued request=$normalized queue=${_pendingRequests.length}',
    );
    notifyListeners();
  }

  void enqueueImportPath(String path) {
    enqueueRequest(
      MacosOpenRequest(
        path: path,
        isDirectory: true,
        openInNewWindow: false,
        source: MacosOpenRequestSource.unknown,
      ),
    );
  }

  void enqueueRoute(String route) {
    final trimmed = route.trim();
    if (trimmed.isEmpty) return;
    _pendingRoutes.add(trimmed);
    debugPrint(
      '[d1vai-open] flutter queued route=$trimmed queue=${_pendingRoutes.length}',
    );
    notifyListeners();
  }

  MacosOpenRequest? consumePendingRequest() {
    if (_pendingRequests.isEmpty) return null;
    final value = _pendingRequests.first;
    _pendingRequests.removeAt(0);
    debugPrint(
      '[d1vai-open] flutter consumed request=$value remaining=${_pendingRequests.length}',
    );
    return value;
  }

  String? consumePendingRoute() {
    if (_pendingRoutes.isEmpty) return null;
    final value = _pendingRoutes.first;
    _pendingRoutes.removeAt(0);
    debugPrint(
      '[d1vai-open] flutter consumed route=$value remaining=${_pendingRoutes.length}',
    );
    return value;
  }

  String? get pendingImportPath => pendingRequest?.path;

  String? consumePendingImportPath() => consumePendingRequest()?.path;

  void _updateWorkspaceWindows(dynamic arguments) {
    final next = arguments is List
        ? arguments
              .map(MacosWorkspaceWindowInfo.fromChannelArguments)
              .where((item) => item.hostIdentifier.isNotEmpty)
              .toList(growable: false)
        : const <MacosWorkspaceWindowInfo>[];
    _workspaceWindows = next;
    notifyListeners();
  }
}
