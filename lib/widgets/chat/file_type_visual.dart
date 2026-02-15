import 'package:flutter/material.dart';

class FileTypeVisual {
  final IconData icon;
  final Color? color;

  const FileTypeVisual({required this.icon, this.color});
}

FileTypeVisual fileTypeVisual(ThemeData theme, String path) {
  final lower = path.toLowerCase().trim();

  bool endsWithAny(List<String> exts) => exts.any(lower.endsWith);

  if (endsWithAny(const ['.dart'])) {
    return FileTypeVisual(icon: Icons.code, color: theme.colorScheme.primary);
  }
  if (endsWithAny(const ['.ts', '.tsx', '.js', '.jsx', '.py', '.rs', '.go'])) {
    return FileTypeVisual(icon: Icons.code, color: theme.colorScheme.primary);
  }
  if (endsWithAny(const ['.json'])) {
    return FileTypeVisual(
      icon: Icons.data_object,
      color: theme.colorScheme.tertiary,
    );
  }
  if (endsWithAny(const ['.md', '.markdown'])) {
    return FileTypeVisual(
      icon: Icons.description_outlined,
      color: theme.colorScheme.secondary,
    );
  }
  if (endsWithAny(const ['.css', '.scss', '.sass', '.less'])) {
    return FileTypeVisual(icon: Icons.palette_outlined, color: Colors.purple);
  }
  if (endsWithAny(const ['.html', '.htm', '.xml'])) {
    return FileTypeVisual(
      icon: Icons.language,
      color: theme.colorScheme.secondary,
    );
  }
  if (endsWithAny(const ['.yml', '.yaml', '.toml', '.ini'])) {
    return FileTypeVisual(icon: Icons.tune, color: theme.colorScheme.secondary);
  }
  if (endsWithAny(const ['.sql'])) {
    return FileTypeVisual(icon: Icons.storage, color: Colors.amber.shade700);
  }
  if (endsWithAny(const ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg'])) {
    return FileTypeVisual(icon: Icons.image_outlined, color: Colors.teal);
  }
  if (endsWithAny(const ['.lock'])) {
    return FileTypeVisual(
      icon: Icons.lock_outline,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  return FileTypeVisual(
    icon: Icons.insert_drive_file_outlined,
    color: theme.colorScheme.onSurfaceVariant,
  );
}
