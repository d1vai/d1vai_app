import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workspace_cli_result.dart';
import '../services/macos_open_service.dart';
import '../services/workspace_cli_executor.dart';
import '../services/workspace_cli_service.dart';

enum _InspectorMode { localParser, cli }

class MacosWorkspaceInspectorCard extends StatefulWidget {
  const MacosWorkspaceInspectorCard({super.key});

  @override
  State<MacosWorkspaceInspectorCard> createState() =>
      _MacosWorkspaceInspectorCardState();
}

class _MacosWorkspaceInspectorCardState
    extends State<MacosWorkspaceInspectorCard> {
  final WorkspaceCliService _workspaceCliService = const WorkspaceCliService();
  final WorkspaceCliExecutor _workspaceCliExecutor =
      const WorkspaceCliExecutor();

  bool _loading = false;
  bool _initializing = false;
  String? _selectedDirectory;
  String? _lastConsumedPendingPath;
  WorkspaceCliResult<Map<String, dynamic>>? _result;
  _InspectorMode _mode = _InspectorMode.localParser;

  bool get _enabled => !kIsWeb && Platform.isMacOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final openService = context.watch<MacosOpenService>();
    final pending = openService.pendingImportPath;
    if (pending == null ||
        pending.isEmpty ||
        pending == _lastConsumedPendingPath) {
      return;
    }
    _lastConsumedPendingPath = pending;
    final consumed = openService.consumePendingImportPath();
    if (consumed == null || consumed.isEmpty) return;
    _inspectDirectory(consumed);
  }

  Future<void> _pickDirectory() async {
    if (!_enabled || _loading || _initializing) return;

    final selected = await FilePicker.getDirectoryPath();
    if (selected == null || selected.trim().isEmpty) return;

    await _inspectDirectory(selected);
  }

  Future<void> _inspectDirectory(String selected) async {
    if (!_enabled || _loading || _initializing) return;

    setState(() {
      _loading = true;
      _selectedDirectory = selected;
      _result = null;
    });

    final result = _mode == _InspectorMode.localParser
        ? await _workspaceCliService.inspect(selected)
        : await _workspaceCliExecutor.workspaceStatus(selected);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _initializeWorkspace() async {
    final selected = _selectedDirectory;
    if (!_enabled || _initializing || selected == null || selected.isEmpty) {
      return;
    }

    setState(() {
      _initializing = true;
    });

    final result = await _workspaceCliExecutor.workspaceInit(selected);
    if (!mounted) return;
    setState(() {
      _result = result;
      _initializing = false;
      _mode = _InspectorMode.cli;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final result = _result;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local Workspace Inspector',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a local folder and inspect its .d1v binding status.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_InspectorMode>(
              segments: const [
                ButtonSegment<_InspectorMode>(
                  value: _InspectorMode.localParser,
                  label: Text('Local Parse'),
                  icon: Icon(Icons.description_outlined),
                ),
                ButtonSegment<_InspectorMode>(
                  value: _InspectorMode.cli,
                  label: Text('CLI'),
                  icon: Icon(Icons.terminal),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _loading
                  ? null
                  : (selection) {
                      setState(() {
                        _mode = selection.first;
                        _result = null;
                      });
                    },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: (_loading || _initializing)
                      ? null
                      : _pickDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: Text(_loading ? 'Inspecting...' : 'Choose Folder'),
                ),
                if ((_selectedDirectory ?? '').isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: (_loading || _initializing)
                        ? null
                        : _initializeWorkspace,
                    icon: _initializing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Init .d1v'),
                  ),
                if ((_selectedDirectory ?? '').isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SelectableText(
                      _selectedDirectory!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: result.ok
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: result.ok
                        ? Colors.green.withValues(alpha: 0.28)
                        : Colors.orange.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.code} · ${result.ok ? 'OK' : 'CHECK'}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(result.message),
                    const SizedBox(height: 4),
                    Text(
                      'mode=${_mode.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (result.data != null) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        result.data.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
