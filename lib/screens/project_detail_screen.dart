import 'dart:async';
import 'package:flutter/material.dart';
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
  late final TabController _tabController;
  late final MacosMenuController _macosMenuController;
  late BuildContext _stableUiContext;
  final GlobalKey<ProjectChatTabState> _chatTabKey =
      GlobalKey<ProjectChatTabState>();

  UserProject? _project;
  bool _isLoading = true;
  String? _error;

  final List<_TabItem> _tabs = const [
    _TabItem('project_detail_tab_overview', 'Overview', Icons.dashboard),
    _TabItem('project_detail_tab_chat', 'Chat', Icons.chat),
    _TabItem('project_detail_tab_environment', 'Environment', Icons.key),
    _TabItem('project_detail_tab_database', 'Database', Icons.storage),
    _TabItem('project_detail_tab_payment', 'Payment', Icons.payment),
    _TabItem('project_detail_tab_deploy', 'Deploy', Icons.cloud_upload),
    _TabItem('project_detail_tab_analytics', 'Analytics', Icons.analytics),
  ];

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  String _translateWithContext(BuildContext context, String key, String fallback) {
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
      case 'overview':
        return 0;
      case 'chat':
        return 1;
      case 'environment':
      case 'env':
      case 'variables':
      case 'api':
        return 2;
      case 'database':
      case 'db':
        return 3;
      case 'payment':
      case 'billing':
        return 4;
      case 'deploy':
      case 'deployment':
      case 'logs':
        return 5;
      case 'analytics':
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
    // 切换到 Chat Tab（索引 1）
    _tabController.animateTo(1);

    // 等待 Tab 构建完成后再发送消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _chatTabKey.currentState;
      state?.sendInitialPrompt(prompt);
    });
  }

  @override
  void dispose() {
    _macosMenuController.clearCurrentProjectContext(expectedId: widget.projectId);
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

    if (_isLoading) {
      return Scaffold(
        appBar: desktop
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: _buildGlassmorphicAppBar(context),
              ),
        body: const ProjectOverviewSkeleton(),
      );
    }

    if (_error != null) {
      return Scaffold(
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
      return Scaffold(
        body: Center(
          child: Text(_t('project_detail_not_found', 'Project not found')),
        ),
      );
    }

    return Scaffold(
      appBar: desktop
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: _buildGlassmorphicAppBar(context),
            ),
      body: desktop
          ? DesktopContentFrame(
              maxWidth: 1520,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 250,
                    child: _ProjectDesktopRail(
                      tabs: _tabs
                          .map((tab) => (tab.icon, _t(tab.labelKey, tab.fallback)))
                          .toList(),
                      controller: _tabController,
                      projectName: project.projectName,
                      onBack: () {
                        final router = GoRouter.of(context);
                        if (router.canPop()) {
                          router.pop();
                        } else {
                          router.go('/projects');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: _buildProjectTabViews(project)),
                ],
              ),
            )
          : _buildProjectTabViews(project),
    );
  }

  Widget _buildProjectTabViews(UserProject project) {
    return D1VTabBarView(
      controller: _tabController,
      children: [
        ProjectOverviewTab(project: project, onRefreshProject: _loadProject),
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
}

class _ProjectDesktopRail extends StatelessWidget {
  final List<(IconData, String)> tabs;
  final TabController controller;
  final String projectName;
  final VoidCallback onBack;

  const _ProjectDesktopRail({
    required this.tabs,
    required this.controller,
    required this.projectName,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(42, 42),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.arrow_back, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        projectName.trim().isEmpty ? 'Project' : projectName,
                        style: TextStyle(
                          fontSize: theme.textTheme.titleLarge?.fontSize ?? 22,
                          height: theme.textTheme.titleLarge?.height,
                          letterSpacing:
                              theme.textTheme.titleLarge?.letterSpacing,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < tabs.length; i++) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => controller.animateTo(i),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: controller.index == i
                              ? colorScheme.primary.withValues(alpha: 0.10)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              tabs[i].$1,
                              size: 18,
                              color: controller.index == i
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tabs[i].$2,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: controller.index == i
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: controller.index == i
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (i != tabs.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabItem {
  final String labelKey;
  final String fallback;
  final IconData icon;

  const _TabItem(this.labelKey, this.fallback, this.icon);
}
