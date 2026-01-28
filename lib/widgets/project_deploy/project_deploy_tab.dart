import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../models/deployment.dart';
import '../../models/project.dart';
import '../../services/d1vai_service.dart';
import '../../core/auth_expiry_bus.dart';
import '../../utils/error_utils.dart';
import 'deployment_log_screen.dart';
import '../snackbar_helper.dart';
import '../card.dart';
import '../chat/project_chat/status_dot.dart';
import '../skeleton.dart';

/// 项目详情页 - Deploy Tab
class ProjectDeployTab extends StatefulWidget {
  final UserProject project;
  final void Function(String prompt)? onAskAi;
  final Future<void> Function()? onRefreshProject;

  const ProjectDeployTab({
    super.key,
    required this.project,
    this.onAskAi,
    this.onRefreshProject,
  });

  @override
  State<ProjectDeployTab> createState() => _ProjectDeployTabState();
}

enum _DeploymentEnvFilter { all, dev, prod }

class _TroubleRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TroubleRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectDeployTabState extends State<ProjectDeployTab>
    with SingleTickerProviderStateMixin {
  final List<DeploymentHistory> _deployments = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _deployingPreview = false;
  bool _deployingProduction = false;
  bool _retryingLast = false;
  _DeploymentEnvFilter _envFilter = _DeploymentEnvFilter.all;
  late final AnimationController _ambientController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadDeployments();
    }
  }

  @override
  void didUpdateWidget(covariant ProjectDeployTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _loadDeployments();
    }
  }

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _loadDeployments() async {
    final projectId = widget.project.id;
    setState(() {
      _isLoading = true;
    });

    try {
      final service = D1vaiService();
      final deployments = await service.getProjectDeploymentHistory(
        projectId,
        environment: _envFilter == _DeploymentEnvFilter.dev
            ? 'dev'
            : _envFilter == _DeploymentEnvFilter.prod
            ? 'prod'
            : null,
        limit: 20,
      );

      if (!mounted) return;

      setState(() {
        _deployments
          ..clear()
          ..addAll(deployments);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final msg = humanizeError(e);
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(endpoint: '/api/projects/${widget.project.id}/deployments');
        return;
      }
      SnackBarHelper.showError(
        context,
        title: 'Load failed',
        message: msg,
      );
    }
  }

  Future<void> _triggerPreviewDeploy() async {
    if (_deployingPreview) return;
    setState(() => _deployingPreview = true);
    try {
      final service = D1vaiService();
      final res = await service.deployProjectPreview(widget.project.id);
      final url = (res['vercel_url'] ?? res['production_url'] ?? '')
          .toString()
          .trim();
      final msg = (res['message'] ?? '').toString().trim();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Preview deploy triggered',
        message: url.isNotEmpty ? url : (msg.isNotEmpty ? msg : 'OK'),
        actionLabel: url.isNotEmpty ? 'Open' : null,
        onActionPressed: url.isNotEmpty ? () => _openUrl(url) : null,
      );
      await widget.onRefreshProject?.call();
      await _loadDeployments();
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(endpoint: '/api/projects/${widget.project.id}/deploy/preview');
        return;
      }
      SnackBarHelper.showError(
        context,
        title: 'Preview deploy failed',
        message: msg,
        actionLabel: 'Next steps',
        onActionPressed: () => _showNextStepsDialog(msg),
      );
    } finally {
      if (mounted) setState(() => _deployingPreview = false);
    }
  }

  Future<void> _triggerProductionDeploy() async {
    if (_deployingProduction) return;
    setState(() => _deployingProduction = true);
    try {
      final service = D1vaiService();
      final res = await service.deployProjectToProduction(widget.project.id);
      final url = (res['production_url'] ?? res['vercel_url'] ?? '')
          .toString()
          .trim();
      final msg = (res['message'] ?? '').toString().trim();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Production deploy triggered',
        message: url.isNotEmpty ? url : (msg.isNotEmpty ? msg : 'OK'),
        actionLabel: url.isNotEmpty ? 'Open' : null,
        onActionPressed: url.isNotEmpty ? () => _openUrl(url) : null,
      );
      await widget.onRefreshProject?.call();
      await _loadDeployments();
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(endpoint: '/api/projects/${widget.project.id}/deploy/production');
        return;
      }
      SnackBarHelper.showError(
        context,
        title: 'Production deploy failed',
        message: msg,
        actionLabel: 'Next steps',
        onActionPressed: () => _showNextStepsDialog(msg),
      );
    } finally {
      if (mounted) setState(() => _deployingProduction = false);
    }
  }

  void _showNextStepsDialog(String errorText) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final tips = _suggestNextSteps(errorText);
        return AlertDialog(
          title: const Text('Next steps'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Common fixes:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...tips.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.arrow_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (widget.onAskAi != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAskAi!(
                    'My deploy failed with this error:\n$errorText\n\n'
                    'Give me the most likely root cause and a step-by-step fix.',
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Ask AI'),
              ),
          ],
        );
      },
    );
  }

  List<String> _suggestNextSteps(String msg) {
    final lower = msg.toLowerCase();
    final tips = <String>[
      'Open the latest build logs and copy/share the error snippet.',
      'Retry preview deploy first (then production).',
      'Check GitHub collaborator/bot access to the repo.',
      'Check environment variables (and sync to Vercel).',
    ];
    if (lower.contains('permission') || lower.contains('access denied')) {
      tips.insert(0, 'This looks like a permission issue — verify GitHub access and tokens.');
    }
    if (lower.contains('env') || lower.contains('secret') || lower.contains('key')) {
      tips.insert(0, 'This looks like an env var issue — verify required secrets are set.');
    }
    if (lower.contains('build') || lower.contains('compile') || lower.contains('typescript')) {
      tips.insert(0, 'This looks like a build failure — check compilation errors in logs.');
    }
    return tips.toSet().toList();
  }

  Future<void> _retryLastDeployment() async {
    if (_retryingLast) return;
    if (_deployments.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: 'Retry',
        message: 'No deployment history yet.',
      );
      return;
    }
    final last = _deployments.first;
    final env = last.environment.toLowerCase().trim();
    final isProd = env == 'prod' || env == 'production';
    setState(() => _retryingLast = true);
    try {
      await _confirmAndDeploy(
        title: isProd ? 'Retry production deploy?' : 'Retry preview deploy?',
        message: isProd
            ? 'This will trigger a new production deployment.'
            : 'This will trigger a new preview (dev) deployment.',
        action: isProd ? _triggerProductionDeploy : _triggerPreviewDeploy,
      );
    } finally {
      if (mounted) setState(() => _retryingLast = false);
    }
  }

  Future<void> _confirmAndDeploy({
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    return RefreshIndicator(
      onRefresh: _loadDeployments,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActionsCard(project),
            const SizedBox(height: 16),
            _buildTroubleshootingCard(project),
            const SizedBox(height: 16),
            _buildCurrentDeploymentsCard(project),
            const SizedBox(height: 16),
            _buildDeploymentHistoryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(UserProject project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deployingPreview
                        ? null
                        : () => _confirmAndDeploy(
                            title: 'Redeploy preview?',
                            message:
                                'This will trigger a new preview (dev) deployment on Vercel.',
                            action: _triggerPreviewDeploy,
                          ),
                    icon: _deployingPreview
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Redeploy preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _deployingProduction
                        ? null
                        : () => _confirmAndDeploy(
                            title: 'Deploy to production?',
                            message:
                                'This will promote dev to main and trigger a production deployment.',
                            action: _triggerProductionDeploy,
                          ),
                    icon: _deployingProduction
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: const Text('Deploy production'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_deployingPreview || _deployingProduction || _retryingLast)
                    ? null
                    : _retryLastDeployment,
                icon: _retryingLast
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.replay),
                label: const Text('Retry last deployment'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'History',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                DropdownButton<_DeploymentEnvFilter>(
                  value: _envFilter,
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _envFilter = v);
                    await _loadDeployments();
                  },
                  items: const [
                    DropdownMenuItem(
                      value: _DeploymentEnvFilter.all,
                      child: Text('All'),
                    ),
                    DropdownMenuItem(
                      value: _DeploymentEnvFilter.dev,
                      child: Text('Preview'),
                    ),
                    DropdownMenuItem(
                      value: _DeploymentEnvFilter.prod,
                      child: Text('Production'),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : _loadDeployments,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingCard(UserProject project) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Troubleshooting',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'If deploy fails, try these quick checks:',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            const _TroubleRow(icon: Icons.code, text: 'GitHub access / repo permissions'),
            const SizedBox(height: 6),
            const _TroubleRow(icon: Icons.key, text: 'Env vars configured (and synced to Vercel)'),
            const SizedBox(height: 6),
            const _TroubleRow(icon: Icons.cloud, text: 'Retry preview deploy first'),
            const SizedBox(height: 6),
            const _TroubleRow(icon: Icons.receipt_long, text: 'Open build logs and share error snippet'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onAskAi == null
                        ? null
                        : () {
                            widget.onAskAi!(
                              'My Vercel deployment failed for project "${project.projectName}". '
                              'Give a step-by-step debugging checklist based on common Vercel/Remix issues. '
                              'Also suggest what logs/env vars to check first.',
                            );
                          },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Ask AI'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _retryingLast ? null : _retryLastDeployment,
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDeploymentsCard(UserProject project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Deployments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Production deployment
            if (project.latestProdDeploymentUrl != null &&
                project.latestProdDeploymentUrl!.isNotEmpty)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                title: const Text('Production'),
                subtitle: Text(
                  _getDeploymentLabel(project.latestProdDeploymentUrl),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          _openUrl(project.latestProdDeploymentUrl!),
                      child: const Text('Open'),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
                onTap: () {
                  final question =
                      'Can you provide insights and recommendations about the Production deployment, including performance optimization, troubleshooting, and best practices?';
                  widget.onAskAi?.call(question);
                },
              )
            else
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cancel, color: Colors.grey, size: 24),
                ),
                title: const Text('Production'),
                subtitle: const Text('No production deployment'),
                onTap: () {},
              ),
            // Preview deployment
            if (project.latestPreviewUrl != null &&
                project.latestPreviewUrl!.isNotEmpty) ...[
              const Divider(),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.preview,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                title: const Text('Preview'),
                subtitle: Text(
                  _getDeploymentLabel(project.latestPreviewUrl),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _openUrl(project.latestPreviewUrl!),
                      child: const Text('Open'),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
                onTap: () {
                  final question =
                      'Can you provide insights and recommendations about the Preview deployment, including performance optimization, troubleshooting, and best practices?';
                  widget.onAskAi?.call(question);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeploymentHistoryCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final countPill = AnimatedBuilder(
      animation: _ambientController,
      builder: (context, child) {
        final t = _ambientController.value;
        final bg = Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.10 + 0.06 * t),
          colorScheme.surface,
        );
        final border = Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.18 + 0.10 * t),
          colorScheme.outlineVariant,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            '${_deployments.length}',
            style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ) ??
                TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
          ),
        );
      },
    );

    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: _isLoading
          ? Column(
              key: const ValueKey('deploy-history-loading'),
              children: const [
                SkeletonListTile(hasLeading: false, hasThreeLines: true),
                SizedBox(height: 6),
                SkeletonListTile(hasLeading: false, hasThreeLines: true),
              ],
            )
          : _deployments.isEmpty
              ? Padding(
                  key: const ValueKey('deploy-history-empty'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No deployments yet — deploy your project to see history here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.85,
                          ),
                        ) ??
                        TextStyle(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.85,
                          ),
                        ),
                  ),
                )
              : Column(
                  key: const ValueKey('deploy-history-list'),
                  children: [
                    for (final entry in _deployments.asMap().entries)
                      _StaggeredIn(
                        index: entry.key,
                        count: _deployments.length,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == _deployments.length - 1
                                ? 0
                                : 12,
                          ),
                          child: _buildDeploymentHistoryRow(entry.value),
                        ),
                      ),
                  ],
                ),
    );

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Deployment History',
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ) ??
                    const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              countPill,
            ],
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }

  Widget _buildDeploymentHistoryRow(DeploymentHistory deployment) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final when = _formatTimeAgo(
      deployment.completedAt ??
          deployment.startedAt ??
          deployment.createdAt ??
          '',
    );
    final url = deployment.primaryUrl;
    final sha = deployment.primaryCommitSha;
    final subtitleParts = <String>[];
    if (when.trim().isNotEmpty) subtitleParts.add(when);
    if (sha != null && sha.isNotEmpty) subtitleParts.add(sha.substring(0, 7));
    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join(' • ');

    final statusLower = deployment.status.toLowerCase();
    final isRunning =
        statusLower == 'pending' ||
        statusLower == 'building' ||
        statusLower == 'deploying';
    final isSuccess = statusLower == 'success';

    final statusColor = isSuccess
        ? colorScheme.tertiary
        : isRunning
            ? colorScheme.secondary
            : colorScheme.error;

    final statusIcon = isSuccess
        ? Icons.check_circle_outline
        : isRunning
            ? Icons.autorenew_rounded
            : Icons.error_outline;

    return InkWell(
      onTap: () => _showDeploymentActions(deployment),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            statusColor.withValues(alpha: 0.06),
            colorScheme.surface,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color.alphaBlend(
              statusColor.withValues(alpha: 0.18),
              colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (isRunning)
                  ProjectChatStatusDot(
                    color: statusColor,
                    size: 10,
                    enablePulse: true,
                  )
                else
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Icon(statusIcon, size: 18, color: statusColor),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${deployment.environmentLabel} • ${deployment.statusLabel}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ) ??
                              const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (deployment.deployedBy != null &&
                          deployment.deployedBy!.trim().isNotEmpty)
                        Text(
                          deployment.deployedBy!.trim(),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ],
                  if (deployment.gitCommitMessage != null &&
                      deployment.gitCommitMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      deployment.gitCommitMessage!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.92),
                      ),
                    ),
                  ] else if (deployment.statusMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      deployment.statusMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (url != null && url.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _openUrl(url),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open'),
                        ),
                      if (deployment.vercelDeploymentId != null &&
                          deployment.vercelDeploymentId!.trim().isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _openLog(deployment),
                          icon: const Icon(Icons.subject, size: 16),
                          label: const Text('Logs'),
                        ),
                      const Spacer(),
                      Text(
                        deployment.id,
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLog(DeploymentHistory deployment) async {
    final id = deployment.vercelDeploymentId?.trim();
    if (id == null || id.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: 'No logs',
        message: 'This deployment has no Vercel deployment id.',
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeploymentLogScreen(
          vercelDeploymentId: id,
          title: '${deployment.environmentLabel} logs',
        ),
      ),
    );
  }

  Future<void> _showDeploymentActions(DeploymentHistory deployment) async {
    final url = (deployment.primaryUrl ?? '').trim();
    final canOpenUrl = url.isNotEmpty;
    final canViewLogs =
        deployment.vercelDeploymentId != null &&
        deployment.vercelDeploymentId!.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${deployment.environmentLabel} deployment',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${deployment.statusLabel} • ${deployment.id}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                if (deployment.statusMessage != null &&
                    deployment.statusMessage!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      deployment.statusMessage!.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: canOpenUrl
                          ? () => _openUrl(url)
                          : null,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open'),
                    ),
                    OutlinedButton.icon(
                      onPressed: canViewLogs
                          ? () {
                              Navigator.of(context).pop();
                              _openLog(deployment);
                            }
                          : null,
                      icon: const Icon(Icons.subject),
                      label: const Text('Build logs'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onAskAi == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              final question =
                                  'Can you provide insights and recommendations about the ${deployment.environmentLabel} deployment, including performance optimization, troubleshooting, and best practices?';
                              widget.onAskAi?.call(question);
                            },
                      icon: const Icon(Icons.smart_toy),
                      label: const Text('Ask AI'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Cannot Open URL',
        message: 'Could not open $url',
      );
    }
  }
}

class _StaggeredIn extends StatelessWidget {
  final int index;
  final int count;
  final Widget child;

  const _StaggeredIn({
    required this.index,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index / (count + 6)).clamp(0.0, 1.0);
    final end = (start + 0.45).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Interval(start, end, curve: Curves.easeOutCubic),
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
    );
  }
}

String _formatTimeAgo(String isoString) {
  try {
    final dateTime = DateTime.parse(isoString);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  } catch (e) {
    return '';
  }
}

String _getDeploymentLabel(String? url) {
  if (url == null || url.isEmpty) {
    return 'Configure later';
  }
  try {
    final uri = Uri.parse(url);
    return uri.host;
  } catch (e) {
    return url;
  }
}
