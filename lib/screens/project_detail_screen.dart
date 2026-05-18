import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../models/project.dart';
import '../providers/auth_provider.dart';
import '../providers/macos_menu_controller.dart';
import '../providers/project_provider.dart';
import '../services/d1vai_service.dart';
import '../utils/error_utils.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/project_analytics/project_analytics_tab.dart';
import '../widgets/project_api/project_api_tab.dart';
import '../widgets/project_chat/project_chat_tab.dart';
import '../widgets/project_database/project_database_tab.dart';
import '../widgets/project_deploy/project_deploy_tab.dart';
import '../widgets/project_overview/project_overview_tab.dart';
import '../widgets/project_payment/project_payment_tab.dart';
import '../widgets/d1v_tab_bar_view.dart';
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';
import '../theme/d1v_theme_colors.dart';
import '../core/auth_expiry_bus.dart';
import '../l10n/app_localizations.dart';
import '../utils/desktop_layout.dart';
import 'dart:ui';
import '../widgets/skeletons/project_overview_skeleton.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String? initialTab;
  final String? initialChatTab;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.initialTab,
    this.initialChatTab,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _windowChannel = MethodChannel(
    'ai.d1v.d1vai/window',
  );
  static const double _macosTitleBarHeight = 34;
  static const double _macosTrafficLightsInset = 80;

  late final TabController _tabController;
  late final MacosMenuController _macosMenuController;
  late BuildContext _stableUiContext;
  final GlobalKey<ProjectChatTabState> _chatTabKey =
      GlobalKey<ProjectChatTabState>();

  UserProject? _project;
  bool _isLoading = true;
  String? _error;

  final List<_TabItem> _tabs = const [
    _TabItem('project_detail_tab_chat', 'Chat', Icons.chat),
    _TabItem('project_detail_tab_environment', 'Environment', Icons.key),
    _TabItem('project_detail_tab_database', 'Database', Icons.storage),
    _TabItem('project_detail_tab_payment', 'Payment', Icons.payment),
    _TabItem('project_detail_tab_deploy', 'Deploy', Icons.cloud_upload),
    _TabItem('project_detail_tab_analytics', 'Analytics', Icons.analytics),
    _TabItem('project_detail_tab_overview', 'Overview', Icons.dashboard),
  ];

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  String _translateWithContext(
    BuildContext context,
    String key,
    String fallback,
  ) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _macosMenuController = Provider.of<MacosMenuController>(
      context,
      listen: false,
    );
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _tabIndexFromName(widget.initialTab),
    );

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLoginRequiredDialog();
      });
      return;
    }

    // Populate immediately (enables Hero on first frame), then refresh async.
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final cached = projectProvider.getProjectById(widget.projectId);
    if (cached != null) {
      _project = cached;
      _isLoading = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProject();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stableUiContext = Navigator.of(context, rootNavigator: true).context;
  }

  int _tabIndexFromName(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    if (t.isEmpty) return 0;
    switch (t) {
      case 'chat':
        return 0;
      case 'environment':
      case 'env':
      case 'variables':
      case 'api':
        return 1;
      case 'database':
      case 'db':
        return 2;
      case 'payment':
      case 'billing':
        return 3;
      case 'deploy':
      case 'deployment':
      case 'logs':
        return 4;
      case 'analytics':
        return 5;
      case 'overview':
        return 6;
      default:
        return 0;
    }
  }

  Future<void> _loadProject({bool forceNetwork = false}) async {
    final shouldShowBlocking = _project == null;
    setState(() {
      _isLoading = shouldShowBlocking;
      _error = null;
    });

    try {
      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );

      var project = projectProvider.getProjectById(widget.projectId);
      final hasBranch =
          (project?.workspaceCurrentBranch ??
                  project?.repositoryCurrentBranch ??
                  '')
              .trim()
              .isNotEmpty;

      // Fast-path: show cached list item immediately to avoid blank UI.
      if (project != null) {
        setState(() {
          _project = project;
          _isLoading = false;
        });
        unawaited(_macosMenuController.registerProjectVisit(project));
      }

      // Force a fresh detail fetch when requested (for example after enabling
      // payments), otherwise keep the existing fast-path and only fetch when
      // key runtime fields are missing.
      if (forceNetwork || project == null || !hasBranch) {
        final service = D1vaiService();
        final fresh = await service.getUserProjectById(widget.projectId);
        if (!mounted) return;
        setState(() {
          _project = fresh;
          _isLoading = false;
        });
        unawaited(_macosMenuController.registerProjectVisit(fresh));
      }
    } catch (e) {
      final message = humanizeError(e);
      if (isAuthExpiredText(message)) {
        AuthExpiryBus.trigger(endpoint: '/api/projects/${widget.projectId}');
        return;
      }
      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(),
    );
  }

  /// 供子 Tab 调用，发送一个问题到 Chat Tab 并自动切换过去
  void _handleAskAi(String prompt) {
    // 切换到 Chat Tab（索引 0）
    _tabController.animateTo(0);

    // 等待 Tab 构建完成后再发送消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _chatTabKey.currentState;
      state?.sendInitialPrompt(prompt);
    });
  }

  @override
  void dispose() {
    _macosMenuController.clearCurrentProjectContext(
      expectedId: widget.projectId,
    );
    _tabController.dispose();
    super.dispose();
  }

  void _shareProject() {
    final project = _project;
    if (project == null) return;
    final uiContext = _stableUiContext;
    final shareTitle = _translateWithContext(
      uiContext,
      'project_detail_share_title',
      'Share',
    );
    final prod = (project.latestProdDeploymentUrl ?? '').trim();
    final preview = (project.preferredPreviewUrl ?? '').trim();
    final raw = (prod.isNotEmpty ? prod : preview).trim();
    if (raw.isEmpty) {
      SnackBarHelper.showInfo(
        uiContext,
        title: shareTitle,
        message: _translateWithContext(
          uiContext,
          'project_detail_share_no_url',
          'No preview/production URL available yet.',
        ),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      SnackBarHelper.showError(
        uiContext,
        title: shareTitle,
        message: _translateWithContext(
          uiContext,
          'project_detail_share_invalid_url',
          'Invalid URL: {url}',
        ).replaceAll('{url}', raw),
      );
      return;
    }
    ShareSheet.show(
      uiContext,
      url: uri,
      title: project.projectName,
      message: project.projectDescription.trim().isNotEmpty
          ? project.projectDescription.trim()
          : (prod.isNotEmpty
                ? _translateWithContext(
                    uiContext,
                    'project_detail_share_production_link',
                    'Production link',
                  )
                : _translateWithContext(
                    uiContext,
                    'project_detail_share_preview_link',
                    'Preview link',
                  )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = isDesktopLayout(context);
    final isMacosDesktop =
        desktop && !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

    if (_isLoading) {
      return _buildScaffold(
        context,
        isMacosDesktop: isMacosDesktop,
        body: const ProjectOverviewSkeleton(),
      );
    }

    if (_error != null) {
      return _buildScaffold(
        context,
        isMacosDesktop: isMacosDesktop,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _t(
                  'project_detail_error_text',
                  'Error: {error}',
                ).replaceAll('{error}', _error ?? ''),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProject,
                child: Text(_t('retry', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final project = _project;
    if (project == null) {
      return _buildScaffold(
        context,
        isMacosDesktop: isMacosDesktop,
        body: Center(
          child: Text(_t('project_detail_not_found', 'Project not found')),
        ),
      );
    }

    return _buildScaffold(
      context,
      isMacosDesktop: isMacosDesktop,
      project: project,
      body: desktop
          ? DesktopContentFrame(
              maxWidth: 1520,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _buildProjectTabViews(project),
            )
          : _buildProjectTabViews(project),
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required bool isMacosDesktop,
    required Widget body,
    UserProject? project,
  }) {
    if (!isMacosDesktop) {
      return Scaffold(
        appBar: isDesktopLayout(context)
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: _buildGlassmorphicAppBar(context),
              ),
        body: body,
      );
    }

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          _buildMacosProjectTitleBar(context, project),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildProjectTabViews(UserProject project) {
    return D1VTabBarView(
      controller: _tabController,
      children: [
        ProjectChatTab(
          key: _chatTabKey,
          projectId: project.id,
          previewUrl: project.preferredPreviewUrl,
          initialSubTab: widget.initialChatTab,
        ),
        ProjectApiTab(projectId: project.id),
        ProjectDatabaseTab(
          project: project,
          onAskAi: _handleAskAi,
          onRefreshProject: _loadProject,
        ),
        ProjectPaymentTab(
          projectId: project.id,
          projectPayId: project.projectPayId,
          onRefreshProject: () => _loadProject(forceNetwork: true),
          onAskAi: _handleAskAi,
        ),
        ProjectDeployTab(
          project: project,
          onAskAi: _handleAskAi,
          onRefreshProject: _loadProject,
        ),
        ProjectAnalyticsTab(
          project: project,
          onAskAi: _handleAskAi,
          onRefreshProject: _loadProject,
        ),
        ProjectOverviewTab(project: project, onRefreshProject: _loadProject),
      ],
    );
  }

  Widget _buildGlassmorphicAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = D1VColors.getPrimaryGradient(context);
    final activeText = D1VColors.getActiveText(context);
    final inactiveText = D1VColors.getInactiveText(context);

    return Container(
      decoration: BoxDecoration(
        boxShadow: isDark ? null : D1VColors.getGlowShadows(context, 1.0),
      ),
      child: ClipRRect(
        child: Stack(
          children: [
            // 渐变背景
            Container(decoration: BoxDecoration(gradient: gradient)),
            // 磨砂玻璃层 (Dark Mode)
            if (isDark)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: D1VColors.deepBlueDark.withValues(alpha: 0.6 * 255),
                  ),
                ),
              ),
            // AppBar 内容
            AppBar(
              titleSpacing: 0,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: activeText,
              actions: [
                IconButton(
                  tooltip: _t('project_detail_share_title', 'Share'),
                  icon: const Icon(Icons.share),
                  onPressed: _shareProject,
                ),
              ],
              title: ClipRect(
                child: D1VTabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  labelColor: activeText,
                  unselectedLabelColor: inactiveText,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: _tabs
                      .map(
                        (tab) => D1VTab(
                          icon: tab.icon,
                          text: _t(tab.labelKey, tab.fallback),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacosProjectTitleBar(
    BuildContext context,
    UserProject? project,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = project?.projectName.trim().isNotEmpty == true
        ? project!.projectName.trim()
        : 'Project';

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
                  _MacosHeaderBackButton(onPressed: _handleBack),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        return Row(
                          children: [
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerLeft,
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
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (var i = 0; i < _tabs.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 8),
                                      _MacosProjectTabChip(
                                        label: _t(
                                          _tabs[i].labelKey,
                                          _tabs[i].fallback,
                                        ),
                                        icon: _tabs[i].icon,
                                        selected: _tabController.index == i,
                                        onTap: () =>
                                            _tabController.animateTo(i),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _t('project_detail_share_title', 'Share'),
                    icon: const Icon(Icons.share, size: 18),
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: 16,
                    onPressed: project == null ? null : _shareProject,
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

  Future<void> _beginMacosWindowDrag() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _windowChannel.invokeMethod<void>('beginWindowDrag');
    } catch (_) {}
  }
}

extension on _ProjectDetailScreenState {
  void _handleBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/projects');
    }
  }
}

class _MacosHeaderBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _MacosHeaderBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 10,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MacosProjectTabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MacosProjectTabChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                size: 13,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
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

class _MacosWindowDragArea extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onDragStart;

  const _MacosWindowDragArea({required this.child, required this.onDragStart});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        unawaited(onDragStart());
      },
      child: child,
    );
  }
}

class _TabItem {
  final String labelKey;
  final String fallback;
  final IconData icon;

  const _TabItem(this.labelKey, this.fallback, this.icon);
}
