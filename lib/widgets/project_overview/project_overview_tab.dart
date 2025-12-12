import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/deployment.dart';
import '../../models/project.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../app_preview.dart';
import '../snackbar_helper.dart';

/// 项目详情页 - 概览 Tab
class ProjectOverviewTab extends StatefulWidget {
  final UserProject project;

  const ProjectOverviewTab({
    super.key,
    required this.project,
  });

  @override
  State<ProjectOverviewTab> createState() => _ProjectOverviewTabState();
}

class _ProjectOverviewTabState extends State<ProjectOverviewTab> {
  final List<DeploymentHistory> _deployments = [];
  bool _isLoadingDeployments = false;

  @override
  void initState() {
    super.initState();
    _loadDeployments();
  }

  Future<void> _loadDeployments() async {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProjectHeaderCard(project: project),
          const SizedBox(height: 16),
          AppPreview(
            previewUrl: project.latestPreviewUrl,
            projectName: project.projectName,
          ),
          const SizedBox(height: 16),
          _ProjectStatsCard(project: project),
          const SizedBox(height: 16),
          _ProjectLinksCard(
            project: project,
            onOpenPreviewUrl: _openPreviewUrl,
            onOpenGitHubRepo: _openGitHubRepo,
          ),
          const SizedBox(height: 16),
          _RecentDeploymentsCard(
            deployments: _deployments,
            isLoading: _isLoadingDeployments,
          ),
          const SizedBox(height: 16),
          _HealthMetricsCard(project: project),
        ],
      ),
    );
  }

  Future<void> _openPreviewUrl(String url) async {
    if (!mounted) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final canLaunch = await canLaunchUrl(uri);

    if (mounted && canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Could not open preview URL',
      );
    }
  }

  Future<void> _openGitHubRepo(String repoName) async {
    if (!mounted) return;

    final githubUrl = 'https://github.com/d1vai/$repoName';
    final uri = Uri.tryParse(githubUrl);
    if (uri == null) return;

    final canLaunch = await canLaunchUrl(uri);

    if (!mounted) return;

    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Could not open GitHub repository',
      );
    }
  }
}

class _ProjectHeaderCard extends StatelessWidget {
  final UserProject project;

  const _ProjectHeaderCard({
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    project.emoji ?? '🚀',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.projectName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.projectDescription,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatusChip(status: project.status),
                const SizedBox(width: 8),
                Text(
                  'Updated ${_formatTimeAgo(project.updatedAt)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectStatsCard extends StatelessWidget {
  final UserProject project;

  const _ProjectStatsCard({
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.createdAt.isNotEmpty
                        ? DateFormat('MMM d, yyyy').format(
                            DateTime.parse(project.createdAt),
                          )
                        : 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      final user = authProvider.user;
                      final email = user?.email ?? 'Unknown';
                      return Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deployment',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _DeploymentLink(url: project.latestPreviewUrl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeploymentLink extends StatelessWidget {
  final String? url;

  const _DeploymentLink({
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        if (url == null || url!.isEmpty) return;
        final uri = Uri.tryParse(url!);
        if (uri == null) return;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              _getDeploymentLabel(url),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: url != null && url!.isNotEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (url != null && url!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectLinksCard extends StatelessWidget {
  final UserProject project;
  final Future<void> Function(String url) onOpenPreviewUrl;
  final Future<void> Function(String repoName) onOpenGitHubRepo;

  const _ProjectLinksCard({
    required this.project,
    required this.onOpenPreviewUrl,
    required this.onOpenGitHubRepo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Preview URL'),
            subtitle: Text(project.latestPreviewUrl ?? 'Not available'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              final url = project.latestPreviewUrl;
              if (url != null && url.isNotEmpty) {
                onOpenPreviewUrl(url);
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub Repository'),
            subtitle: Text('proj_${project.projectPort}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              onOpenGitHubRepo('proj_${project.projectPort}');
            },
          ),
        ],
      ),
    );
  }
}

class _RecentDeploymentsCard extends StatelessWidget {
  final List<DeploymentHistory> deployments;
  final bool isLoading;

  const _RecentDeploymentsCard({
    required this.deployments,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Recent deployments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Activity feed',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (deployments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No recent deployments — ship a new build to see activity here.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...deployments.map((deployment) {
                final timestamp = deployment.completedAt ??
                    deployment.startedAt ??
                    deployment.createdAt ??
                    '';
                Color statusColor;
                if (deployment.status == 'success') {
                  statusColor = theme.colorScheme.primary;
                } else if (deployment.status == 'pending') {
                  statusColor = theme.colorScheme.tertiary;
                } else {
                  statusColor = theme.colorScheme.error;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          deployment.status == 'success'
                              ? Icons.check_circle
                              : deployment.status == 'pending'
                                  ? Icons.hourglass_empty
                                  : Icons.error,
                          size: 18,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${deployment.environment} deployment',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatTimeAgo(timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              deployment.statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _HealthMetricsCard extends StatelessWidget {
  final UserProject project;

  const _HealthMetricsCard({
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _HealthMetricItem(
              title: 'Production domain',
              status: project.latestProdDeploymentUrl != null &&
                      project.latestProdDeploymentUrl!.isNotEmpty
                  ? project.latestProdDeploymentUrl!
                  : (project.vercelProdDomain != null &&
                          project.vercelProdDomain!.isNotEmpty
                      ? project.vercelProdDomain!
                      : '—'),
              description: project.latestProdDeploymentUrl != null &&
                      project.latestProdDeploymentUrl!.isNotEmpty
                  ? 'Primary public endpoint'
                  : 'No domain configured',
              icon: Icons.language,
              isEnabled: project.latestProdDeploymentUrl != null &&
                  project.latestProdDeploymentUrl!.isNotEmpty,
            ),
            const Divider(height: 32),
            _HealthMetricItem(
              title: 'Analytics status',
              status: project.analyticsEnabled == true ? 'Enabled' : 'Disabled',
              description: 'Traffic instrumentation',
              icon: Icons.analytics,
              isEnabled: project.analyticsEnabled == true,
            ),
            const Divider(height: 32),
            _HealthMetricItem(
              title: 'Database',
              status:
                  project.projectDatabaseId != null ? 'Enabled' : 'Disabled',
              description: 'Neon integration',
              icon: Icons.storage,
              isEnabled: project.projectDatabaseId != null,
            ),
            const Divider(height: 32),
            _HealthMetricItem(
              title: 'Payments',
              status: project.projectPayId != null ? 'Enabled' : 'Disabled',
              description: 'User-scoped Pay API',
              icon: Icons.payment,
              isEnabled: project.projectPayId != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthMetricItem extends StatelessWidget {
  final String title;
  final String status;
  final String description;
  final IconData icon;
  final bool isEnabled;

  const _HealthMetricItem({
    required this.title,
    required this.status,
    required this.description,
    required this.icon,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'Active';
        break;
      case 'archived':
        color = Colors.orange;
        label = 'Archived';
        break;
      case 'draft':
        color = Colors.grey;
        label = 'Draft';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
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
