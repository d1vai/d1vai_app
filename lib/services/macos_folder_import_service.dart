import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/project_provider.dart';
import 'd1vai_service.dart';

enum MacosFolderImportStage {
  idle,
  preparing,
  compressing,
  uploading,
  finalizing,
  failed,
}

class MacosFolderImportService extends ChangeNotifier {
  MacosFolderImportService._();

  static final MacosFolderImportService instance = MacosFolderImportService._();

  bool _busy = false;
  MacosFolderImportStage _stage = MacosFolderImportStage.idle;
  String _message = '';
  String? _currentImportPath;
  String? _error;

  bool get busy => _busy;
  MacosFolderImportStage get stage => _stage;
  String get message => _message;
  String? get currentImportPath => _currentImportPath;
  String? get error => _error;

  Future<void> importPath(
    BuildContext context,
    String importPath,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS || _busy) {
      debugPrint(
        '[d1vai-drop] importPath skipped path=$importPath kIsWeb=$kIsWeb platform=$defaultTargetPlatform busy=$_busy',
      );
      return;
    }

    final trimmedPath = importPath.trim();
    if (trimmedPath.isEmpty) return;
    debugPrint('[d1vai-drop] importPath start path=$trimmedPath');
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);

    try {
      final entityType = FileSystemEntity.typeSync(trimmedPath);
      if (entityType == FileSystemEntityType.notFound) {
        throw Exception('Import path not found: $trimmedPath');
      }
      final isDirectory = entityType == FileSystemEntityType.directory;
      final isFile = entityType == FileSystemEntityType.file;
      if (!isDirectory && !isFile) {
        throw Exception('Only folders and files can be imported.');
      }

      _setState(
        busy: true,
        stage: MacosFolderImportStage.preparing,
        message: isDirectory
            ? 'Preparing local folder…'
            : 'Preparing local file…',
        currentImportPath: trimmedPath,
        error: null,
      );

      _showProgressDialog(context);
      debugPrint('[d1vai-drop] importPath progress dialog shown path=$trimmedPath');

      final projectName = _deriveProjectName(trimmedPath);

      _setState(
        stage: MacosFolderImportStage.compressing,
        message: isDirectory
            ? 'Compressing local folder…'
            : 'Packaging local file…',
      );

      final archiveBytes = await _zipImportPath(
        trimmedPath,
        isDirectory: isDirectory,
      );
      debugPrint(
        '[d1vai-drop] importPath archive built path=$trimmedPath bytes=${archiveBytes.length}',
      );
      if (archiveBytes.isEmpty) {
        throw Exception('Generated archive is empty.');
      }

      _setState(
        stage: MacosFolderImportStage.uploading,
        message: 'Uploading project…',
      );

      final service = D1vaiService();
      final result = await service.importProjectFromLocal(
        archiveBytes: archiveBytes,
        archiveFileName: '$projectName.zip',
        projectName: projectName,
        isPrivate: true,
      );

      final projectId = _extractProjectId(result);
      debugPrint('[d1vai-drop] importPath upload complete projectId=$projectId');
      if (projectId == null || projectId.isEmpty) {
        throw Exception('Import succeeded but project ID is missing.');
      }

      _setState(
        stage: MacosFolderImportStage.finalizing,
        message: 'Opening chat code…',
      );

      await projectProvider.refresh();

      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      router.go('/projects/$projectId?tab=chat&chatTab=code');
      debugPrint('[d1vai-drop] importPath navigation complete projectId=$projectId');

      _setState(
        busy: false,
        stage: MacosFolderImportStage.idle,
        message: '',
        currentImportPath: null,
        error: null,
      );
    } catch (e) {
      debugPrint('[d1vai-drop] importPath failed path=$trimmedPath error=$e');
      _setState(
        busy: false,
        stage: MacosFolderImportStage.failed,
        message: 'Import failed',
        currentImportPath: trimmedPath,
        error: '$e',
      );
    }
  }

  Future<void> importDirectory(BuildContext context, String directoryPath) {
    return importPath(context, directoryPath);
  }

  Future<Uint8List> _zipImportPath(
    String importPath, {
    required bool isDirectory,
  }) async {
    final tempDirectory = await Directory.systemTemp.createTemp('d1vai-import-');
    final archiveBaseName = _deriveProjectName(importPath);
    final archivePath = '${tempDirectory.path}/$archiveBaseName.zip';

    try {
      final result = isDirectory
          ? await _zipDirectory(
              directoryPath: importPath,
              archivePath: archivePath,
            )
          : await _zipFile(filePath: importPath, archivePath: archivePath);

      if (result.exitCode != 0) {
        throw Exception(
          'Failed to package import: ${result.stderr.toString().trim()}',
        );
      }

      return await File(archivePath).readAsBytes();
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<ProcessResult> _zipDirectory({
    required String directoryPath,
    required String archivePath,
  }) {
    return Process.run('ditto', [
      '-c',
      '-k',
      '--sequesterRsrc',
      '--keepParent',
      directoryPath,
      archivePath,
    ]);
  }

  Future<ProcessResult> _zipFile({
    required String filePath,
    required String archivePath,
  }) {
    return Process.run('ditto', [
      '-c',
      '-k',
      '--sequesterRsrc',
      filePath,
      archivePath,
    ]);
  }

  String _deriveProjectName(String importPath) {
    final raw = _lastSegment(importPath);
    if (raw.isEmpty) return 'local-project';
    final dotIndex = raw.lastIndexOf('.');
    if (dotIndex <= 0) return raw;
    final trimmed = raw.substring(0, dotIndex).trim();
    return trimmed.isEmpty ? raw : trimmed;
  }

  String _lastSegment(String path) {
    final normalized = path.replaceAll(RegExp(r'[/\\]+$'), '');
    final segments = normalized.split(RegExp(r'[/\\]'));
    return segments.isEmpty ? '' : segments.last.trim();
  }

  String? _extractProjectId(Map<String, dynamic> result) {
    final nested = result['data'];
    final payload = nested is Map<String, dynamic>
        ? nested
        : nested is Map
        ? nested.cast<String, dynamic>()
        : result;
    final project = payload['project'] is Map<String, dynamic>
        ? payload['project'] as Map<String, dynamic>
        : payload['project'] is Map
        ? (payload['project'] as Map).cast<String, dynamic>()
        : payload;
    return project['id']?.toString() ??
        payload['project_id']?.toString() ??
        payload['id']?.toString();
  }

  void _showProgressDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MacosFolderImportProgressDialog(),
    );
  }

  void _setState({
    bool? busy,
    MacosFolderImportStage? stage,
    String? message,
    String? currentImportPath,
    String? error,
  }) {
    _busy = busy ?? _busy;
    _stage = stage ?? _stage;
    _message = message ?? _message;
    _currentImportPath = currentImportPath ?? _currentImportPath;
    _error = error;
    notifyListeners();
  }
}

class _MacosFolderImportProgressDialog extends StatelessWidget {
  const _MacosFolderImportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return Consumer<MacosFolderImportService>(
      builder: (context, service, _) {
        final path = service.currentImportPath ?? '';
        final isFailed = service.stage == MacosFolderImportStage.failed;

        return AlertDialog(
          title: Text(isFailed ? 'Import failed' : 'Uploading local project'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isFailed) const LinearProgressIndicator(),
                if (!isFailed) const SizedBox(height: 16),
                Text(service.message),
                if (path.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    path,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if ((service.error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    service.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isFailed)
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Close'),
              ),
          ],
        );
      },
    );
  }
}
