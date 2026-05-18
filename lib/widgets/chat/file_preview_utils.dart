bool isEditableFilePreview(String path, bool isBinary) {
  if (isBinary) return false;
  final lower = path.toLowerCase();
  return !_markdownExtensions.contains(lower.split('.').lastOrNull ?? '') &&
      !_nonEditableExtensions.any((suffix) => lower.endsWith(suffix));
}

bool isCopyableFilePreview(String path, bool isBinary) {
  if (!isBinary) return true;
  final lower = path.toLowerCase();
  return lower.endsWith('.svg');
}

bool isMarkdownPreview(String path) {
  final lower = path.toLowerCase();
  return _markdownExtensions.any((suffix) => lower.endsWith('.$suffix'));
}

bool isJsonPreview(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.json') ||
      lower.endsWith('.jsonc') ||
      lower.endsWith('.har');
}

bool isSvgPreview(String path, String content) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.svg')) return true;
  return content.trimLeft().startsWith('<svg');
}

bool isHtmlPreview(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.html') || lower.endsWith('.htm');
}

bool isImagePreview(String path) {
  final lower = path.toLowerCase();
  return _imageExtensions.any((suffix) => lower.endsWith('.$suffix'));
}

bool isVideoPreview(String path) {
  final lower = path.toLowerCase();
  return _videoExtensions.any((suffix) => lower.endsWith('.$suffix'));
}

bool isAudioPreview(String path) {
  final lower = path.toLowerCase();
  return _audioExtensions.any((suffix) => lower.endsWith('.$suffix'));
}

String? mimeTypeForPath(String path) {
  final lower = path.toLowerCase();
  for (final entry in _mimeTypes.entries) {
    if (lower.endsWith('.${entry.key}')) return entry.value;
  }
  return null;
}

const Set<String> _markdownExtensions = <String>{
  'md',
  'markdown',
  'mdx',
  'txt',
};

const List<String> _nonEditableExtensions = <String>['.svg', '.html', '.htm'];

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
};

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
