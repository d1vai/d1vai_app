import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../models/deployment.dart';
import '../../models/project.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import 'deployment_log_screen.dart';
import '../snackbar_helper.dart';

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

class _ProjectDeployTabState extends State<ProjectDeployTab> {
  final List<DeploymentHistory> _deployments = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _deployingPreview = false;
  bool _deployingProduction = false;
  _DeploymentEnvFilter _envFilter = _DeploymentEnvFilter.all;

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
      SnackBarHelper.showError(
        context,
        title: 'Load failed',
        message: msg,
        actionLabel: authExpired ? 'Re-login' : null,
        onActionPressed: authExpired
            ? () {
                unawaited(_logoutAndGoLogin());
              }
            : null,
      );
    }
  }

  Future<void> _logoutAndGoLogin() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    context.go('/login');
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
      SnackBarHelper.showError(
        context,
        title: 'Preview deploy failed',
        message: msg,
        actionLabel: authExpired ? 'Re-login' : null,
        onActionPressed: authExpired
            ? () {
                unawaited(_logoutAndGoLogin());
              }
            : null,
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
      SnackBarHelper.showError(
        context,
        title: 'Production deploy failed',
        message: msg,
        actionLabel: authExpired ? 'Re-login' : null,
        onActionPressed: authExpired
            ? () {
                unawaited(_logoutAndGoLogin());
              }
            : null,
      );
    } finally {
      if (mounted) setState(() => _deployingProduction = false);
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Deployment History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_deployments.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_deployments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No deployments yet — deploy your project to see history here.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              )
            else
              ..._deployments.asMap().entries.map((entry) {
                final index = entry.key;
                final deployment = entry.value;
                final isLast = index == _deployments.length - 1;
                return _buildDeploymentHistoryRow(
                  deployment,
                  bottomMargin: isLast ? 0 : 12,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeploymentHistoryRow(
    DeploymentHistory deployment, {
    required double bottomMargin,
  }) {
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

    final statusColor = deployment.status == 'success'
        ? Colors.green
        : (deployment.status == 'pending' ||
              deployment.status == 'building' ||
              deployment.status == 'deploying')
        ? Colors.orange
        : Colors.red;

    final statusIcon = deployment.status == 'success'
        ? Icons.check_circle
        : (deployment.status == 'pending' ||
              deployment.status == 'building' ||
              deployment.status == 'deploying')
        ? Icons.hourglass_empty
        : Icons.error;

    return InkWell(
      onTap: () => _showDeploymentActions(deployment),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(statusIcon, size: 18, color: statusColor),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (deployment.deployedBy != null &&
                          deployment.deployedBy!.trim().isNotEmpty)
                        Text(
                          deployment.deployedBy!.trim(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
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
                        color: Colors.grey.shade600,
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
                        color: Colors.grey.shade800,
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
                        color: Colors.grey.shade700,
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
                          color: Colors.grey.shade500,
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
