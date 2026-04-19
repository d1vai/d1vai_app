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

const Set<String> _markdownExtensions = <String>{
  'md',
  'markdown',
  'mdx',
  'txt',
};

const List<String> _nonEditableExtensions = <String>['.svg', '.html', '.htm'];

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
