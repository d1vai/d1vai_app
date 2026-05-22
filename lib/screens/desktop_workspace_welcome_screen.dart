import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/macos_menu_controller.dart';

class DesktopWorkspaceWelcomeScreen extends StatelessWidget {
  const DesktopWorkspaceWelcomeScreen({super.key});

  Future<void> _openPath(
    BuildContext context, {
    required bool pickDirectory,
  }) async {
    String? selectedPath;

    if (pickDirectory) {
      selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Open Folder in d1v',
      );
    } else {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        lockParentWindow: true,
        dialogTitle: 'Open File in d1v',
      );
      selectedPath = result?.files.single.path;
    }

    final path = (selectedPath ?? '').trim();
    if (path.isEmpty || !context.mounted) return;
    _openRoute(context, path: path, source: pickDirectory ? 'picker' : 'menu');
  }

  void _openRecentWorkspace(BuildContext context, String path) {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) return;
    _openRoute(context, path: trimmedPath, source: 'recentWorkspace');
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
    final menuController = context.watch<MacosMenuController>();
    final recentWorkspaces = menuController.recentWorkspaces;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 860;
                  final content = <Widget>[
                    _WelcomeHero(
                      onOpenFolder: () =>
                          _openPath(context, pickDirectory: true),
                      onOpenFile: () =>
                          _openPath(context, pickDirectory: false),
                    ),
                    const SizedBox(height: 18),
                    _RecentWorkspacePanel(
                      recentWorkspaces: recentWorkspaces,
                      onOpenWorkspace: (path) =>
                          _openRecentWorkspace(context, path),
                    ),
                  ];

                  if (compact) {
                    return ListView(children: content);
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: content.first),
                      const SizedBox(width: 18),
                      Expanded(flex: 5, child: content.last),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  final VoidCallback onOpenFolder;
  final VoidCallback onOpenFile;

  const _WelcomeHero({required this.onOpenFolder, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.12),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.folder_open_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Open a local project',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Use a dedicated project window for lightweight local editing with the existing high-density workbench UI.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onOpenFolder,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open Folder'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenFile,
                icon: const Icon(Icons.insert_drive_file_outlined),
                label: const Text('Open File'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _WelcomeChip(label: 'Fast startup'),
              _WelcomeChip(label: 'High-density UI'),
              _WelcomeChip(label: 'Reuse current editor'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentWorkspacePanel extends StatelessWidget {
  final List<MacosRecentWorkspaceEntry> recentWorkspaces;
  final ValueChanged<String> onOpenWorkspace;

  const _RecentWorkspacePanel({
    required this.recentWorkspaces,
    required this.onOpenWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent workspaces',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Reopen a recent local project in this window.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (recentWorkspaces.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'No recent local projects yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...recentWorkspaces.map(
              (workspace) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpenWorkspace(workspace.path),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workspace.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                workspace.path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeChip extends StatelessWidget {
  final String label;

  const _WelcomeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
