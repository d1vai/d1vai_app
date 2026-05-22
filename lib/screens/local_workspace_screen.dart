import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/local_workspace.dart';
import '../providers/macos_menu_controller.dart';
import '../services/desktop_window_service.dart';
import '../services/macos_folder_import_service.dart';
import '../services/macos_open_service.dart';
import '../services/native_window_service.dart';
import '../services/workspace_local_service.dart';
import '../widgets/chat/project_chat/code_tab/project_chat_code_tab.dart';
import '../widgets/chat/project_chat/project_chat_top_bar.dart';
import '../widgets/snackbar_helper.dart';

class LocalWorkspaceScreen extends StatefulWidget {
  final String? requestedPath;
  final String? source;

  const LocalWorkspaceScreen({
    super.key,
    required this.requestedPath,
    this.source,
  });

  @override
  State<LocalWorkspaceScreen> createState() => _LocalWorkspaceScreenState();
}

class _LocalWorkspaceScreenState extends State<LocalWorkspaceScreen> {
  final WorkspaceLocalService _workspaceLocalService =
      const WorkspaceLocalService();
  final CodeTabTopBarController _codeTabTopBarController =
      CodeTabTopBarController();

  bool _loading = true;
  bool _importing = false;
  bool _openingNewWindow = false;
  String? _error;
  String? _rootPath;
  String? _initialEntryPath;
  bool _initialEntryIsFile = false;
  LocalWorkspaceState? _workspaceState;

  @override
  void initState() {
    super.initState();
    _resolveWorkspace(widget.requestedPath);
  }

