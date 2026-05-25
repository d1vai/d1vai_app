class ProjectFileLinkTarget {
  final String path;
  final int? line;
  final int? column;

  const ProjectFileLinkTarget({required this.path, this.line, this.column});

  String get requestKey => '$path#${line ?? ''}:${column ?? ''}';
}

class ProjectFileLinkRequest {
  final int requestId;
  final ProjectFileLinkTarget target;

  const ProjectFileLinkRequest({required this.requestId, required this.target});
}

String _normalizeProjectPath(String path) {
  return path
      .trim()
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '')
      .replaceFirst(RegExp(r'^\./+'), '')
      .replaceAll(RegExp(r'/+'), '/');
}

bool _looksLikeProjectFilePath(String path) {
  final hasFileLikeExtension = RegExp(
    r'\.(?:[a-z0-9]{1,8})$',
    caseSensitive: false,
  ).hasMatch(path);
  final hasKnownFileName = RegExp(
    r'(^|/)(?:Dockerfile|Makefile|README|LICENSE)(?:\.[^/\s]+)?$',
    caseSensitive: false,
  ).hasMatch(path);
  final hasPathSegments = path.contains('/');

  return hasFileLikeExtension || hasKnownFileName || hasPathSegments;
}

ProjectFileLinkTarget? parseProjectFileLinkTarget(String rawHref) {
  final raw = rawHref.trim();
  if (raw.isEmpty || raw.startsWith('#') || raw.startsWith('/')) {
    return null;
  }
  if (RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(raw)) {
    return null;
  }

  final hashIndex = raw.indexOf('#');
  final queryIndex = raw.indexOf('?');
  final splitIndex = switch ((hashIndex, queryIndex)) {
    (-1, -1) => raw.length,
    (-1, _) => queryIndex,
    (_, -1) => hashIndex,
    _ => hashIndex < queryIndex ? hashIndex : queryIndex,
  };
  final pathPart = raw.substring(0, splitIndex).trim();
  if (pathPart.isEmpty) return null;

  String decodedPath;
  try {
    decodedPath = Uri.decodeComponent(pathPart);
  } catch (_) {
    decodedPath = pathPart;
  }

  final normalized = _normalizeProjectPath(decodedPath);
  if (normalized.isEmpty || normalized == '.' || normalized == '..') {
    return null;
  }
  if (normalized.endsWith('/')) return null;

  final segments = normalized.split('/').where((segment) => segment.isNotEmpty);
  if (segments.isEmpty) return null;
  if (segments.any((segment) => segment == '.' || segment == '..')) {
    return null;
  }

  final joined = segments.join('/');
  if (!_looksLikeProjectFilePath(joined)) {
    return null;
  }

  final fragment = hashIndex >= 0 ? raw.substring(hashIndex + 1).trim() : '';
  final lineMatch = RegExp(
    r'^(?:L|line-)(\d+)(?::(\d+))?(?:-L?\d+)?$',
    caseSensitive: false,
  ).firstMatch(fragment);
  final line = lineMatch == null ? null : int.tryParse(lineMatch.group(1)!);
  final column = lineMatch == null
      ? null
      : int.tryParse(lineMatch.group(2) ?? '');

  return ProjectFileLinkTarget(path: joined, line: line, column: column);
}
