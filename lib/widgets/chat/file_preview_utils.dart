bool isEditableFilePreview(String path, bool isBinary) {
  if (isBinary) return false;
  if (isMindJsonPreview(path)) return true;
  return _editablePreviewExtensions.contains(fileExtensionForPath(path));
}

bool isCopyableFilePreview(String path, bool isBinary) {
  if (!isBinary) return true;
  return isSvgPreview(path, '');
}

bool isMarkdownPreview(String path) {
  return _markdownExtensions.contains(fileExtensionForPath(path));
}

bool isJsonPreview(String path) {
  final ext = fileExtensionForPath(path);
  return ext == 'json' || ext == 'jsonc' || ext == 'har';
}

bool isJsonLinesPreview(String path) {
  final ext = fileExtensionForPath(path);
  return ext == 'jsonl' || ext == 'ndjson';
}

bool isMindJsonPreview(String path) {
  return path.toLowerCase().endsWith('.mind.json');
}

bool isSvgPreview(String path, String content) {
  if (fileExtensionForPath(path) == 'svg') return true;
  return content.trimLeft().startsWith('<svg');
}

bool isHtmlPreview(String path) {
  final ext = fileExtensionForPath(path);
  return ext == 'html' || ext == 'htm';
}

bool isImagePreview(String path) {
  return _imageExtensions.contains(fileExtensionForPath(path));
}

bool isVideoPreview(String path) {
  return _videoExtensions.contains(fileExtensionForPath(path));
}

bool isAudioPreview(String path) {
  return _audioExtensions.contains(fileExtensionForPath(path));
}

bool isPdfPreview(String path) {
  return fileExtensionForPath(path) == 'pdf';
}

bool isEpubPreview(String path) {
  return fileExtensionForPath(path) == 'epub';
}

bool isXmlStructuredPreview(String path) {
  return fileExtensionForPath(path) == 'xml';
}

bool isDocxPreview(String path) {
  return fileExtensionForPath(path) == 'docx';
}

bool isSpreadsheetPreview(String path) {
  return _spreadsheetExtensions.contains(fileExtensionForPath(path));
}

bool isPresentationPreview(String path) {
  return _presentationExtensions.contains(fileExtensionForPath(path));
}

bool isArchivePreview(String path) {
  return _archiveExtensions.contains(fileExtensionForPath(path));
}

bool isXMindPreview(String path) {
  return fileExtensionForPath(path) == 'xmind';
}

bool isLegacyOfficePreview(String path) {
  return _legacyOfficeExtensions.contains(fileExtensionForPath(path));
}

bool shouldPreferBrowserImagePreview(String path) {
  return _browserImageExtensions.contains(fileExtensionForPath(path));
}

String fileExtensionForPath(String path) {
  final lower = path.toLowerCase().trim();
  final parts = lower.split('.');
  return parts.lastOrNull ?? '';
}

String? mimeTypeForPath(String path) {
  for (final entry in _mimeTypes.entries) {
    if (fileExtensionForPath(path) == entry.key) return entry.value;
  }
  return null;
}

const Set<String> _markdownExtensions = <String>{
  'md',
  'markdown',
  'mdx',
  'txt',
};

const Set<String> _editablePreviewExtensions = <String>{
  'txt',
  'md',
  'markdown',
  'mdx',
  'json',
  'jsonc',
  'har',
  'jsonl',
  'ndjson',
  'yaml',
  'yml',
  'toml',
  'xml',
  'csv',
  'tsv',
  'js',
  'jsx',
  'ts',
  'tsx',
  'dart',
  'py',
  'go',
  'rs',
  'java',
  'kt',
  'swift',
  'c',
  'cpp',
  'h',
  'hpp',
  'css',
  'scss',
  'sass',
  'less',
  'sh',
  'bash',
  'zsh',
  'sql',
  'env',
  'mind.json',
};

const Set<String> _imageExtensions = <String>{
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'ico',
  'tif',
  'tiff',
  'avif',
  'heic',
  'heif',
};

const Set<String> _videoExtensions = <String>{
  'mp4',
  'm4v',
  'mov',
  'avi',
  'mkv',
  'webm',
  'mpeg',
  'mpg',
  'wmv',
};

const Set<String> _audioExtensions = <String>{
  'mp3',
  'wav',
  'm4a',
  'flac',
  'aac',
  'ogg',
  'opus',
  'weba',
};

const Set<String> _archiveExtensions = <String>{
  'zip',
};

const Set<String> _spreadsheetExtensions = <String>{
  'csv',
  'tsv',
  'xlsx',
  'xls',
  'ods',
};

const Set<String> _presentationExtensions = <String>{'pptx'};

const Set<String> _legacyOfficeExtensions = <String>{'doc', 'xls', 'ppt'};

const Set<String> _browserImageExtensions = <String>{
  'ico',
  'avif',
  'heic',
  'heif',
};

const Map<String, String> _mimeTypes = <String, String>{
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'ico': 'image/x-icon',
  'tif': 'image/tiff',
  'tiff': 'image/tiff',
  'avif': 'image/avif',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'mp4': 'video/mp4',
  'm4v': 'video/x-m4v',
  'mov': 'video/quicktime',
  'avi': 'video/x-msvideo',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  'mpeg': 'video/mpeg',
  'mpg': 'video/mpeg',
  'wmv': 'video/x-ms-wmv',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'm4a': 'audio/mp4',
  'flac': 'audio/flac',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'opus': 'audio/opus',
  'weba': 'audio/webm',
  'pdf': 'application/pdf',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx':
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'csv': 'text/csv',
  'tsv': 'text/tab-separated-values',
  'zip': 'application/zip',
};

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
