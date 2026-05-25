import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/deployment.dart';
import '../../models/project.dart';
import '../../providers/auth_provider.dart';
import '../../utils/preview_url.dart';
import '../snackbar_helper.dart';
import 'components/project_overview_card_shell.dart';
import 'components/project_overview_danger_zone_card.dart';
import 'components/project_overview_health_metrics_card.dart';
import 'components/project_overview_links_card.dart';
import 'components/project_overview_recent_deployments_card.dart';
import 'components/project_overview_utils.dart';
import '../../providers/project_provider.dart';
import '../../core/api_client.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../progress_widget.dart';

/// 项目详情页 - 概览 Tab
class ProjectOverviewTab extends StatefulWidget {
  final UserProject project;
  final Future<void> Function()? onRefreshProject;
  final void Function(String tab)? onNavigateToTab;

  const ProjectOverviewTab({
    super.key,
    required this.project,
    this.onRefreshProject,
    this.onNavigateToTab,
  });

  @override
  State<ProjectOverviewTab> createState() => _ProjectOverviewTabState();
}

class _ProjectOverviewTabState extends State<ProjectOverviewTab> {
  final List<DeploymentHistory> _deployments = [];
  bool _isLoadingDeployments = false;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _loadDeployments();
  }

  @override
  void didUpdateWidget(covariant ProjectOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _loadDeployments();
    }
  }

  Future<void> _loadDeployments() async {
    if (_isLoadingDeployments) return;
    setState(() {
      _isLoadingDeployments = true;
    });

    try {
      final d1vaiService = D1vaiService();
      final deployments = await d1vaiService.getProjectDeploymentHistory(
        widget.project.id,
        limit: 5,
      );

      if (!mounted) return;

      setState(() {
        _deployments
          ..clear()
          ..addAll(deployments);
        _isLoadingDeployments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDeployments = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final ownerEmail = context.select<AuthProvider, String?>(
      (authProvider) => authProvider.user?.email,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        final topWorkspace = isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _OverviewHeroPanel(
                      project: project,
                      ownerEmail: ownerEmail,
                      onOpenUrl: _openProjectUrl,
                      onCopyValue: _copyValue,
                      isWide: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _OverviewQuickActionsCard(
                      project: project,
                      onNavigateToTab: widget.onNavigateToTab,
                      onOpenPreviewUrl: _openPreviewUrl,
                      onOpenGitHubRepo: _openGitHubRepo,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OverviewHeroPanel(
                    project: project,
                    ownerEmail: ownerEmail,
                    onOpenUrl: _openProjectUrl,
                    onCopyValue: _copyValue,
                    isWide: false,
                  ),
                  const SizedBox(height: 14),
                  _OverviewQuickActionsCard(
                    project: project,
                    onNavigateToTab: widget.onNavigateToTab,
                    onOpenPreviewUrl: _openPreviewUrl,
                    onOpenGitHubRepo: _openGitHubRepo,
                  ),
                ],
              );

        final content = <Widget>[topWorkspace, const SizedBox(height: 16)];

        if (isWide) {
          content.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CommunityActionsCard(
                        project: project,
                        onRefreshProject: widget.onRefreshProject,
                        onReloadDeployments: _loadDeployments,
                      ),
                      const SizedBox(height: 16),
                      ProjectOverviewRecentDeploymentsCard(
                        deployments: _deployments,
                        isLoading: _isLoadingDeployments,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProjectOverviewLinksCard(
                        project: project,
                        onOpenPreviewUrl: _openPreviewUrl,
                        onOpenGitHubRepo: _openGitHubRepo,
                      ),
                      const SizedBox(height: 16),
                      ProjectOverviewHealthMetricsCard(project: project),
                      const SizedBox(height: 16),
                      ProjectOverviewDangerZoneCard(project: project),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          content.addAll([
            _CommunityActionsCard(
              project: project,
              onRefreshProject: widget.onRefreshProject,
              onReloadDeployments: _loadDeployments,
            ),
            const SizedBox(height: 16),
            ProjectOverviewRecentDeploymentsCard(
              deployments: _deployments,
              isLoading: _isLoadingDeployments,
            ),
            const SizedBox(height: 16),
            ProjectOverviewLinksCard(
              project: project,
              onOpenPreviewUrl: _openPreviewUrl,
              onOpenGitHubRepo: _openGitHubRepo,
            ),
            const SizedBox(height: 16),
            ProjectOverviewHealthMetricsCard(project: project),
            const SizedBox(height: 16),
            ProjectOverviewDangerZoneCard(project: project),
          ]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String url, String errorMessage) async {
    if (!mounted) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final canLaunch = await canLaunchUrl(uri);

    if (mounted && canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: errorMessage,
      );
    }
  }

  Future<void> _openPreviewUrl(String url) async {
    await _openUrl(
      url,
      _t(
        'project_overview_links_open_preview_failed',
        'Could not open preview URL',
      ),
    );
  }

  Future<void> _openProjectUrl(String url) async {
    await _openUrl(
      url,
      _t(
        'project_overview_links_open_url_failed',
        'Could not open project URL',
      ),
    );
  }

  Future<void> _openGitHubRepo(String repoFullName) async {
    final repo = repoFullName.trim();
    if (repo.isEmpty || !repo.contains('/')) return;
    await _openUrl(
      'https://github.com/$repo',
      _t(
        'project_overview_links_open_github_failed',
        'Could not open GitHub repository',
      ),
    );
  }

  Future<void> _copyValue(String value, String label) async {
    final text = value.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: _t('copied', 'Copied'),
      message: '$label copied',
    );
  }
}

class _OverviewHeroPanel extends StatelessWidget {
  final UserProject project;
  final String? ownerEmail;
  final Future<void> Function(String url) onOpenUrl;
  final Future<void> Function(String value, String label) onCopyValue;
  final bool isWide;

  const _OverviewHeroPanel({
    required this.project,
    required this.ownerEmail,
    required this.onOpenUrl,
    required this.onCopyValue,
    required this.isWide,
  });

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final previewUrl = preferredPreviewUrlFromProject(project);
    final branch =
        (project.workspaceCurrentBranch ??
                project.repositoryCurrentBranch ??
                '')
            .trim();
    final prodUrl = (project.latestProdDeploymentUrl?.trim().isNotEmpty == true)
        ? project.latestProdDeploymentUrl!.trim()
        : ((project.vercelProdDomain ?? '').trim().isNotEmpty
              ? 'https://${project.vercelProdDomain!.trim()}'
              : null);

    return ProjectOverviewCardShell(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      accentColor: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: _buildSummaryColumn(
                    context,
                    theme,
                    cs,
                    isDark,
                    previewUrl,
                    branch,
                    prodUrl,
                  ),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 328,
                  child: _buildMetaRail(context, previewUrl),
                ),
              ],
            )
          else ...[
            _buildSummaryColumn(
              context,
              theme,
              cs,
              isDark,
              previewUrl,
              branch,
              prodUrl,
            ),
            const SizedBox(height: 14),
            _buildMetaRail(context, previewUrl),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
    String? previewUrl,
    String branch,
    String? prodUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'project-emoji-${project.id}',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Color.alphaBlend(
                      cs.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                      cs.surface,
                    ),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: isDark ? 0.24 : 0.14),
                    ),
                  ),
                  child: Text(
                    project.emoji ?? '🚀',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        project.projectName.trim().isEmpty
                            ? _t(context, 'project_detail_not_found', 'Project')
                            : project.projectName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      _OverviewStatusPill(status: project.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.projectDescription.trim().isEmpty
                        ? _t(
                            context,
                            'project_overview_no_description',
                            'No description yet.',
                          )
                        : project.projectDescription.trim(),
                    maxLines: isWide ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _OverviewInlineTag(
              icon: Icons.schedule_rounded,
              text: _t(
                context,
                'project_overview_header_updated',
                'Updated {time}',
              ).replaceAll('{time}', formatTimeAgo(context, project.updatedAt)),
            ),
            if (branch.isNotEmpty)
              _OverviewInlineTag(
                icon: Icons.alt_route,
                text: branch,
                monospace: true,
                onTap: () => onCopyValue(branch, 'Branch'),
                tooltip: 'Copy branch',
              ),
            _OverviewInlineTag(
              icon: Icons.preview_outlined,
              text: getDeploymentLabel(
                context,
                preferredPreviewUrlFromProject(project),
              ),
              onTap: previewUrl == null || previewUrl.isEmpty
                  ? null
                  : () => onOpenUrl(previewUrl),
              tooltip: previewUrl == null || previewUrl.isEmpty
                  ? null
                  : 'Open preview',
            ),
            if (prodUrl != null)
              _OverviewInlineTag(
                icon: Icons.public,
                text: getDeploymentLabel(context, prodUrl),
                onTap: () => onOpenUrl(prodUrl),
                tooltip: 'Open production',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaRail(BuildContext context, String? previewUrl) {
    final owner = (ownerEmail ?? '').trim().isEmpty
        ? _t(context, 'project_overview_stats_unknown', 'Unknown')
        : ownerEmail!;
    final analytics = project.hasAnalyticsId
        ? _t(context, 'project_overview_health_status_enabled', 'Enabled')
        : _t(context, 'project_overview_health_status_disabled', 'Disabled');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _OverviewMetricTile(
              label: _t(context, 'project_overview_stats_created', 'Created'),
              value: _safeDate(context, project.createdAt),
              compact: true,
            ),
            _OverviewMetricTile(
              label: _t(context, 'project_overview_stats_owner', 'Owner'),
              value: owner,
              compact: true,
              onTap:
                  owner ==
                      _t(context, 'project_overview_stats_unknown', 'Unknown')
                  ? null
                  : () => onCopyValue(owner, 'Owner'),
              tooltip:
                  owner ==
                      _t(context, 'project_overview_stats_unknown', 'Unknown')
                  ? null
                  : 'Copy owner',
            ),
            _OverviewMetricTile(
              label: _t(
                context,
                'project_overview_health_analytics',
                'Analytics',
              ),
              value: analytics,
              compact: true,
            ),
            _OverviewMetricTile(
              label: _t(
                context,
                'project_overview_stats_deployment',
                'Deployment',
              ),
              value: getDeploymentLabel(context, previewUrl),
              compact: true,
              onTap: previewUrl == null || previewUrl.isEmpty
                  ? null
                  : () => onOpenUrl(previewUrl),
              tooltip: previewUrl == null || previewUrl.isEmpty
                  ? null
                  : 'Open preview',
            ),
          ],
        ),
        if (previewUrl != null && previewUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => onOpenUrl(previewUrl),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                _t(context, 'project_overview_open_preview', 'Open preview'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OverviewQuickActionsCard extends StatelessWidget {
  final UserProject project;
  final void Function(String tab)? onNavigateToTab;
  final Future<void> Function(String url) onOpenPreviewUrl;
  final Future<void> Function(String repoFullName) onOpenGitHubRepo;

  const _OverviewQuickActionsCard({
    required this.project,
    required this.onNavigateToTab,
    required this.onOpenPreviewUrl,
    required this.onOpenGitHubRepo,
  });

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = preferredPreviewUrlFromProject(project);
    final repoFullName = (project.repositoryFullName ?? '').trim();

    return ProjectOverviewCardShell(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final columns = constraints.maxWidth >= 420 ? 2 : 1;
          final buttonWidth = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gap) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick actions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Jump straight into the part of the project you want to operate on.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: _OverviewActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: _t(context, 'project_detail_tab_chat', 'Chat'),
                      onPressed: onNavigateToTab == null
                          ? null
                          : () => onNavigateToTab!('chat'),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: _OverviewActionButton(
                      icon: Icons.cloud_upload_outlined,
                      label: _t(context, 'project_detail_tab_deploy', 'Deploy'),
                      onPressed: onNavigateToTab == null
                          ? null
                          : () => onNavigateToTab!('deploy'),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: _OverviewActionButton(
                      icon: Icons.payment_outlined,
                      label: _t(
                        context,
                        'project_detail_tab_payment',
                        'Payment',
                      ),
                      onPressed: onNavigateToTab == null
                          ? null
                          : () => onNavigateToTab!('payment'),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: _OverviewActionButton(
                      icon: Icons.analytics_outlined,
                      label: _t(
                        context,
                        'project_detail_tab_analytics',
                        'Analytics',
                      ),
                      onPressed: onNavigateToTab == null
                          ? null
                          : () => onNavigateToTab!('analytics'),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: _OverviewActionButton(
                      icon: Icons.open_in_new_rounded,
                      label: _t(
                        context,
                        'project_overview_open_preview',
                        'Open preview',
                      ),
                      onPressed: previewUrl == null || previewUrl.isEmpty
                          ? null
                          : () => onOpenPreviewUrl(previewUrl),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: _OverviewActionButton(
                      icon: Icons.code_rounded,
                      label: _t(
                        context,
                        'project_overview_links_github_repo',
                        'GitHub Repository',
                      ),
                      onPressed:
                          repoFullName.isEmpty || !repoFullName.contains('/')
                          ? null
                          : () => onOpenGitHubRepo(repoFullName),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _OverviewActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: Icon(icon, size: 15),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

String _safeDate(BuildContext context, String raw) {
  try {
    return MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime.parse(raw));
  } catch (_) {
    final value = AppLocalizations.of(
      context,
    )?.translate('project_overview_stats_unknown');
    return (value == null || value == 'project_overview_stats_unknown')
        ? 'Unknown'
        : value;
  }
}

class _OverviewMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;
  final VoidCallback? onTap;
  final String? tooltip;

  const _OverviewMetricTile({
    required this.label,
    required this.value,
    this.compact = false,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = (MediaQuery.sizeOf(context).width - 56) / 2;
    final child = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? 128 : 144,
        maxWidth: width.clamp(compact ? 128 : 144, compact ? 188 : 220),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 9 : 11,
        ),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(compact ? 11 : 12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return child;

    final interactive = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        onTap: onTap,
        child: child,
      ),
    );

    if ((tooltip ?? '').trim().isEmpty) return interactive;
    return Tooltip(message: tooltip, child: interactive);
  }
}

class _OverviewInlineTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool monospace;
  final VoidCallback? onTap;
  final String? tooltip;

  const _OverviewInlineTag({
    required this.icon,
    required this.text,
    this.monospace = false,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    final interactive = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: child,
      ),
    );

    if ((tooltip ?? '').trim().isEmpty) return interactive;
    return Tooltip(message: tooltip, child: interactive);
  }
}

class _OverviewStatusPill extends StatelessWidget {
  final String status;

  const _OverviewStatusPill({required this.status});

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    late final Color color;
    late final String label;
    switch (status) {
      case 'active':
        color = cs.primary;
        label = _t(context, 'project_overview_status_active', 'Active');
        break;
      case 'archived':
        color = cs.tertiary;
        label = _t(context, 'project_overview_status_archived', 'Archived');
        break;
      case 'draft':
        color = cs.onSurfaceVariant;
        label = _t(context, 'project_overview_status_draft', 'Draft');
        break;
      default:
        color = cs.onSurfaceVariant;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CommunityActionsCard extends StatefulWidget {
  final UserProject project;
  final Future<void> Function()? onRefreshProject;
  final Future<void> Function() onReloadDeployments;

  const _CommunityActionsCard({
    required this.project,
    required this.onRefreshProject,
    required this.onReloadDeployments,
  });

  @override
  State<_CommunityActionsCard> createState() => _CommunityActionsCardState();
}

class _CommunityActionsCardState extends State<_CommunityActionsCard> {
  bool _isLoading = false;
  String? _loadingAction; // 'publish' | 'update' | 'unpublish'
  Map<String, dynamic>? _post;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void didUpdateWidget(covariant _CommunityActionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _post = null;
      _loadPost();
    }
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final service = D1vaiService();
      final res = await service.getCommunityPostForProject(widget.project.id);
      if (!mounted) return;
      setState(() {
        _post = res is Map<String, dynamic> ? res : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _post = null;
        _isLoading = false;
      });
    }
  }

  String get _status {
    final id = _post?['id'];
    if (id == null) return 'none';
    final s = _post?['status']?.toString().trim();
    return (s == null || s.isEmpty) ? 'draft' : s;
  }

  String _webBaseFromApi() {
    try {
      final api = Uri.parse(ApiClient.baseUrl);
      final host = api.host;
      if (host.startsWith('api.')) {
        return api.replace(host: host.substring(4), path: '').toString();
      }
      return api.replace(path: '').toString();
    } catch (_) {
      return 'https://d1v.ai';
    }
  }

  String _prodUrl() {
    final project = widget.project;
    final latest = project.latestProdDeploymentUrl;
    if (latest != null && latest.trim().isNotEmpty) return latest.trim();
    final dom = project.vercelProdDomain;
    if (dom == null || dom.trim().isEmpty) return '';
    final d = dom.trim();
    if (d.startsWith('http://') || d.startsWith('https://')) return d;
    return 'https://$d';
  }

  String _prodLabel(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  bool _shouldRetryLockTimeout(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('lock wait timeout exceeded') ||
        msg.contains('pymysql.err.operationalerror') ||
        msg.contains('internal error');
  }

  Future<bool> _publish() async {
    final project = widget.project;
    final service = D1vaiService();
    final maxAttempts = 3;

    setState(() {
      _loadingAction = 'publish';
    });

    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          final postId = _post?['id'];
          if (postId is num) {
            await service.publishCommunityPost(postId.toInt());
          } else if (postId is String && int.tryParse(postId) != null) {
            await service.publishCommunityPost(int.parse(postId));
          } else {
            await service.upsertCommunityPost(
              projectId: project.id,
              title: project.projectName,
              summary: project.projectDescription,
              publish: true,
            );
          }
          if (!mounted) return true;
          SnackBarHelper.showSuccess(
            context,
            title: _t('success', 'Success'),
            message: _t(
              'project_overview_community_publish_success',
              'Published to community',
            ),
          );
          await _loadPost();
          await widget.onRefreshProject?.call();
          if (!mounted) return true;
          await Provider.of<ProjectProvider>(context, listen: false).refresh();
          await widget.onReloadDeployments();
          return true;
        } catch (e) {
          if (attempt < maxAttempts - 1 && _shouldRetryLockTimeout(e)) {
            final delay = Duration(milliseconds: 300 * (attempt + 1) + 120);
            await Future.delayed(delay);
            continue;
          }
          rethrow;
        }
      }
    } catch (e) {
      if (!mounted) return false;
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: _t(
          'project_overview_community_publish_failed',
          'Failed to publish to community',
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = null;
        });
      }
    }
    return false;
  }

  Future<void> _update() async {
    final project = widget.project;
    setState(() {
      _loadingAction = 'update';
    });
    try {
      final service = D1vaiService();
      await service.upsertCommunityPost(
        projectId: project.id,
        title: project.projectName,
        summary: project.projectDescription,
        publish: false,
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('success', 'Success'),
        message: _t(
          'project_overview_community_update_success',
          'Post updated',
        ),
      );
      await _loadPost();
    } catch (_) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: _t(
          'project_overview_community_update_failed',
          'Failed to update post',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _unpublish() async {
    final postId = _post?['id'];
    final id = postId is num
        ? postId.toInt()
        : postId is String
        ? int.tryParse(postId)
        : null;
    if (id == null) return;

    setState(() {
      _loadingAction = 'unpublish';
    });
    try {
      final service = D1vaiService();
      await service.unpublishCommunityPost(id);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('success', 'Success'),
        message: _t(
          'project_overview_community_unpublish_success',
          'Unpublished',
        ),
      );
      await _loadPost();
    } catch (_) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: _t(
          'project_overview_community_unpublish_failed',
          'Failed to unpublish',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _openCommunityPost() async {
    final slug = _post?['slug']?.toString().trim();
    if (slug == null || slug.isEmpty) return;
    final url = '${_webBaseFromApi()}/c/$slug';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showPublishDialog() async {
    final project = widget.project;
    final prodUrl = _prodUrl();
    final hasProdDomain = prodUrl.trim().isNotEmpty;
    final prodLabel = hasProdDomain ? _prodLabel(prodUrl) : '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var releaseRunning = false;
        var releaseCompleted = false;
        String? releaseError;

        Future<void> directPublish(StateSetter setDialogState) async {
          if (releaseRunning) return;
          setDialogState(() {
            releaseRunning = true;
            releaseCompleted = false;
            releaseError = null;
          });
          try {
            final ok = await _publish();
            if (!ok) {
              setDialogState(() {
                releaseRunning = false;
                releaseError = _t(
                  'project_overview_community_publish_failed_sentence',
                  'Failed to publish to community.',
                );
              });
              return;
            }
            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
          } catch (e) {
            setDialogState(() {
              releaseRunning = false;
              releaseError = humanizeError(e);
            });
          }
        }

        Future<void> releaseAndPublish(StateSetter setDialogState) async {
          if (releaseRunning) return;
          setDialogState(() {
            releaseRunning = true;
            releaseCompleted = false;
            releaseError = null;
          });

          try {
            final service = D1vaiService();
            final head =
                (project.repositoryCurrentBranch ?? '').trim().isNotEmpty
                ? project.repositoryCurrentBranch!.trim()
                : 'dev';
            const base = 'main';

            String? headSha;
            String? baseSha;
            try {
              final results = await Future.wait([
                service.getGitHubBranchCommits(
                  project.id,
                  branch: head,
                  limit: 1,
                  includeStats: false,
                ),
                service.getGitHubBranchCommits(
                  project.id,
                  branch: base,
                  limit: 1,
                  includeStats: false,
                ),
              ]);

              final headCommits = results[0];
              if (headCommits.isNotEmpty && headCommits.first is Map) {
                headSha = (headCommits.first as Map)['sha']?.toString();
              }

              final baseCommits = results[1];
              if (baseCommits.isNotEmpty && baseCommits.first is Map) {
                baseSha = (baseCommits.first as Map)['sha']?.toString();
              }
            } catch (_) {}

            if (headSha == null || headSha.trim().isEmpty) {
              throw Exception(
                _t(
                  'project_overview_community_release_no_commits',
                  'No commits found on development branch',
                ),
              );
            }

            if (baseSha == null || baseSha != headSha) {
              await service.mergeGitHubBranches(
                project.id,
                baseBranch: base,
                headBranch: head,
                commitMessage: _t(
                  'project_overview_community_release_merge_message',
                  'Merge {head} into {base}',
                ).replaceAll('{head}', head).replaceAll('{base}', base),
              );
            }

            await service.deployProjectToProduction(project.id);

            final ok = await _publish();
            if (!ok) {
              throw Exception(
                _t(
                  'project_overview_community_release_publish_failed',
                  'Production deploy succeeded, but failed to publish to community',
                ),
              );
            }

            await widget.onRefreshProject?.call();
            if (mounted) {
              await Provider.of<ProjectProvider>(
                context,
                listen: false,
              ).refresh();
              await widget.onReloadDeployments();
            }

            if (!dialogContext.mounted) return;
            setDialogState(() {
              releaseCompleted = true;
              releaseRunning = false;
            });
          } catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              releaseError = humanizeError(e);
              releaseRunning = false;
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final showProgress =
                releaseRunning ||
                releaseCompleted ||
                (releaseError != null && releaseError!.trim().isNotEmpty);
            return AlertDialog(
              title: Text(
                _t(
                  'project_overview_community_publish_dialog_title',
                  'Publish to community',
                ),
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!showProgress) ...[
                      if (hasProdDomain) ...[
                        Text(
                          _t(
                            'project_overview_community_publish_dialog_has_prod',
                            'This project already has a production deployment. Publishing will create or update a community post linked to your project overview.',
                          ),
                        ),
                        if (prodLabel.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _t(
                              'project_overview_community_publish_dialog_current_domain',
                              'Current domain: {domain}',
                            ).replaceAll('{domain}', prodLabel),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ],
                      ] else ...[
                        Text(
                          _t(
                            'project_overview_community_publish_dialog_need_release',
                            "To publish this project to the community, we first need to release it to production. We'll merge your dev branch into main, trigger a production deploy, then publish the post.",
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _t(
                            'project_overview_community_publish_dialog_steps',
                            'Steps:',
                          ),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _t(
                            'project_overview_community_publish_dialog_step_merge',
                            '• Merge dev → main',
                          ),
                        ),
                        Text(
                          _t(
                            'project_overview_community_publish_dialog_step_deploy',
                            '• Trigger production deploy',
                          ),
                        ),
                        Text(
                          _t(
                            'project_overview_community_publish_dialog_step_publish',
                            '• Publish to community',
                          ),
                        ),
                      ],
                    ] else ...[
                      ProgressWidget(
                        tipList: hasProdDomain
                            ? [
                                _t(
                                  'project_overview_community_progress_publish',
                                  'Publishing to community…',
                                ),
                                _t(
                                  'project_overview_community_progress_finalizing',
                                  'Finalizing…',
                                ),
                              ]
                            : [
                                _t(
                                  'project_overview_community_progress_merge',
                                  'Merging branches…',
                                ),
                                _t(
                                  'project_overview_community_progress_deploy',
                                  'Triggering production deploy…',
                                ),
                                _t(
                                  'project_overview_community_progress_publish',
                                  'Publishing to community…',
                                ),
                              ],
                        completed: releaseCompleted,
                        width: 420,
                        onDone: () {
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                      if (releaseError != null &&
                          releaseError!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            releaseError!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: releaseRunning
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(_t('cancel', 'Cancel')),
                ),
                ElevatedButton(
                  onPressed: releaseRunning || _loadingAction == 'publish'
                      ? null
                      : () async {
                          if (hasProdDomain) {
                            await directPublish(setDialogState);
                          } else {
                            await releaseAndPublish(setDialogState);
                          }
                        },
                  child: Text(
                    hasProdDomain
                        ? _t(
                            'project_overview_community_action_publish',
                            'Publish',
                          )
                        : _t(
                            'project_overview_community_action_release_publish',
                            'Release & Publish',
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusLabel = switch (_status) {
      'published' => _t(
        'project_overview_community_status_published',
        'Published',
      ),
      'draft' => _t('project_overview_community_status_draft', 'Draft'),
      _ => _t('project_overview_community_status_none', 'Not published'),
    };

    final canInteract = !_isLoading && _loadingAction == null;
    Widget communityActionButton({
      required double width,
      required String label,
      required Widget icon,
      required VoidCallback? onPressed,
      bool primary = false,
    }) {
      final cs = theme.colorScheme;
      final outlinedStyle = OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(
          color: primary
              ? cs.primary.withValues(alpha: 0.18)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
        backgroundColor: primary
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surface.withValues(alpha: 0.48),
        foregroundColor: primary ? cs.primary : cs.onSurface,
        disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.6),
        disabledBackgroundColor: cs.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      );

      return SizedBox(
        width: width,
        child: primary
            ? FilledButton.tonalIcon(
                onPressed: onPressed,
                style: outlinedStyle,
                icon: icon,
                label: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: outlinedStyle,
                icon: icon,
                label: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public, size: 18),
                const SizedBox(width: 8),
                Text(
                  _t('project_overview_community_title', 'Community'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      communityActionButton(
                        width: buttonWidth,
                        primary: true,
                        onPressed: canInteract ? _showPublishDialog : null,
                        icon: _loadingAction == 'publish'
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: _t(
                          'project_overview_community_action_publish',
                          'Publish',
                        ),
                      ),
                      communityActionButton(
                        width: buttonWidth,
                        onPressed: canInteract && _status != 'none'
                            ? _update
                            : null,
                        icon: _loadingAction == 'update'
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: _t(
                          'project_overview_community_action_update',
                          'Update',
                        ),
                      ),
                      communityActionButton(
                        width: buttonWidth,
                        onPressed: canInteract && _status == 'published'
                            ? _unpublish
                            : null,
                        icon: _loadingAction == 'unpublish'
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.visibility_off_rounded,
                                size: 18,
                              ),
                        label: _t(
                          'project_overview_community_action_unpublish',
                          'Unpublish',
                        ),
                      ),
                      communityActionButton(
                        width: buttonWidth,
                        onPressed: canInteract && _status == 'published'
                            ? _openCommunityPost
                            : null,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: _t(
                          'project_overview_community_action_view',
                          'View',
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 10),
            Text(
              _t(
                'project_overview_community_hint',
                'Publish a community post linked to this project (auto-release to production if needed).',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
