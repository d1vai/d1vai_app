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
import '../providers/theme_provider.dart';
import '../services/app_analytics_service.dart';
import '../services/d1vai_service.dart';
import '../utils/error_utils.dart';
import '../widgets/adaptive_modal.dart';
import '../widgets/avatar_image.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/project_analytics/project_analytics_tab.dart';
import '../widgets/project_api/project_api_tab.dart';
import '../widgets/project_chat/project_chat_tab.dart';
import '../widgets/project_database/project_database_tab.dart';
import '../widgets/project_deploy/project_deploy_tab.dart';
import '../widgets/project_overview/project_overview_tab.dart';
import '../widgets/project_payment/project_payment_tab.dart';
import 'settings/profile_tab.dart';
import '../widgets/editor_preferences_dialog.dart';
import '../widgets/d1v_tab_bar_view.dart';
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';
import '../core/theme/app_colors.dart';
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
  bool _showProfileSidebar = false;
  String? _lastTrackedProjectId;

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
        _trackProjectOpened(project);
        _trackChatOpenedIfNeeded(project);
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
        _trackProjectOpened(fresh);
        _trackChatOpenedIfNeeded(fresh);
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

  void _trackProjectOpened(UserProject project) {
    if (_lastTrackedProjectId == project.id) return;
    _lastTrackedProjectId = project.id;
    unawaited(AppAnalyticsService.instance.trackProjectOpened(project));
  }

  void _trackChatOpenedIfNeeded(UserProject project) {
    if (_tabController.index != 0) return;
    final hasPreview = (project.preferredPreviewUrl ?? '').trim().isNotEmpty;
    final defaultTab =
        (widget.initialChatTab ?? '').trim().isNotEmpty
            ? widget.initialChatTab!.trim()
            : (hasPreview ? 'preview' : 'code');
    unawaited(
      AppAnalyticsService.instance.trackChatOpened(
        projectId: project.id,
        defaultTab: defaultTab,
        hasPreview: hasPreview,
      ),
    );
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
      body: Stack(
        children: [
          Column(
            children: [
              _buildMacosProjectTitleBar(context, project),
              Expanded(child: body),
            ],
          ),
          if (_showProfileSidebar) _buildProfileSidebarOverlay(context),
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
    final isMobilePlatform =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    final useSoftLightBackground = isMobilePlatform && !isDark;
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
            if (useSoftLightBackground)
              Container(
                color: theme.colorScheme.surface.withValues(alpha: 0.98),
              )
            else
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
                    icon: const Icon(Icons.share, size: 16),
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                    onPressed: project == null ? null : _shareProject,
                  ),
                  const SizedBox(width: 6),
                  _MacosProfileButton(
                    onPressed: _toggleProfileSidebar,
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

  Future<void> _beginMacosWindowDrag() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _windowChannel.invokeMethod<void>('beginWindowDrag');
    } catch (_) {}
  }

  void _toggleProfileSidebar() {
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
                              _t('profile', 'Profile'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: _closeProfileSidebar,
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: _t('close', 'Close'),
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
        ],
      ),
    );
  }

  void _showThemeDialog() {
    final loc = AppLocalizations.of(context);
    showAdaptiveModal(
      context: context,
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return AdaptiveModalContainer(
              maxWidth: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdaptiveModalHeader(
                    title: loc?.translate('choose_theme') ?? 'Choose Theme',
                    subtitle: 'Match your workspace mood and ambient contrast.',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.light,
                    Icons.light_mode,
                    loc?.translate('light_mode') ?? 'Light Mode',
                  ),
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.dark,
                    Icons.dark_mode,
                    loc?.translate('dark_mode') ?? 'Dark Mode',
                  ),
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.system,
                    Icons.brightness_auto,
                    loc?.translate('system_mode') ?? 'System',
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    AppThemeMode mode,
    IconData icon,
    String title,
  ) {
    final isSelected = themeProvider.themeMode == mode;

    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primaryBrand : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primaryBrand : null,
        ),
      ),
      trailing: Radio<AppThemeMode>(
        groupValue: themeProvider.themeMode,
        onChanged: (AppThemeMode? newMode) {
          if (newMode != null) {
            Navigator.pop(context);
            themeProvider.setThemeMode(newMode);
            SnackBarHelper.showSuccess(
              context,
              title: 'Theme Updated',
              message: 'Switched to $title',
            );
          }
        },
        value: mode,
      ),
      onTap: () {
        final loc = AppLocalizations.of(context);
        Navigator.pop(context);
        themeProvider.setThemeMode(mode);
        SnackBarHelper.showSuccess(
          context,
          title: loc?.translate('theme_updated') ?? 'Theme Updated',
          message:
              '${loc?.translate('theme_switched') ?? 'Switched to'} $title',
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'd1v.ai',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.apps, size: 48),
      children: [
        Text(
          AppLocalizations.of(context)?.translate('about_description') ??
              'An AI-powered app development platform.',
        ),
      ],
    );
  }

  void _showEditorPreferencesDialog() {
    showAdaptiveModal(
      context: context,
      builder: (_) => const EditorPreferencesDialogBody(),
    );
  }

  void _showBindEmailDialog() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    int step = 1;
    final d1vaiService = D1vaiService();
    final loc = AppLocalizations.of(context);

    showAdaptiveModal(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AdaptiveModalContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveModalHeader(
                  title: loc?.translate('bind_email') ?? 'Bind Email',
                  subtitle: step == 1
                      ? (loc?.translate('enter_email_for_code') ??
                            'Enter your email address to receive a verification code')
                      : (loc?.translate('enter_code_sent') ??
                            'Enter the 6-digit verification code sent to your email'),
                  onClose: () => Navigator.pop(context),
                ),
                if (step == 1)
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: loc?.translate('email') ?? 'Email',
                      hintText: 'your@email.com',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  )
                else
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('verify_code') ?? 'Verification Code',
                      hintText: '123456',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc?.translate('cancel') ?? 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (step == 1) {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('email_required') ??
                                    'Please enter an email address',
                              );
                              return;
                            }
                            try {
                              await d1vaiService.postUserBindEmailSend(email);
                              if (!context.mounted) return;
                              SnackBarHelper.showSuccess(
                                context,
                                title: loc?.translate('success') ?? 'Success',
                                message:
                                    loc?.translate('code_sent_success') ??
                                    'Verification code sent to your email',
                              );
                              setDialogState(() {
                                step = 2;
                              });
                            } catch (error) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    '${loc?.translate('failed_to_send_code') ?? "Failed to send verification code"}: $error',
                              );
                            }
                          } else {
                            try {
                              await d1vaiService.postUserBindEmailConfirm(
                                emailController.text.trim(),
                                codeController.text.trim(),
                              );
                              if (!context.mounted) return;
                              SnackBarHelper.showSuccess(
                                context,
                                title: loc?.translate('success') ?? 'Success',
                                message:
                                    loc?.translate('email_bound_success') ??
                                    'Email bound successfully',
                              );
                              Navigator.pop(context);
                              await Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              ).refreshUser();
                            } catch (error) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    '${loc?.translate('failed_to_verify') ?? "Failed to verify code"}: $error',
                              );
                            }
                          }
                        },
                        child: Text(
                          step == 1
                              ? (loc?.translate('send_code') ?? 'Send Code')
                              : (loc?.translate('confirm') ?? 'Verify'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetPasswordDialog() {
    final loc = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    int step = 1;
    final d1vaiService = D1vaiService();

    showAdaptiveModal(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AdaptiveModalContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveModalHeader(
                  title: loc?.translate('reset_password') ?? 'Reset Password',
                  subtitle: step == 1
                      ? (loc?.translate('enter_email_for_code') ??
                            'Enter your email address to receive a verification code')
                      : (loc?.translate('enter_code_and_new_password') ??
                            'Enter the verification code and your new password'),
                  onClose: () => Navigator.pop(context),
                ),
                if (step == 1) ...[
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: loc?.translate('email') ?? 'Email',
                      hintText: 'your@email.com',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('verify_code') ?? 'Verification Code',
                      border: const OutlineInputBorder(),
                    ),
                    maxLength: 6,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('new_password') ?? 'New Password',
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('confirm_password') ??
                          'Confirm Password',
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc?.translate('cancel') ?? 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            if (step == 1) {
                              await d1vaiService.postUserPasswordForgotSend(
                                emailController.text.trim(),
                              );
                              if (!context.mounted) return;
                              setDialogState(() {
                                step = 2;
                              });
                            } else {
                              await d1vaiService.postUserPasswordReset(
                                emailController.text.trim(),
                                codeController.text.trim(),
                                passwordController.text,
                              );
                              if (!context.mounted) return;
                              SnackBarHelper.showSuccess(
                                context,
                                title: loc?.translate('success') ?? 'Success',
                                message:
                                    loc?.translate('password_reset_success') ??
                                    'Password reset successfully',
                              );
                              Navigator.pop(context);
                            }
                          } catch (error) {
                            if (!context.mounted) return;
                            SnackBarHelper.showError(
                              context,
                              title: loc?.translate('error') ?? 'Error',
                              message: '$error',
                            );
                          }
                        },
                        child: Text(
                          step == 1
                              ? (loc?.translate('send_code') ?? 'Send Code')
                              : (loc?.translate('reset_password') ??
                                    'Reset Password'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

class _MacosProfileButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool active;

  const _MacosProfileButton({required this.onPressed, required this.active});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: AppLocalizations.of(context)?.translate('profile') ?? 'Profile',
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
          child: user?.picture != null && user!.picture.isNotEmpty
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
