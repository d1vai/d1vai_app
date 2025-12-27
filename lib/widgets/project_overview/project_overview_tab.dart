import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/deployment.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../core/api_client.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../app_preview.dart';
import '../progress_widget.dart';
import '../snackbar_helper.dart';
import 'components/project_overview_danger_zone_card.dart';
import 'components/project_overview_header_card.dart';
import 'components/project_overview_health_metrics_card.dart';
import 'components/project_overview_links_card.dart';
import 'components/project_overview_recent_deployments_card.dart';
import 'components/project_overview_stats_card.dart';

/// 项目详情页 - 概览 Tab
class ProjectOverviewTab extends StatefulWidget {
  final UserProject project;
  final Future<void> Function()? onRefreshProject;

  const ProjectOverviewTab({
    super.key,
    required this.project,
    this.onRefreshProject,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProjectOverviewHeaderCard(project: project),
          const SizedBox(height: 16),
          _CommunityActionsCard(
            project: project,
            onRefreshProject: widget.onRefreshProject,
            onReloadDeployments: _loadDeployments,
          ),
          const SizedBox(height: 16),
          AppPreview(
            previewUrl: project.latestPreviewUrl,
            projectName: project.projectName,
          ),
          const SizedBox(height: 16),
          ProjectOverviewStatsCard(project: project),
          const SizedBox(height: 16),
          ProjectOverviewLinksCard(
            project: project,
            onOpenPreviewUrl: _openPreviewUrl,
            onOpenGitHubRepo: _openGitHubRepo,
          ),
          const SizedBox(height: 16),
          ProjectOverviewRecentDeploymentsCard(
            deployments: _deployments,
            isLoading: _isLoadingDeployments,
          ),
          const SizedBox(height: 16),
          ProjectOverviewHealthMetricsCard(project: project),
          const SizedBox(height: 16),
          ProjectOverviewDangerZoneCard(project: project),
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
            title: 'Success',
            message: 'Published to community',
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
        title: 'Error',
        message: 'Failed to publish to community',
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
        title: 'Success',
        message: 'Post updated',
      );
      await _loadPost();
    } catch (_) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to update post',
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
        title: 'Success',
        message: 'Unpublished',
      );
      await _loadPost();
    } catch (_) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to unpublish',
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
                releaseError = 'Failed to publish to community.';
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
            final head = (project.repositoryCurrentBranch ?? '').trim().isNotEmpty
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
              throw Exception('No commits found on development branch');
            }

            if (baseSha == null || baseSha != headSha) {
              await service.mergeGitHubBranches(
                project.id,
                baseBranch: base,
                headBranch: head,
                commitMessage: 'Merge $head into $base',
              );
            }

            await service.deployProjectToProduction(project.id);

            final ok = await _publish();
            if (!ok) {
              throw Exception(
                'Production deploy succeeded, but failed to publish to community',
              );
            }

            await widget.onRefreshProject?.call();
            if (mounted) {
              await Provider.of<ProjectProvider>(context, listen: false).refresh();
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
            final showProgress = releaseRunning ||
                releaseCompleted ||
                (releaseError != null && releaseError!.trim().isNotEmpty);
            return AlertDialog(
              title: const Text('Publish to community'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!showProgress) ...[
                      if (hasProdDomain) ...[
                        const Text(
                          'This project already has a production deployment. Publishing will create or update a community post linked to your project overview.',
                        ),
                        if (prodLabel.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Current domain: $prodLabel',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                ),
                          ),
                        ],
                      ] else ...[
                        const Text(
                          "To publish this project to the community, we first need to release it to production. We'll merge your dev branch into main, trigger a production deploy, then publish the post.",
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Steps:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text('• Merge dev → main'),
                        const Text('• Trigger production deploy'),
                        const Text('• Publish to community'),
                      ],
                    ] else ...[
                      ProgressWidget(
                        tipList: hasProdDomain
                            ? const [
                                'Publishing to community…',
                                'Finalizing…',
                              ]
                            : const [
                                'Merging branches…',
                                'Triggering production deploy…',
                                'Publishing to community…',
                              ],
                        completed: releaseCompleted,
                        width: 420,
                        onDone: () {
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                      if (releaseError != null && releaseError!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .errorContainer
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            releaseError!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  onPressed: releaseRunning ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
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
                  child: Text(hasProdDomain ? 'Publish' : 'Release & Publish'),
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
      'published' => 'Published',
      'draft' => 'Draft',
      _ => 'Not published',
    };

    final canInteract = !_isLoading && _loadingAction == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Community',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: canInteract ? _showPublishDialog : null,
                    icon: _loadingAction == 'publish'
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: const Text('Publish'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        canInteract && _status != 'none' ? _update : null,
                    icon: _loadingAction == 'update'
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text('Update'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        canInteract && _status == 'published' ? _unpublish : null,
                    icon: _loadingAction == 'unpublish'
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_off, size: 18),
                    label: const Text('Unpublish'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        canInteract && _status == 'published' ? _openCommunityPost : null,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View'),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              'Publish a community post linked to this project (auto-release to production if needed).',
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
