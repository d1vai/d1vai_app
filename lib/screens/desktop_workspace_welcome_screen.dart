import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/macos_menu_controller.dart';
import '../services/desktop_window_service.dart';
import '../services/macos_open_service.dart';

typedef WorkspaceWindowOpenHandler =
    Future<bool> Function(String path, MacosOpenRequestSource source);
typedef WorkspacePathPicker = Future<String?> Function(bool pickDirectory);

class DesktopWorkspaceWelcomeScreen extends StatefulWidget {
  final List<MacosRecentWorkspaceEntry>? recentWorkspacesOverride;
  final WorkspaceWindowOpenHandler? openInWorkspaceWindow;
  final WorkspacePathPicker? pickPath;

  const DesktopWorkspaceWelcomeScreen({
    super.key,
    this.recentWorkspacesOverride,
    this.openInWorkspaceWindow,
    this.pickPath,
  });

  @override
  State<DesktopWorkspaceWelcomeScreen> createState() =>
      _DesktopWorkspaceWelcomeScreenState();
}

class _DesktopWorkspaceWelcomeScreenState
    extends State<DesktopWorkspaceWelcomeScreen> {
  bool _isPickingPath = false;
  String? _pendingRecentPath;

  bool get _isBusy => _isPickingPath || _pendingRecentPath != null;

  Future<void> _handlePrimaryAction({required bool pickDirectory}) async {
    if (_isBusy) return;
    setState(() {
      _isPickingPath = true;
    });

    try {
      final selectedPath = await _pickPath(pickDirectory);
      final path = (selectedPath ?? '').trim();
      if (path.isEmpty) return;
      await _openWorkspacePath(path, source: MacosOpenRequestSource.picker);
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPath = false;
        });
      }
    }
  }

  Future<void> _handleRecentWorkspaceTap(String path) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty || _isBusy) return;
    setState(() {
      _pendingRecentPath = trimmedPath;
    });

    try {
      await _openWorkspacePath(
        trimmedPath,
        source: MacosOpenRequestSource.recentWorkspace,
      );
    } finally {
      if (mounted && _pendingRecentPath == trimmedPath) {
        setState(() {
          _pendingRecentPath = null;
        });
      }
    }
  }

  Future<String?> _pickPath(bool pickDirectory) async {
    if (widget.pickPath != null) {
      return widget.pickPath!(pickDirectory);
    }

    if (pickDirectory) {
      return FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Open Folder in d1v',
      );
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      lockParentWindow: true,
      dialogTitle: 'Open File in d1v',
    );
    return result?.files.single.path;
  }

  Future<void> _openWorkspacePath(
    String path, {
    required MacosOpenRequestSource source,
  }) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) return;

    final shouldAttemptWindowOpen =
        widget.openInWorkspaceWindow != null ||
        DesktopWindowService.instance.supportsProjectWindows;

    if (shouldAttemptWindowOpen) {
      final opened = await _openInWorkspaceWindow(trimmedPath, source);
      if (opened || !mounted) return;
    }

    _openRoute(context, path: trimmedPath, source: source.name);
  }

  Future<bool> _openInWorkspaceWindow(
    String path,
    MacosOpenRequestSource source,
  ) {
    final opener = widget.openInWorkspaceWindow;
    if (opener != null) {
      return opener(path, source);
    }
    return DesktopWindowService.instance.openWorkspaceWindow(
      path,
      source: source,
    );
  }

  void _openRoute(
    BuildContext context, {
    required String path,
    required String source,
  }) {
    context.go(
      Uri(
        path: '/local-workspace',
        queryParameters: <String, String>{'path': path, 'source': source},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recentWorkspaces =
        widget.recentWorkspacesOverride ??
        context.watch<MacosMenuController>().recentWorkspaces;
    final opensSeparateWindow =
        widget.openInWorkspaceWindow != null ||
        DesktopWindowService.instance.supportsProjectWindows;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(
                colorScheme.primary.withValues(alpha: 0.07),
                colorScheme.surface,
              ),
              colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            _BackdropOrb(
              alignment: Alignment.topLeft,
              diameter: 300,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            _BackdropOrb(
              alignment: Alignment.bottomRight,
              diameter: 360,
              color: colorScheme.tertiary.withValues(alpha: 0.06),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 940;
                        final body = compact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _WorkspaceCommandPanel(
                                    isBusy: _isBusy,
                                    onOpenFolder: () => _handlePrimaryAction(
                                      pickDirectory: true,
                                    ),
                                    onOpenFile: () => _handlePrimaryAction(
                                      pickDirectory: false,
                                    ),
                                    recentCount: recentWorkspaces.length,
                                    opensSeparateWindow: opensSeparateWindow,
                                  ),
                                  const SizedBox(height: 18),
                                  _RecentWorkspaceRail(
                                    recentWorkspaces: recentWorkspaces,
                                    pendingPath: _pendingRecentPath,
                                    onOpenWorkspace: _handleRecentWorkspaceTap,
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 8,
                                    child: _WorkspaceCommandPanel(
                                      isBusy: _isBusy,
                                      onOpenFolder: () => _handlePrimaryAction(
                                        pickDirectory: true,
                                      ),
                                      onOpenFile: () => _handlePrimaryAction(
                                        pickDirectory: false,
                                      ),
                                      recentCount: recentWorkspaces.length,
                                      opensSeparateWindow: opensSeparateWindow,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 5,
                                    child: _RecentWorkspaceRail(
                                      recentWorkspaces: recentWorkspaces,
                                      pendingPath: _pendingRecentPath,
                                      onOpenWorkspace:
                                          _handleRecentWorkspaceTap,
                                    ),
                                  ),
                                ],
                              );

                        return SingleChildScrollView(child: body);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceCommandPanel extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onOpenFolder;
  final VoidCallback onOpenFile;
  final int recentCount;
  final bool opensSeparateWindow;

  const _WorkspaceCommandPanel({
    required this.isBusy,
    required this.onOpenFolder,
    required this.onOpenFile,
    required this.recentCount,
    required this.opensSeparateWindow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelBase = theme.brightness == Brightness.dark
        ? const Color(0xFF0F172A)
        : const Color(0xFF111827);
    final panelTop = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: 0.18),
      panelBase,
    );
    final panelBorder = Colors.white.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.09,
    );
    final panelMuted = Colors.white.withValues(alpha: 0.68);
    final infoItems = <_PanelInfoItem>[
      _PanelInfoItem(
        icon: Icons.open_in_new_rounded,
        label: opensSeparateWindow ? 'Workspace window' : 'Open here',
      ),
      _PanelInfoItem(
        icon: Icons.history_toggle_off_rounded,
        label: '$recentCount recent',
      ),
      const _PanelInfoItem(
        icon: Icons.folder_copy_outlined,
        label: 'Folders + files',
      ),
    ];

    return Container(
      constraints: const BoxConstraints(minHeight: 520),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [panelTop, panelBase],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: panelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -50,
              child: _PanelGlow(
                size: 220,
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -90,
              child: _PanelGlow(
                size: 260,
                color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.desktop_windows_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Local Workspace',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Open a local path\nand get back to work.',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      'Pick a folder or a single file. Recent workspaces reopen in one tap and use the same code workbench.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: panelMuted,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _WorkspaceActionButton(
                        icon: Icons.folder_open_rounded,
                        title: 'Open Folder',
                        subtitle: 'Choose a project directory',
                        emphasize: true,
                        enabled: !isBusy,
                        onTap: onOpenFolder,
                      ),
                      _WorkspaceActionButton(
                        icon: Icons.insert_drive_file_outlined,
                        title: 'Open File',
                        subtitle: 'Inspect a single entry first',
                        emphasize: false,
                        enabled: !isBusy,
                        onTap: onOpenFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: infoItems
                          .map(
                            (item) => _PanelInfoLabel(
                              icon: item.icon,
                              label: item.label,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentWorkspaceRail extends StatelessWidget {
  final List<MacosRecentWorkspaceEntry> recentWorkspaces;
  final String? pendingPath;
  final ValueChanged<String> onOpenWorkspace;

  const _RecentWorkspaceRail({
    required this.recentWorkspaces,
    required this.pendingPath,
    required this.onOpenWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        recentWorkspaces.isEmpty
                            ? 'No local workspaces yet.'
                            : '${recentWorkspaces.length} saved paths, most recent first.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (recentWorkspaces.isEmpty)
              _RecentWorkspaceEmptyState()
            else
              ...recentWorkspaces.asMap().entries.map((entry) {
                final index = entry.key;
                final workspace = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == recentWorkspaces.length - 1 ? 0 : 10,
                  ),
                  child: _RecentWorkspaceTile(
                    workspace: workspace,
                    opening: pendingPath == workspace.path,
                    onTap: () => onOpenWorkspace(workspace.path),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RecentWorkspaceTile extends StatefulWidget {
  final MacosRecentWorkspaceEntry workspace;
  final bool opening;
  final VoidCallback onTap;

  const _RecentWorkspaceTile({
    required this.workspace,
    required this.opening,
    required this.onTap,
  });

  @override
  State<_RecentWorkspaceTile> createState() => _RecentWorkspaceTileState();
}

class _RecentWorkspaceTileState extends State<_RecentWorkspaceTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = (widget.workspace.label).trim().isEmpty
        ? _workspaceDisplayName(widget.workspace.path)
        : widget.workspace.label.trim();
    final badgeColor = colorScheme.primary.withValues(
      alpha: _hovered ? 0.2 : 0.12,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('recent-workspace-${widget.workspace.path}'),
          borderRadius: BorderRadius.circular(20),
          onTap: widget.opening ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0.0,
              _hovered ? -2.0 : 0.0,
              0.0,
            ),
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              color: _hovered
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.62)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hovered
                    ? colorScheme.primary.withValues(alpha: 0.26)
                    : colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _workspaceGlyph(widget.workspace.path),
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Tooltip(
                    message: widget.workspace.path,
                    waitDuration: const Duration(milliseconds: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.workspace.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatSeenAt(widget.workspace.seenAt),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: widget.opening
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.arrow_outward_rounded,
                          key: const ValueKey('arrow'),
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentWorkspaceEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.schedule_rounded, color: colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'Nothing saved yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Open a folder once and it will show up here for quick reopen.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceActionButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasize;
  final bool enabled;
  final VoidCallback onTap;

  const _WorkspaceActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emphasize,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_WorkspaceActionButton> createState() => _WorkspaceActionButtonState();
}

class _WorkspaceActionButtonState extends State<_WorkspaceActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = Colors.white;
    final background = widget.emphasize
        ? Colors.white.withValues(alpha: _hovered ? 0.18 : 0.13)
        : Colors.white.withValues(alpha: _hovered ? 0.09 : 0.05);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0.0, _hovered ? -2.0 : 0.0, 0.0),
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: _hovered ? 0.2 : 0.12),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.enabled ? widget.onTap : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: foreground),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.68),
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelInfoItem {
  final IconData icon;
  final String label;

  const _PanelInfoItem({required this.icon, required this.label});
}

class _PanelInfoLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PanelInfoLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PanelGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _PanelGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  final Alignment alignment;
  final double diameter;
  final Color color;

  const _BackdropOrb({
    required this.alignment,
    required this.diameter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: diameter,
          height: diameter,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

String _workspaceDisplayName(String path) {
  final normalized = path.trim().replaceAll(RegExp(r'[/\\]+$'), '');
  if (normalized.isEmpty) return path.trim();
  final parts = normalized.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? normalized : parts.last;
}

IconData _workspaceGlyph(String path) {
  final displayName = _workspaceDisplayName(path);
  return displayName.contains('.') && !displayName.startsWith('.')
      ? Icons.insert_drive_file_outlined
      : Icons.folder_open_outlined;
}

String _formatSeenAt(DateTime seenAt) {
  final difference = DateTime.now().difference(seenAt);
  if (difference.inMinutes <= 0) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${seenAt.year}-${seenAt.month.toString().padLeft(2, '0')}-${seenAt.day.toString().padLeft(2, '0')}';
}