  @override
  void dispose() {
    _codeTabTopBarController.reset();
    unawaited(MacosOpenService.instance.clearWorkspaceWindowState());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LocalWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestedPath == widget.requestedPath) return;
    _resolveWorkspace(widget.requestedPath);
  }

  Future<void> _resolveWorkspace(String? requestedPath) async {
    final trimmed = (requestedPath ?? '').trim();
    final startedAt = DateTime.now();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _workspaceState = null;
      _rootPath = null;
      _initialEntryPath = null;
      _initialEntryIsFile = false;
    });

    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows)) {
      unawaited(MacosOpenService.instance.clearWorkspaceWindowState());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Local workspace windows are only available on macOS and Windows.';
      });
      return;
    }

    if (trimmed.isEmpty) {
      unawaited(MacosOpenService.instance.clearWorkspaceWindowState());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No local file or folder was provided.';
      });
      return;
    }

    try {
      final entityType = FileSystemEntity.typeSync(trimmed, followLinks: true);
      if (entityType == FileSystemEntityType.notFound) {
        throw Exception('The selected path does not exist anymore.');
      }

      final resolvedRootPath = entityType == FileSystemEntityType.file
          ? File(trimmed).parent.path
          : trimmed;
      final state = await _workspaceLocalService.inspectDirectory(
        resolvedRootPath,
      );
      final projectId = (state.config?.projectId ?? '').trim();
      debugPrint(
        '[d1vai-open] local workspace resolved root=$resolvedRootPath '
        'entry=$trimmed status=${state.status.name} '
        'project=${projectId.isEmpty ? 'local-only' : projectId} '
        'elapsed=${DateTime.now().difference(startedAt).inMilliseconds}ms',
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _workspaceState = state;
        _rootPath = resolvedRootPath;
        _initialEntryPath = trimmed;
        _initialEntryIsFile = entityType == FileSystemEntityType.file;
      });
      unawaited(
        MacosOpenService.instance.setWorkspaceWindowState(
          workspacePath: resolvedRootPath,
          entryPath: trimmed,
          title: _lastSegment(resolvedRootPath),
        ),
      );
      unawaited(
        NativeWindowService.instance.configureCurrentWorkspaceWindow(
          title: _lastSegment(resolvedRootPath),
        ),
      );
      unawaited(
        context.read<MacosMenuController>().registerLocalWorkspaceVisit(
          path: trimmed,
          label: _lastSegment(trimmed),
        ),
      );
    } catch (e) {
      debugPrint(
        '[d1vai-open] local workspace resolve failed path=$trimmed '
        'elapsed=${DateTime.now().difference(startedAt).inMilliseconds}ms '
        'error=$e',
      );
      unawaited(MacosOpenService.instance.clearWorkspaceWindowState());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _initialEntryIsFile = false;
      });
    }
  }

  Future<void> _activateWorkspaceWindow(String hostIdentifier) async {
    final activated = await MacosOpenService.instance.activateWorkspaceWindow(
      hostIdentifier,
    );
    if (activated || !mounted) return;
    SnackBarHelper.showError(
      context,
      title: 'Window unavailable',
      message: 'This workspace window is no longer available.',
    );
  }

  String _normalizePath(String path) =>
      path.trim().replaceAll(RegExp(r'[/\\]+$'), '');

  String _lastSegment(String path) {
    final normalized = _normalizePath(path);
    if (normalized.isEmpty) return path;
    final parts = normalized.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? normalized : parts.last;
  }

  String? _formattedSourceLabel() {
    final raw = (widget.source ?? '').trim();
    if (raw.isEmpty) return null;
    switch (raw.toLowerCase()) {
      case 'dock':
        return 'Opened from Dock';
      case 'opendocument':
      case 'open_document':
        return 'Opened by macOS';
      case 'windowdrop':
      case 'window_drop':
      case 'drop':
        return 'Dropped into window';
      case 'menu':
        return 'Opened from File menu';
      case 'recentworkspace':
      case 'recent_workspace':
      case 'recent':
        return 'Opened from recent workspaces';
      case 'picker':
        return 'Chosen in app';
      case 'commandline':
      case 'command_line':
      case 'argv':
        return 'Opened from desktop launcher';
      default:
        return raw;
    }
  }

  Future<void> _openCurrentInNewWindow() async {
    final path = (_initialEntryPath ?? _rootPath ?? '').trim();
    if (path.isEmpty || _openingNewWindow) return;
    debugPrint('[d1vai-open] local workspace new-window requested path=$path');
    setState(() {
      _openingNewWindow = true;
    });
    try {
      final opened = await DesktopWindowService.instance.openWorkspaceWindow(
        path,
        source: MacosOpenRequestSource.menu,
      );
      debugPrint(
        '[d1vai-open] local workspace new-window result=$opened path=$path',
      );
      if (!opened && mounted) {
        SnackBarHelper.showError(
          context,
          title: 'New window failed',
          message: 'd1v could not open a new local workspace window.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingNewWindow = false;
        });
      }
    }
  }

  Future<void> _switchFolder() async {
    if (_loading) return;
    final selected = await FilePicker.platform.getDirectoryPath();
    if (selected == null || selected.trim().isEmpty || !mounted) return;
    final uri = Uri(
      path: '/local-workspace',
      queryParameters: {'path': selected.trim(), 'source': 'picker'},
    );
    context.go(uri.toString());
  }

  String _revealActionLabel() =>
      Platform.isWindows ? 'Reveal in Explorer' : 'Reveal in Finder';

  String _revealFailureTitle() =>
      Platform.isWindows ? 'Open in Explorer failed' : 'Open in Finder failed';

  Future<void> _revealInFileManager() async {
    final rootPath = (_rootPath ?? '').trim();
    if (rootPath.isEmpty) return;
    try {
      await launchUrl(Uri.file(rootPath), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _revealFailureTitle(),
        message: e.toString(),
      );
    }
  }

  bool get _canImportToCloud => !kIsWeb && Platform.isMacOS;

  Future<void> _importCurrentFolder() async {
    final rootPath = (_rootPath ?? '').trim();
    if (rootPath.isEmpty || _importing) return;
    setState(() {
      _importing = true;
    });
    try {
      await MacosFolderImportService.instance.importPath(context, rootPath);
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
        });
      }
    }
  }

  void _openLinkedProject() {
    final projectId = (_workspaceState?.config?.projectId ?? '').trim();
    if (projectId.isEmpty) return;
    context.go('/projects/$projectId?tab=chat&chatTab=code');
  }

  void _askAboutLocalFile(String prompt) {
    final projectId = (_workspaceState?.config?.projectId ?? '').trim();
    if (projectId.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: 'Local workspace only',
        message: 'Bind this folder to a d1v project to continue with AI chat.',
      );
      return;
    }
    final uri = Uri(
      path: '/projects/$projectId/chat',
      queryParameters: {'autoprompt': prompt},
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openService = context.watch<MacosOpenService>();
    final workspaceState = _workspaceState;
    final rootPath = _rootPath;
    final linkedProjectId = (workspaceState?.config?.projectId ?? '').trim();
    final linkedProjectName =
        (workspaceState?.config?.projectName ?? '').trim().isNotEmpty
        ? workspaceState!.config!.projectName!.trim()
        : linkedProjectId;
    final sourceLabel = _formattedSourceLabel();
    final entryPath = (_initialEntryPath ?? '').trim();
    final openedFileLabel = _initialEntryIsFile
        ? _lastSegment(entryPath)
        : null;
    final revealActionLabel = _revealActionLabel();
    final currentHostIdentifier = openService.currentHostIdentifier;
    final otherWorkspaceWindows = openService.workspaceWindows
        .where((item) => item.hostIdentifier != currentHostIdentifier)
        .toList(growable: false);

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Opening local workspace...'),
            ],
          ),
        ),
      );
    }

    if (_error != null || rootPath == null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to open local workspace',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _switchFolder,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Choose Another Folder'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 320 || constraints.maxHeight < 220) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastSegment(rootPath),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.96),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final compactHeader = headerConstraints.maxWidth < 980;
                      final headerIcon = Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.folder_open_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      );
                      final headerMeta = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _lastSegment(rootPath),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              _HeaderBadge(
                                label: linkedProjectId.isEmpty
                                    ? 'Local only'
                                    : 'Connected to d1v',
                                color: linkedProjectId.isEmpty
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.tertiary,
                              ),
                              if (sourceLabel != null)
                                _HeaderBadge(
                                  label: sourceLabel,
                                  color: theme.colorScheme.secondary,
                                ),
                              if (openedFileLabel != null)
                                _HeaderBadge(
                                  label: 'File: $openedFileLabel',
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rootPath,
                            maxLines: compactHeader ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (openedFileLabel != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Starts with $openedFileLabel in this workspace',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (linkedProjectId.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              linkedProjectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      );
                      final actionButtons = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: compactHeader
                            ? WrapAlignment.start
                            : WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openingNewWindow
                                ? null
                                : _openCurrentInNewWindow,
                            icon: _openingNewWindow
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.open_in_new_outlined),
                            label: const Text('New Window'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _switchFolder,
                            icon: const Icon(Icons.swap_horiz_outlined),
                            label: const Text('Switch Folder'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _revealInFileManager,
                            icon: const Icon(Icons.folder_outlined),
                            label: Text(revealActionLabel),
                          ),
                          if (linkedProjectId.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: _openLinkedProject,
                              icon: const Icon(Icons.launch_outlined),
                              label: const Text('Open Cloud Project'),
                            ),
                          if (_canImportToCloud)
                            FilledButton.icon(
                              onPressed: _importing
                                  ? null
                                  : _importCurrentFolder,
                              icon: _importing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text(
                                _importing ? 'Importing...' : 'Import to Cloud',
                              ),
                            ),
                        ],
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (compactHeader) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                headerIcon,
                                const SizedBox(width: 12),
                                Expanded(child: headerMeta),
                              ],
                            ),
                            const SizedBox(height: 12),
                            actionButtons,
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                headerIcon,
                                const SizedBox(width: 12),
                                Expanded(child: headerMeta),
                                const SizedBox(width: 12),
                                Flexible(child: actionButtons),
                              ],
                            ),
                          const SizedBox(height: 14),
                          _LocalWorkspaceToolbar(
                            controller: _codeTabTopBarController,
                          ),
                          if (otherWorkspaceWindows.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Open windows',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                for (final window in otherWorkspaceWindows)
                                  OutlinedButton.icon(
                                    onPressed: () => unawaited(
                                      _activateWorkspaceWindow(
                                        window.hostIdentifier,
                                      ),
                                    ),
                                    icon: Icon(
                                      window.focused
                                          ? Icons.radio_button_checked
                                          : Icons.open_in_new,
                                      size: 16,
                                    ),
                                    label: Text(window.displayTitle),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: ProjectChatCodeTab(
                    key: ValueKey(
                      'local-workspace:${_initialEntryPath ?? rootPath}:${linkedProjectId.isEmpty ? 'local' : linkedProjectId}',
                    ),
                    projectId: linkedProjectId.isEmpty ? null : linkedProjectId,
                    topBarController: _codeTabTopBarController,
                    initialLocalEntryPath: _initialEntryPath ?? rootPath,
                    initialLocalHybridMode: linkedProjectId.isNotEmpty,
                    onDetachLocalWorkspace: _switchFolder,
                    onAsk: _askAboutLocalFile,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _HeaderBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LocalWorkspaceToolbar extends StatelessWidget {
  final CodeTabTopBarController controller;

  const _LocalWorkspaceToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final searchController = controller.searchController;
        final searchText = searchController?.text.trim() ?? '';
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final searchWidth = constraints.maxWidth >= 1120
                ? 280.0
                : constraints.maxWidth >= 820
                ? 220.0
                : constraints.maxWidth >= 560
                ? 180.0
                : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: narrow ? constraints.maxWidth : 160,
                    maxWidth: searchWidth,
                  ),
                  child: TextField(
                    controller: searchController,
                    enabled: searchController != null,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: searchController == null
                          ? 'Loading files…'
                          : 'Search files…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: searchText.isEmpty
                          ? null
                          : IconButton(
                              onPressed: searchController?.clear,
                              icon: const Icon(Icons.clear, size: 16),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                _ToolbarIconButton(
                  icon: Icons.refresh_outlined,
                  tooltip: 'Refresh files',
                  onPressed: controller.loadingTree
                      ? null
                      : controller.onReload,
                ),
                _ToolbarIconButton(
                  icon: Icons.search_outlined,
                  tooltip: 'Find in file',
                  onPressed: controller.activeEditing
                      ? controller.onFind
                      : null,
                ),
                _ToolbarIconButton(
                  icon: controller.activeWrapEnabled
                      ? Icons.wrap_text
                      : Icons.wrap_text_outlined,
                  tooltip: controller.activeWrapEnabled
                      ? 'Disable wrap'
                      : 'Enable wrap',
                  onPressed: controller.activeEditing
                      ? controller.onToggleWrap
                      : null,
                ),
                _ToolbarIconButton(
                  icon: Icons.save_as_outlined,
                  tooltip: 'Save file',
                  onPressed:
                      controller.activeSaving ||
                          !controller.activeHasUnsavedChanges
                      ? null
                      : controller.onSave,
                ),
                _ToolbarIconButton(
                  icon: Icons.tips_and_updates_outlined,
                  tooltip: 'Ask AI about file',
                  onPressed: controller.hasSelection ? controller.onAsk : null,
                ),
                _ToolbarSyncChip(
                  state: controller.syncState,
                  hasLocalWorkspace: controller.hasLocalWorkspace,
                  colorScheme: theme.colorScheme,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ToolbarSyncChip extends StatelessWidget {
  final CodeTabTopBarSyncState state;
  final bool hasLocalWorkspace;
  final ColorScheme colorScheme;

  const _ToolbarSyncChip({
    required this.state,
    required this.hasLocalWorkspace,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      CodeTabTopBarSyncState.localSaved => (
        'Saved locally',
        colorScheme.primary,
      ),
      CodeTabTopBarSyncState.queued => ('Queued', Colors.orange),
      CodeTabTopBarSyncState.syncingCloud => (
        'Cloud sync',
        colorScheme.secondary,
      ),
      CodeTabTopBarSyncState.syncingGitHub => ('Syncing', colorScheme.tertiary),
      CodeTabTopBarSyncState.synced => ('Synced', Colors.green),
      CodeTabTopBarSyncState.failed => ('Sync failed', Colors.redAccent),
      CodeTabTopBarSyncState.idle => (
        hasLocalWorkspace ? 'Local workspace' : 'Cloud workspace',
        colorScheme.onSurfaceVariant,
      ),
    };

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
