import 'dart:io';

import 'package:flutter/foundation.dart';

class LocalWorkspaceFileTree {
  final Map<String, dynamic> root;
  final int directoryCount;
  final int fileCount;

  const LocalWorkspaceFileTree({
    required this.root,
    required this.directoryCount,
    required this.fileCount,
  });
}

class LocalWorkspaceReadResult {
  final String path;
  final String content;
  final int size;
  final bool isBinary;

  const LocalWorkspaceReadResult({
    required this.path,
    required this.content,
    required this.size,
    required this.isBinary,
  });
}

class LocalWorkspaceService {
  const LocalWorkspaceService();

  static const Set<String> _ignoredDirectoryNames = <String>{
    '.git',
    '.dart_tool',
    '.idea',
    '.next',
    '.nuxt',
    '.turbo',
    '.vscode',
    'build',
    'dist',
    'node_modules',
    'Pods',
    '.DS_Store',
  };

  Future<LocalWorkspaceFileTree> readTree(
    String rootPath, {
    int maxDepth = 12,
    int maxEntriesPerDirectory = 300,
  }) async {
    _ensureSupportedDesktop();
    final normalizedRoot = _normalizeRoot(rootPath);
    final rootDir = Directory(normalizedRoot);
    if (!await rootDir.exists()) {
      throw Exception('Local folder not found.');
    }

    int dirCount = 0;
    int fileCount = 0;

    Future<Map<String, dynamic>> walk(Directory dir, int depth) async {
      final basename = _lastSegment(dir.path);
      final children = <Map<String, dynamic>>[];

      if (depth < maxDepth) {
        final entries = <FileSystemEntity>[];
        await for (final entity in dir.list(followLinks: false)) {
          final name = _lastSegment(entity.path);
          if (_shouldIgnoreName(name)) continue;
          entries.add(entity);
        }

        entries.sort((a, b) {
          final aDir = a is Directory;
          final bDir = b is Directory;
          if (aDir != bDir) return aDir ? -1 : 1;
          return _lastSegment(a.path).compareTo(_lastSegment(b.path));
        });

        final limited = entries.take(maxEntriesPerDirectory);
        for (final entity in limited) {
          if (entity is Directory) {
            dirCount += 1;
            children.add(await walk(entity, depth + 1));
            continue;
          }

          fileCount += 1;
          children.add(<String, dynamic>{
            'name': _lastSegment(entity.path),
            'is_directory': false,
            'size': null,
            'children': null,
          });
        }
      }

      return <String, dynamic>{
        'name': depth == 0 ? basename : _lastSegment(dir.path),
        'is_directory': true,
        'size': null,
        'children': children,
      };
    }

    return LocalWorkspaceFileTree(
      root: await walk(rootDir, 0),
      directoryCount: dirCount,
      fileCount: fileCount,
    );
  }

  Future<LocalWorkspaceReadResult> readFile(
    String rootPath,
    String relativePath,
  ) async {
    _ensureSupportedDesktop();
    final file = File(_joinRootAndRelative(rootPath, relativePath));
    if (!await file.exists()) {
      throw Exception('Local file not found.');
    }
    final size = await file.length();
    final sample = await _readSampleBytes(file, maxBytes: 8192);
    final binary = _looksBinary(sample);
    return LocalWorkspaceReadResult(
      path: relativePath,
      content: binary ? '' : await file.readAsString(),
      size: size,
      isBinary: binary,
    );
  }

  Future<void> writeFile(
    String rootPath,
    String relativePath,
    String content,
  ) async {
    _ensureSupportedDesktop();
    final file = File(_joinRootAndRelative(rootPath, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<String> renameEntry(
    String rootPath,
    String relativePath, {
    required String newName,
    required bool isDirectory,
  }) async {
    _ensureSupportedDesktop();
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Name cannot be empty.');
    }
    if (trimmedName.contains('/') || trimmedName.contains(r'\')) {
      throw Exception('Name cannot contain path separators.');
    }

    final normalizedRelative = relativePath.replaceAll(RegExp(r'^[\/\\]+'), '');
    final segments = normalizedRelative
        .split(RegExp(r'[/\\]'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      throw Exception('Root folder cannot be renamed here.');
    }

    final parentSegments = segments.length > 1
        ? segments.sublist(0, segments.length - 1)
        : const <String>[];
    final nextRelative = [
      ...parentSegments,
      trimmedName,
    ].join('/');

    final sourcePath = _joinRootAndRelative(rootPath, normalizedRelative);
    final targetPath = _joinRootAndRelative(rootPath, nextRelative);
    final sourceEntity = isDirectory ? Directory(sourcePath) : File(sourcePath);
    final targetExists = await FileSystemEntity.type(targetPath) !=
        FileSystemEntityType.notFound;
    if (targetExists) {
      throw Exception('An item with this name already exists.');
    }
    await sourceEntity.rename(targetPath);
    return nextRelative;
  }

  void _ensureSupportedDesktop() {
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows)) {
      throw Exception(
        'Local workspace access is only supported on macOS and Windows.',
      );
    }
  }

  String _normalizeRoot(String path) =>
      path.trim().replaceAll(RegExp(r'[/\\]+$'), '');

  String _joinRootAndRelative(String rootPath, String relativePath) {
    final cleanRoot = _normalizeRoot(rootPath);
    final cleanRelative = relativePath.replaceAll(RegExp(r'^[\/\\]+'), '');
    return '$cleanRoot/$cleanRelative';
  }

  String _lastSegment(String path) {
    final normalized = path.replaceAll(RegExp(r'[/\\]+$'), '');
    if (normalized.isEmpty) return path;
    final parts = normalized.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? normalized : parts.last;
  }

  bool _shouldIgnoreName(String name) {
    if (name.isEmpty) return true;
    if (_ignoredDirectoryNames.contains(name)) return true;
    return false;
  }

  bool _looksBinary(List<int> bytes) {
    if (bytes.isEmpty) return false;
    int suspicious = 0;
    final sampleLength = bytes.length < 8000 ? bytes.length : 8000;
    for (var i = 0; i < sampleLength; i += 1) {
      final byte = bytes[i];
      if (byte == 0) return true;
      final isCommonText =
          byte == 9 || byte == 10 || byte == 13 || (byte >= 32 && byte <= 126);
      if (!isCommonText) {
        suspicious += 1;
      }
    }
    return suspicious / sampleLength > 0.2;
  }

  Future<List<int>> _readSampleBytes(File file, {required int maxBytes}) async {
    final raf = await file.open();
    try {
      return await raf.read(maxBytes);
    } finally {
      await raf.close();
    }
  }
}
