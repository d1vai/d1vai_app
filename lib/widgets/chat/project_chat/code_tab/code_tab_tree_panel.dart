import 'package:flutter/material.dart';

import '../../file_type_visual.dart';
import 'code_tab_models.dart';
import 'code_tab_views.dart';

class CodeTabTreePanel extends StatelessWidget {
  final bool loading;
  final String? error;
  final String searchQuery;
  final List<CodeTabFlatNode> list;
  final String? selectedFilePath;
  final Set<String> expandedDirs;
  final VoidCallback onReload;
  final void Function(String dirPath) onToggleDir;
  final Future<void> Function(String path) onOpenFile;

  const CodeTabTreePanel({
    super.key,
    required this.loading,
    required this.error,
    required this.searchQuery,
    required this.list,
    required this.selectedFilePath,
    required this.expandedDirs,
    required this.onReload,
    required this.onToggleDir,
    required this.onOpenFile,
  });

  IconData _iconForFile(BuildContext context, String name) {
    return fileTypeVisual(Theme.of(context), name).icon;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? CodeTabErrorView(
              title: 'Failed to load files',
              message: error!,
              onRetry: onReload,
            )
          : list.isEmpty
          ? CodeTabEmptyView(
              text: searchQuery.isEmpty ? 'No files found' : 'No matches',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemBuilder: (context, index) {
                final item = list[index];
                final isDir = item.node.isDirectory;
                final path = item.path;
                final selected = !isDir && path == selectedFilePath;
                final dirExpanded = isDir && expandedDirs.contains(path);

                return InkWell(
                  onTap: () async {
                    if (isDir) {
                      onToggleDir(path);
                      return;
                    }
                    await onOpenFile(path);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.35,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 10.0 * item.depth),
                        Icon(
                          isDir
                              ? (dirExpanded ? Icons.folder_open : Icons.folder)
                              : _iconForFile(context, item.node.name),
                          size: 18,
                          color: isDir
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isDir)
                          Icon(
                            dirExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemCount: list.length,
            ),
    );
  }
}
