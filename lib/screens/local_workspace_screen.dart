import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';

import '../models/local_workspace.dart';
import '../providers/auth_provider.dart';
import '../providers/macos_menu_controller.dart';
import '../providers/profile_provider.dart';
import '../services/macos_folder_import_service.dart';
import '../services/macos_open_service.dart';
import '../services/native_window_service.dart';
import '../services/workspace_local_service.dart';
import '../screens/settings/profile_tab.dart';
import '../utils/desktop_layout.dart';
import '../widgets/avatar_image.dart';
import '../widgets/chat/project_chat/code_tab/project_chat_code_tab.dart';
import '../widgets/editor_preferences_dialog.dart';
import '../widgets/adaptive_modal.dart';
import '../widgets/login_required_dialog.dart';
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
  static const MethodChannel _windowChannel = MethodChannel(
    'ai.d1v.d1vai/window',
  );
  static const double _macosTitleBarHeight = 34;
  static const double _macosTrafficLightsInset = 80;

  final WorkspaceLocalService _workspaceLocalService =
      const WorkspaceLocalService();
  bool _loading = true;
  bool _showProfileSidebar = false;
  String? _error;
  String? _rootPath;
  String? _initialEntryPath;
  LocalWorkspaceState? _workspaceState;
  int _selectedTabIndex = 0;

  static const List<_LocalWorkspaceDesktopTab> _desktopTabs = [
    _LocalWorkspaceDesktopTab(
      'Chat',
      Icons.chat_bubble_outline,
      projectTabName: 'chat',
    ),
    _LocalWorkspaceDesktopTab(
      'Environment',
      Icons.key_outlined,
      projectTabName: 'environment',
    ),
    _LocalWorkspaceDesktopTab(
      'Database',
      Icons.storage_outlined,
      projectTabName: 'database',
    ),
    _LocalWorkspaceDesktopTab(
      'Payment',
      Icons.credit_card_outlined,
      projectTabName: 'payment',
    ),
    _LocalWorkspaceDesktopTab(
      'Deploy',
      Icons.rocket_launch_outlined,
      projectTabName: 'deployment',
    ),
    _LocalWorkspaceDesktopTab(
      'Analytics',
      Icons.analytics_outlined,
      projectTabName: 'analytics',
    ),
    _LocalWorkspaceDesktopTab(
      'Overview',
      Icons.dashboard_outlined,
      projectTabName: 'overview',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _resolveWorkspace(widget.requestedPath);
  }

  @override
  void dispose() {
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
      });
    }
  }

  String _normalizePath(String path) =>
      path.trim().replaceAll(RegExp(r'[/\\]+$'), '');

  String _lastSegment(String path) {
    final normalized = _normalizePath(path);
    if (normalized.isEmpty) return path;
    final parts = normalized.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? normalized : parts.last;
  }

  bool get _isCloudConnected =>
      ((_workspaceState?.config?.projectId ?? '').trim().isNotEmpty);

  String get _syncToCloudMessage =>
      'Sync this local workspace to a cloud project first to use this feature.';

  void _showSyncToCloudDialog({String? feature}) {
    final label = (feature ?? 'This feature').trim();
    final loc = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sync to cloud first'),
        content: Text(
          '$label requires a synced cloud project.\n\n$_syncToCloudMessage',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc?.translate('cancel') ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_importCurrentFolder());
            },
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
  }

  void _handleDesktopTabSelected(int index) {
    if (index == 0) {
      setState(() {
        _selectedTabIndex = 0;
      });
      return;
    }

    if (!_isCloudConnected) {
      _showSyncToCloudDialog(feature: _desktopTabs[index].label);
      return;
    }

    unawaited(_openLinkedProjectTab(index));
  }

  Future<void> _beginMacosWindowDrag() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _windowChannel.invokeMethod<void>('beginWindowDrag');
    } catch (_) {}
  }

  void _toggleProfileSidebar() {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      showDialog(
        context: context,
        builder: (_) => const LoginRequiredDialog(
          message: 'Please login first to access your profile and cloud sync.',
        ),
      );
      return;
    }
    setState(() {
      _showProfileSidebar = !_showProfileSidebar;
    });
  }

  void _closeProfileSidebar() {
    if (!_showProfileSidebar) return;
    setState(() {
      _showProfileSidebar = false;
    });
  }

  void _showThemeDialog() {
    final theme = Theme.of(context);
    showAdaptiveModal(
      context: context,
      builder: (context) => AdaptiveModalContainer(
        maxWidth: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Theme',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Use Settings in the main app to change the theme.'),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditorPreferencesDialog() {
    showAdaptiveModal(
      context: context,
      builder: (_) => const EditorPreferencesDialogBody(),
    );
  }

  void _showBindEmailDialog() {
    _showSyncToCloudDialog(feature: 'Account settings');
  }

  void _showResetPasswordDialog() {
    _showSyncToCloudDialog(feature: 'Password reset');
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'd1v.ai',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.apps, size: 48),
      children: const [
        Text('Local workspace editing with optional cloud sync.'),
      ],
    );
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

  Future<void> _importCurrentFolder() async {
    final rootPath = (_rootPath ?? '').trim();
    if (rootPath.isEmpty) return;
    await MacosFolderImportService.instance.importPath(context, rootPath);
  }

  bool get _shouldOpenCloudRouteInMainWindow {
    final hostIdentifier =
        (context.read<MacosOpenService>().currentHostIdentifier ??
                MacosOpenService.instance.currentHostIdentifier ??
                '')
            .trim();
    return hostIdentifier.isNotEmpty && hostIdentifier != 'main';
  }

  String _linkedProjectRoute(String projectId, int index) {
    final projectTabName = _desktopTabs[index].projectTabName;
    final queryParameters = <String, String>{'tab': projectTabName};
    if (projectTabName == 'chat') {
      queryParameters['chatTab'] = 'code';
    }
    return Uri(
      path: '/projects/$projectId',
      queryParameters: queryParameters,
    ).toString();
  }

  Future<void> _openCloudRoute(String route, {bool push = false}) async {
    if (_shouldOpenCloudRouteInMainWindow) {
      final opened = await MacosOpenService.instance.openRouteInMainWindow(
        route,
      );
      if (opened || !mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Main window unavailable',
        message: 'd1v could not open this page in the main window.',
      );
      return;
    }
    if (!mounted) return;
    if (push) {
      context.push(route);
      return;
    }
    context.go(route);
  }

  Future<void> _openLinkedProjectTab(int index) async {
    final projectId = (_workspaceState?.config?.projectId ?? '').trim();
    if (projectId.isEmpty) {
      _showSyncToCloudDialog(feature: 'Cloud project');
      return;
    }
    await _openCloudRoute(_linkedProjectRoute(projectId, index));
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
    unawaited(_openCloudRoute(uri.toString(), push: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = MediaQuery.of(context).size.width >= 1024;
    final isMacosDesktop =
        desktop && !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final workspaceState = _workspaceState;
    final rootPath = _rootPath;
    final linkedProjectId = (workspaceState?.config?.projectId ?? '').trim();
    final linkedProjectName =
        (workspaceState?.config?.projectName ?? '').trim().isNotEmpty
        ? workspaceState!.config!.projectName!.trim()
        : linkedProjectId;

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

    final body = _buildWorkspaceBody(
      context,
      theme,
      workspaceState,
      rootPath,
      linkedProjectId,
      linkedProjectName,
    );

    if (!isMacosDesktop) {
      return Scaffold(backgroundColor: theme.colorScheme.surface, body: body);
    }

    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          Column(
            children: [
              _buildMacosWorkspaceTitleBar(
                context,
                title: _lastSegment(rootPath),
              ),
              Expanded(child: body),
            ],
          ),
          if (_showProfileSidebar) _buildProfileSidebarOverlay(context),
        ],
      ),
    );
  }

  Widget _buildWorkspaceBody(
    BuildContext context,
    ThemeData theme,
    LocalWorkspaceState? workspaceState,
    String rootPath,
    String linkedProjectId,
    String linkedProjectName,
  ) {
    final desktop = MediaQuery.of(context).size.width >= 1024;
    final isMacosDesktop =
        desktop && !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

    Widget content = LayoutBuilder(
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

        final editor = ProjectChatCodeTab(
          key: ValueKey(
            'local-workspace:${_initialEntryPath ?? rootPath}:${linkedProjectId.isEmpty ? 'local' : linkedProjectId}',
          ),
          projectId: linkedProjectId.isEmpty ? null : linkedProjectId,
          initialLocalEntryPath: _initialEntryPath ?? rootPath,
          initialLocalHybridMode: linkedProjectId.isNotEmpty,
          onDetachLocalWorkspace: _switchFolder,
          onAsk: _askAboutLocalFile,
        );

        if (!isMacosDesktop) {
          return Column(children: [Expanded(child: editor)]);
        }

        return DesktopContentFrame(
          maxWidth: 1520,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ClipRect(
            child: Column(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: theme.colorScheme.surface),
                    child: editor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (isMacosDesktop) {
      return content;
    }

    return SafeArea(child: content);
  }

  Widget _buildMacosWorkspaceTitleBar(
    BuildContext context, {
    required String title,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: _macosTitleBarHeight,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  const SizedBox(width: _macosTrafficLightsInset),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.05,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _LocalWorkspaceDesktopTabs(
                              tabs: _desktopTabs,
                              selectedIndex: _selectedTabIndex,
                              onSelected: _handleDesktopTabSelected,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LocalWorkspaceProfileButton(
                    onPressed: _toggleProfileSidebar,
                    onLoginPressed: () => context.go('/login'),
                    active: _showProfileSidebar,
                  ),
                  const SizedBox(width: 6),
                  _MacosWindowDragArea(
                    onDragStart: _beginMacosWindowDrag,
                    child: const SizedBox(width: 28, height: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSidebarOverlay(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            top: _macosTitleBarHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeProfileSidebar,
              child: Container(color: Colors.black.withValues(alpha: 0.16)),
            ),
          ),
          Positioned(
            top: _macosTitleBarHeight,
            bottom: 0,
            left: 0,
            width: 380,
            child: ChangeNotifierProvider(
              create: (_) => ProfileProvider(),
              child: Material(
                elevation: 14,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Profile',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              onPressed: _closeProfileSidebar,
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      Expanded(
                        child: SettingsProfileTab(
                          onShowThemeDialog: _showThemeDialog,
                          onShowEditorPreferencesDialog:
                              _showEditorPreferencesDialog,
                          onShowBindEmailDialog: _showBindEmailDialog,
                          onShowResetPasswordDialog: _showResetPasswordDialog,
                          onShowAboutDialog: _showAboutDialog,
                        ),
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

class _LocalWorkspaceDesktopTab {
  final String label;
  final IconData icon;
  final String projectTabName;

  const _LocalWorkspaceDesktopTab(
    this.label,
    this.icon, {
    required this.projectTabName,
  });
}

class _LocalWorkspaceDesktopTabs extends StatelessWidget {
  final List<_LocalWorkspaceDesktopTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _LocalWorkspaceDesktopTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _LocalWorkspaceDesktopTabChip(
              label: tabs[i].label,
              icon: tabs[i].icon,
              selected: selectedIndex == i,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocalWorkspaceDesktopTabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LocalWorkspaceDesktopTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.92)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? colorScheme.outlineVariant.withValues(alpha: 0.65)
                  : colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalWorkspaceProfileButton extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback onLoginPressed;
  final bool active;

  const _LocalWorkspaceProfileButton({
    required this.onPressed,
    required this.onLoginPressed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return TextButton(
        onPressed: onLoginPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: const Text('Login'),
      );
    }

    return Tooltip(
      message: 'Profile',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: active
                ? colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? colorScheme.primary.withValues(alpha: 0.24)
                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: user.picture.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: AvatarImage(
                    imageUrl: user.picture,
                    size: 24,
                    borderRadius: BorderRadius.circular(999),
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(
                  Icons.person_outline,
                  size: 14,
                  color: active
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}

class _MacosWindowDragArea extends StatelessWidget {
  final Widget child;
  final VoidCallback onDragStart;

  const _MacosWindowDragArea({required this.child, required this.onDragStart});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => onDragStart(),
        onDoubleTap: onDragStart,
        child: child,
      ),
    );
  }
}
