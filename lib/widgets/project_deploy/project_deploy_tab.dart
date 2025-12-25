import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/deployment.dart';
import '../../models/project.dart';
import '../../services/d1vai_service.dart';
import '../snackbar_helper.dart';

/// 项目详情页 - Deploy Tab
class ProjectDeployTab extends StatefulWidget {
  final UserProject project;
  final void Function(String prompt)? onAskAi;

  const ProjectDeployTab({
    super.key,
    required this.project,
    this.onAskAi,
  });

  @override
  State<ProjectDeployTab> createState() => _ProjectDeployTabState();
}

class _ProjectDeployTabState extends State<ProjectDeployTab> {
  final List<DeploymentHistory> _deployments = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadDeployments();
    }
  }

  Future<void> _loadDeployments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final service = D1vaiService();
      final deployments = await service.getProjectDeploymentHistory(
        widget.project.id,
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
          _buildCurrentDeploymentsCard(project),
          const SizedBox(height: 16),
          _buildDeploymentHistoryCard(),
        ],
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
                  child:
                      const Icon(Icons.check_circle, color: Colors.green, size: 24),
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
                      onPressed: () => _openUrl(project.latestProdDeploymentUrl!),
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  child: const Icon(Icons.preview, color: Colors.blue, size: 24),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else
              ..._deployments.asMap().entries.map((entry) {
                final index = entry.key;
                final deployment = entry.value;
                final isLast = index == _deployments.length - 1;

                return InkWell(
                  onTap: () {
                    final question =
                        'Can you provide insights and recommendations about the ${deployment.environment} deployment, including performance optimization, troubleshooting, and best practices?';
                    widget.onAskAi?.call(question);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: isLast
                        ? const EdgeInsets.only(bottom: 0)
                        : const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              deployment.status == 'success'
                                  ? Icons.check_circle
                                  : deployment.status == 'pending'
                                      ? Icons.hourglass_empty
                                      : Icons.error,
                              size: 18,
                              color: deployment.status == 'success'
                                  ? Colors.green
                                  : deployment.status == 'pending'
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${deployment.environment} deployment',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimeAgo(
                                      deployment.completedAt ??
                                          deployment.startedAt ??
                                          deployment.createdAt ??
                                          '',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (deployment.statusMessage != null)
                          Text(
                            deployment.statusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
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
