import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../l10n/app_localizations.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../snackbar_helper.dart';

/// Project-managed storage. Source/workspace files intentionally belong to the
/// editor instead of this project integration surface.
class ProjectStorageTab extends StatefulWidget {
  final UserProject project;
  final D1vaiService? service;

  const ProjectStorageTab({super.key, required this.project, this.service});

  @override
  State<ProjectStorageTab> createState() => _ProjectStorageTabState();
}

class _ProjectStorageTabState extends State<ProjectStorageTab> {
  late final D1vaiService _service = widget.service ?? D1vaiService();
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _files = const [];
  bool _loading = true;
  bool _refreshingFiles = false;
  bool _enabling = false;
  bool _deleting = false;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _provisioned =>
      _status?['enabled'] == true && _status?['provisioned'] == true;

  Future<void> _load({bool filesOnly = false}) async {
    if (filesOnly) {
      setState(() => _refreshingFiles = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final status = filesOnly
          ? _status
          : await _service.getProjectStorageStatus(widget.project.id);
      final provisioned =
          status?['enabled'] == true && status?['provisioned'] == true;
      final files = provisioned
          ? await _service.getProjectStorageFiles(widget.project.id)
          : const <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _status = status;
        _files = files;
        _loading = false;
        _refreshingFiles = false;
      });
    } catch (cause) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(cause);
        _loading = false;
        _refreshingFiles = false;
      });
    }
  }

  Future<void> _enable() async {
    setState(() => _enabling = true);
    try {
      await _service.ensureProjectStorage(widget.project.id);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Storage enabled',
        message: 'Project storage is ready to use.',
      );
      await _load();
    } catch (cause) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Unable to enable storage',
          message: humanizeError(cause),
        );
      }
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  List<Map<String, dynamic>> get _filteredFiles {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _files;
    return _files
        .where((file) => _fileName(file).toLowerCase().contains(query))
        .toList(growable: false);
  }

  String _fileName(Map<String, dynamic> file) =>
      (file['originalName'] ??
              file['original_name'] ??
              file['name'] ??
              file['id'] ??
              'File')
          .toString();

  bool _isImage(Map<String, dynamic> file) {
    final mime = (file['mimeType'] ?? file['mime_type'] ?? '')
        .toString()
        .toLowerCase();
    if (mime.startsWith('image/')) return true;
    final extension = _fileName(file).split('.').last.toLowerCase();
    return const {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'svg',
    }.contains(extension);
  }

  IconData _fileIcon(Map<String, dynamic> file) {
    if (_isImage(file)) return Icons.image_outlined;
    final extension = _fileName(file).split('.').last.toLowerCase();
    if (const {
      'js',
      'jsx',
      'ts',
      'tsx',
      'py',
      'go',
      'rs',
      'java',
      'json',
      'html',
      'css',
    }.contains(extension)) {
      return Icons.code_outlined;
    }
    return Icons.description_outlined;
  }

  Future<void> _preview(Map<String, dynamic> file) async {
    final id = file['id']?.toString() ?? '';
    if (id.isEmpty || !_isImage(file)) return;
    try {
      final bytes = await _service.getManagedProjectStorageFilePreview(
        widget.project.id,
        id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) =>
            _ImagePreviewDialog(name: _fileName(file), bytes: bytes),
      );
    } catch (cause) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Unable to preview file',
          message: humanizeError(cause),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(
          'Delete ${_fileName(file)} from project storage? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    final id = file['id']?.toString() ?? '';
    if (confirmed != true || id.isEmpty || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _service.deleteManagedProjectStorageFile(widget.project.id, id);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'File deleted',
        message: _fileName(file),
      );
      await _load(filesOnly: true);
    } catch (cause) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Unable to delete file',
          message: humanizeError(cause),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  dynamic _usage(String key) =>
      _status?['usage'] is Map ? _status!['usage'][key] : null;
  dynamic _billing(String key) =>
      _status?['billing'] is Map ? _status!['billing'][key] : null;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _StorageLoading();
    if (_error != null) return _StorageError(message: _error!, onRetry: _load);
    if (!_provisioned) {
      return _StorageEnablePanel(enabling: _enabling, onEnable: _enable);
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .7),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Storage usage',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  return GridView.count(
                    crossAxisCount: compact ? 2 : 4,
                    childAspectRatio: compact ? 2.25 : 1.65,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StorageMetric(
                        'Stored',
                        _formatBytes(_usage('storedBytes')),
                        Icons.storage_outlined,
                      ),
                      _StorageMetric(
                        'Download',
                        _formatBytes(_usage('downloadBytes')),
                        Icons.download_outlined,
                      ),
                      _StorageMetric(
                        'Write',
                        _formatNumber(_usage('writeOps')),
                        Icons.build_outlined,
                      ),
                      _StorageMetric(
                        'Read',
                        _formatNumber(_usage('readOps')),
                        Icons.menu_book_outlined,
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 28),
              Row(
                children: [
                  Icon(
                    Icons.sync_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last sync',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(_billing('lastUsageSyncedAt')),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _buildFilesHeader(theme),
              const SizedBox(height: 8),
              if (_filteredFiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      _search.isEmpty ? 'No files yet.' : 'No matching files.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ..._filteredFiles.map(
                  (file) => _StorageFileRow(
                    file: file,
                    name: _fileName(file),
                    isImage: _isImage(file),
                    icon: _fileIcon(file),
                    deleting: _deleting,
                    onPreview: () => _preview(file),
                    onDelete: () => _delete(file),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilesHeader(ThemeData theme) => LayoutBuilder(
    builder: (context, constraints) {
      final search = SizedBox(
        width: constraints.maxWidth < 420 ? double.infinity : 176,
        height: 38,
        child: TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Search files',
            prefixIcon: Icon(Icons.search, size: 18),
            border: OutlineInputBorder(),
          ),
        ),
      );
      final title = Text(
        'Files',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      );
      final refresh = IconButton(
        tooltip: 'Refresh files',
        visualDensity: VisualDensity.compact,
        onPressed: _refreshingFiles ? null : () => _load(filesOnly: true),
        icon: _refreshingFiles
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      );
      if (constraints.maxWidth < 420) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [title, const Spacer(), refresh]),
            const SizedBox(height: 8),
            search,
          ],
        );
      }
      return Row(
        children: [
          title,
          const Spacer(),
          refresh,
          const SizedBox(width: 6),
          search,
        ],
      );
    },
  );
}

