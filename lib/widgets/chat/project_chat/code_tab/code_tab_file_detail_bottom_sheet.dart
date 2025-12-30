import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/d1vai_service.dart';
import '../../../snackbar_helper.dart';
import 'code_tab_code_block.dart';
import 'code_tab_models.dart';
import 'code_tab_run_migration_bottom_sheet.dart';
import 'code_tab_views.dart';

Future<void> showProjectFileDetailBottomSheet(
  BuildContext context, {
  required String projectId,
  required String filePath,
  bool autoOpenMigration = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _ProjectFileDetailSheet(
            projectId: projectId,
            filePath: filePath,
            autoOpenMigration: autoOpenMigration,
          ),
        ),
      );
    },
  );
}

class _ProjectFileDetailSheet extends StatefulWidget {
  final String projectId;
  final String filePath;
  final bool autoOpenMigration;

  const _ProjectFileDetailSheet({
    required this.projectId,
    required this.filePath,
    required this.autoOpenMigration,
  });

  @override
  State<_ProjectFileDetailSheet> createState() => _ProjectFileDetailSheetState();
}

class _ProjectFileDetailSheetState extends State<_ProjectFileDetailSheet> {
  final D1vaiService _service = D1vaiService();

  bool _loading = false;
  String? _error;
  CodeTabFileContent? _content;
  bool _migrationAutoOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isSqlFile => widget.filePath.toLowerCase().trim().endsWith('.sql');

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _content = null;
    });
    try {
      final raw = await _service.getProjectStorageFile(
        widget.projectId,
        widget.filePath,
      );
      if (!mounted) return;
      final c = CodeTabFileContent.fromJson(raw);
      setState(() {
        _content = c;
      });
      _maybeAutoOpenMigration(c);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _maybeAutoOpenMigration(CodeTabFileContent c) {
    if (!widget.autoOpenMigration) return;
    if (_migrationAutoOpened) return;
    if (!_isSqlFile) return;
    if (c.isBinary) return;
    if (c.content.trim().isEmpty) return;
    _migrationAutoOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        showRunSqlMigrationBottomSheet(
          context,
          projectId: widget.projectId,
          sql: c.content,
          sourcePath: widget.filePath,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _content;
    final canRunMigration = _isSqlFile && content != null && !content.isBinary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.code, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.filePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (canRunMigration)
                IconButton(
                  onPressed: () {
                    final c = _content;
                    if (c == null) return;
                    final sql = c.content;
                    unawaited(
                      showRunSqlMigrationBottomSheet(
                        context,
                        projectId: widget.projectId,
                        sql: sql,
                        sourcePath: widget.filePath,
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Run SQL migration',
                ),
              IconButton(
                onPressed: content == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: content.content),
                        );
                        if (!context.mounted) return;
                        SnackBarHelper.showSuccess(
                          context,
                          title: 'Copied',
                          message: 'File content copied',
                          duration: const Duration(seconds: 2),
                        );
                      },
                icon: const Icon(Icons.copy),
                tooltip: 'Copy',
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? CodeTabErrorView(
                      title: 'Failed to open file',
                      message: _error!,
                      onRetry: _load,
                    )
                  : content == null
                  ? const CodeTabEmptyView(text: 'No content')
                  : CodeTabCodeBlock(
                      filePath: widget.filePath,
                      text: content.content,
                      isBinary: content.isBinary,
                      sizeBytes: content.size,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