class _StorageLoading extends StatelessWidget {
  const _StorageLoading();
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                loc?.translate('loading') ?? 'Loading...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const _ShimmerBlock(height: 164),
        const SizedBox(height: 16),
        const _ShimmerBlock(height: 260),
      ],
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double height;
  const _ShimmerBlock({required this.height});
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

class _StorageError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _StorageError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 32),
          const SizedBox(height: 12),
          const Text('Unable to load storage'),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _StorageEnablePanel extends StatelessWidget {
  final bool enabling;
  final VoidCallback onEnable;
  const _StorageEnablePanel({required this.enabling, required this.onEnable});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storage_outlined, size: 32),
              const SizedBox(height: 16),
              Text(
                'Enable project storage',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Give this project managed storage for application files, previews, and usage tracking.',
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: enabling ? null : onEnable,
                  icon: enabling
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    enabling ? 'Enabling storage...' : 'Enable storage',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StorageMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StorageMetric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StorageFileRow extends StatelessWidget {
  final Map<String, dynamic> file;
  final String name;
  final bool isImage;
  final IconData icon;
  final bool deleting;
  final VoidCallback onPreview;
  final VoidCallback onDelete;
  const _StorageFileRow({
    required this.file,
    required this.name,
    required this.isImage,
    required this.icon,
    required this.deleting,
    required this.onPreview,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              icon,
              size: 19,
              color: isImage ? colors.tertiary : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Text(
            _formatBytes(file['size']),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          IconButton(
            tooltip: 'Preview image',
            onPressed: isImage ? onPreview : null,
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: 'Delete file',
            onPressed: deleting ? null : onDelete,
            color: colors.error,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewDialog extends StatelessWidget {
  final String name;
  final Uint8List bytes;
  const _ImagePreviewDialog({required this.name, required this.bytes});
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
      child: InteractiveViewer(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Padding(
            padding: EdgeInsets.all(32),
            child: Text('This image cannot be displayed.'),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

String _formatBytes(dynamic value) {
  final bytes = num.tryParse('${value ?? 0}')?.toDouble() ?? 0;
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var current = bytes;
  var unit = 0;
  while (current >= 1024 && unit < units.length - 1) {
    current /= 1024;
    unit++;
  }
  return '${current.toStringAsFixed(current >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

String _formatNumber(dynamic value) {
  final number = num.tryParse('${value ?? 0}')?.toDouble() ?? 0;
  if (number <= 0) return '0';
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
  return number.toStringAsFixed(0);
}

String _formatDate(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return '-';
  final parsed = DateTime.tryParse('$value')?.toLocal();
  if (parsed == null) return '$value';
  return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}
