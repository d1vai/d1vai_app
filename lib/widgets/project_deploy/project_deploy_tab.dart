import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/deployment.dart';
import '../../models/project.dart';
import '../../services/d1vai_service.dart';
import '../../core/auth_expiry_bus.dart';
import '../../utils/error_utils.dart';
import '../../utils/preview_url.dart';
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

enum _ProductionReleasePhase { idle, checking, merging, deploying }

class _ReleaseCommit {
  final String sha;
  final String message;
  final String authorName;
  final String authoredAt;

  const _ReleaseCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    required this.authoredAt,
  });
}

class _ReleaseGroup {
  final _ReleaseCommit merge;
  final List<_ReleaseCommit> items;

  const _ReleaseGroup({required this.merge, required this.items});
}

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
            style: theme.textTheme.bodySmall?.copyWith(
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
  bool _revertingCommit = false;
  String? _revertingCommitSha;
  bool _isLoadingReleases = false;
  String? _releaseError;
  final List<_ReleaseCommit> _releaseCommits = [];
  _ProductionReleasePhase _productionReleasePhase =
      _ProductionReleasePhase.idle;
  _DeploymentEnvFilter _envFilter = _DeploymentEnvFilter.all;
  late final AnimationController _ambientController;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadDeployments();
      _loadReleases();
    }
  }

  @override
  void didUpdateWidget(covariant ProjectDeployTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _loadDeployments();
      _loadReleases();
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
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.project.id}/deployments',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('failed_to_load', 'Failed to load'),
        message: msg,
      );
    }
  }

  String get _productionPhaseLabel {
    switch (_productionReleasePhase) {
      case _ProductionReleasePhase.checking:
        return _t('project_deploy_phase_checking', 'Checking dev/main diff...');
      case _ProductionReleasePhase.merging:
        return _t('project_deploy_phase_merging', 'Merging dev into main...');
      case _ProductionReleasePhase.deploying:
        return _t(
          'project_deploy_phase_deploying',
          'Triggering production deploy...',
        );
      case _ProductionReleasePhase.idle:
        return _t('project_deploy_action_deploy_prod', 'Deploy production');
    }
  }

  String _resolveDevBranch() {
    final value =
        (widget.project.workspaceCurrentBranch ??
                widget.project.repositoryCurrentBranch ??
                'dev')
            .trim();
    return value.isEmpty ? 'dev' : value;
  }

  String _resolveMainBranch() {
    final value = (widget.project.repositoryDefaultBranch ?? 'main').trim();
    return value.isEmpty ? 'main' : value;
  }

  String? _extractCommitSha(dynamic commit) {
    if (commit is! Map) return null;
    final sha = commit['sha']?.toString().trim();
    if (sha == null || sha.isEmpty) return null;
    return sha;
  }

  _ReleaseCommit? _parseReleaseCommit(dynamic raw) {
    if (raw is! Map) return null;
    final sha = raw['sha']?.toString().trim() ?? '';
    if (sha.isEmpty) return null;
    final message = (raw['message'] ?? '').toString().trim();
    final author = raw['author'];
    final authorName = author is Map
        ? (author['name'] ?? '').toString().trim()
        : '';
    final authoredAt = author is Map
        ? (author['date'] ?? '').toString().trim()
        : '';
    return _ReleaseCommit(
      sha: sha,
      message: message.isEmpty
          ? _t('project_deploy_no_message', '(no message)')
          : message,
      authorName: authorName,
      authoredAt: authoredAt,
    );
  }

  Future<void> _loadReleases() async {
    if (_isLoadingReleases) return;
    setState(() {
      _isLoadingReleases = true;
      _releaseError = null;
    });
    try {
      final service = D1vaiService();
      final commits = await service.getGitHubBranchCommits(
        widget.project.id,
        branch: _resolveMainBranch(),
        limit: 50,
      );
      final parsed = commits
          .map(_parseReleaseCommit)
          .whereType<_ReleaseCommit>()
          .toList();
      if (!mounted) return;
      setState(() {
        _releaseCommits
          ..clear()
          ..addAll(parsed);
        _isLoadingReleases = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      if (isAuthExpiredText(msg)) {
        AuthExpiryBus.trigger(
          endpoint: '/api/github-ops/${widget.project.id}/commits',
        );
        setState(() {
          _isLoadingReleases = false;
          _releaseError = null;
        });
        return;
      }
      setState(() {
        _isLoadingReleases = false;
        _releaseError = msg;
      });
    }
  }

  bool _isMergeCommitMessage(String msg) {
    final m = msg.trim();
    if (m.isEmpty) return false;
    return RegExp(r'Merge .* into main', caseSensitive: false).hasMatch(m) ||
        RegExp(
          r"Merge branch '.*' into main",
          caseSensitive: false,
        ).hasMatch(m) ||
        RegExp(r'Merge pull request #\d+', caseSensitive: false).hasMatch(m);
  }

  List<_ReleaseGroup> _buildReleaseGroups(List<_ReleaseCommit> commits) {
    final groups = <_ReleaseGroup>[];
    _ReleaseCommit? currentMerge;
    final currentItems = <_ReleaseCommit>[];

    for (final c in commits) {
      if (_isMergeCommitMessage(c.message)) {
        if (currentMerge != null) {
          groups.add(
            _ReleaseGroup(merge: currentMerge, items: List.of(currentItems)),
          );
        }
        currentMerge = c;
        currentItems.clear();
      } else if (currentMerge != null) {
        currentItems.add(c);
      }
    }

    if (currentMerge != null) {
      groups.add(
        _ReleaseGroup(merge: currentMerge, items: List.of(currentItems)),
      );
    }
    return groups;
  }

  Future<void> _triggerPreviewDeploy() async {
    if (_deployingPreview) return;
    setState(() => _deployingPreview = true);
    try {
      final service = D1vaiService();
      final res = await service.deployProjectPreview(widget.project.id);
      final url = _normalizeHttpUrl(
        (preferredPreviewUrlFromPayload(res) ?? '').toString(),
      );
      final msg = (res['message'] ?? '').toString().trim();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t(
          'project_deploy_preview_triggered',
          'Preview deploy triggered',
        ),
        message: (url != null && url.isNotEmpty)
            ? url
            : (msg.isNotEmpty ? msg : _t('project_deploy_ok', 'OK')),
        actionLabel: (url != null && url.isNotEmpty)
            ? _t('project_deploy_open', 'Open')
            : null,
        onActionPressed: (url != null && url.isNotEmpty)
            ? () => _openUrl(url)
            : null,
      );
      await widget.onRefreshProject?.call();
      await _loadDeployments();
      await _loadReleases();
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.project.id}/deploy/preview',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('project_deploy_preview_failed', 'Preview deploy failed'),
        message: msg,
        actionLabel: _t('project_deploy_next_steps', 'Next steps'),
        onActionPressed: () => _showNextStepsDialog(msg),
      );
    } finally {
      if (mounted) setState(() => _deployingPreview = false);
    }
  }

  Future<void> _triggerProductionDeploy() async {
    if (_deployingProduction) return;
    setState(() {
      _deployingProduction = true;
      _productionReleasePhase = _ProductionReleasePhase.checking;
    });
    try {
      final service = D1vaiService();
      final headBranch = _resolveDevBranch();
      final baseBranch = _resolveMainBranch();
      final latestDev = await service.getGitHubBranchCommits(
        widget.project.id,
        branch: headBranch,
        limit: 1,
      );
      final latestMain = await service.getGitHubBranchCommits(
        widget.project.id,
        branch: baseBranch,
        limit: 1,
      );
      final devSha = latestDev.isEmpty
          ? null
          : _extractCommitSha(latestDev.first);
      final mainSha = latestMain.isEmpty
          ? null
          : _extractCommitSha(latestMain.first);
      final shouldMerge =
          devSha == null || mainSha == null || devSha != mainSha;

      if (shouldMerge) {
        if (!mounted) return;
        setState(
          () => _productionReleasePhase = _ProductionReleasePhase.merging,
        );
        await service.mergeGitHubBranches(
          widget.project.id,
          baseBranch: baseBranch,
          headBranch: headBranch,
          commitMessage: 'Merge $headBranch into $baseBranch',
        );
      }

      if (!mounted) return;
      setState(
        () => _productionReleasePhase = _ProductionReleasePhase.deploying,
      );
      final res = await service.deployProjectToProduction(widget.project.id);
      final url = _normalizeHttpUrl(
        (res['production_url'] ?? res['vercel_url'] ?? '').toString(),
      );
      final msg = (res['message'] ?? '').toString().trim();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: shouldMerge
            ? _t(
                'project_deploy_prod_merged_triggered',
                'Merged and deployed to production',
              )
            : _t(
                'project_deploy_prod_triggered',
                'Production deploy triggered',
              ),
        message: (url != null && url.isNotEmpty)
            ? url
            : (msg.isNotEmpty ? msg : _t('project_deploy_ok', 'OK')),
        actionLabel: (url != null && url.isNotEmpty)
            ? _t('project_deploy_open', 'Open')
            : null,
        onActionPressed: (url != null && url.isNotEmpty)
            ? () => _openUrl(url)
            : null,
      );
      await widget.onRefreshProject?.call();
      await _loadDeployments();
      await _loadReleases();
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint: '/api/deployment/${widget.project.id}/production',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('project_deploy_prod_failed', 'Production deploy failed'),
        message: msg,
        actionLabel: _t('project_deploy_next_steps', 'Next steps'),
        onActionPressed: () => _showNextStepsDialog(msg),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deployingProduction = false;
          _productionReleasePhase = _ProductionReleasePhase.idle;
        });
      }
    }
  }

  Future<void> _confirmRevertDeployment(DeploymentHistory deployment) async {
    final sha = deployment.primaryCommitSha?.trim();
    if (sha == null || sha.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: _t('project_deploy_revert_unavailable', 'Revert unavailable'),
        message: _t(
          'project_deploy_revert_no_sha',
          'No commit SHA found for this deployment.',
        ),
      );
      return;
    }
    if (_revertingCommit) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _t('project_deploy_revert_confirm_title', 'Revert this commit?'),
          ),
          content: Text(
            _t(
              'project_deploy_revert_confirm_message',
              'This will run git revert on commit {sha} and trigger a new preview deployment.',
            ).replaceAll('{sha}', sha.substring(0, 7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_t('cancel', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                _t('project_deploy_revert_confirm_action', 'Confirm revert'),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await _revertCommitAndPreviewRedeploy(sha);
  }

  Future<void> _revertCommitAndPreviewRedeploy(String sha) async {
    if (_revertingCommit) return;
    setState(() {
      _revertingCommit = true;
      _revertingCommitSha = sha;
    });
    try {
      final service = D1vaiService();
      await service.revertGitCommit(widget.project.id, commitHash: sha);
      final deployRes = await service.deployProjectPreview(widget.project.id);
      final url = _normalizeHttpUrl(
        (preferredPreviewUrlFromPayload(deployRes) ?? '').toString(),
      );

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('project_deploy_revert_success_title', 'Commit reverted'),
        message: (url != null && url.isNotEmpty)
            ? _t(
                'project_deploy_revert_success_with_url',
                'Preview redeploy started: {url}',
              ).replaceAll('{url}', url)
            : _t('project_deploy_revert_success', 'Preview redeploy started'),
        actionLabel: (url != null && url.isNotEmpty)
            ? _t('project_deploy_open', 'Open')
            : null,
        onActionPressed: (url != null && url.isNotEmpty)
            ? () => _openUrl(url)
            : null,
      );
      await widget.onRefreshProject?.call();
      await _loadDeployments();
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(endpoint: '/api/git/${widget.project.id}/revert');
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('project_deploy_revert_failed', 'Revert failed'),
        message: msg,
        actionLabel: _t('project_deploy_next_steps', 'Next steps'),
        onActionPressed: () => _showNextStepsDialog(msg),
      );
    } finally {
      if (mounted) {
        setState(() {
          _revertingCommit = false;
          _revertingCommitSha = null;
        });
      }
    }
  }

  void _showNextStepsDialog(String errorText) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final tips = _suggestNextSteps(errorText);
        return AlertDialog(
          title: Text(_t('project_deploy_next_steps', 'Next steps')),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('project_deploy_common_fixes', 'Common fixes:'),
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
              child: Text(_t('project_deploy_close', 'Close')),
            ),
            if (widget.onAskAi != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAskAi!(
                    '${_t('project_deploy_ai_prompt_prefix', 'My deploy failed with this error:')}\n$errorText\n\n'
                    '${_t('project_deploy_ai_prompt_suffix', 'Give me the most likely root cause and a step-by-step fix.')}',
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: Text(_t('project_deploy_ask_ai', 'Ask AI')),
              ),
          ],
        );
      },
    );
  }

  List<String> _suggestNextSteps(String msg) {
    final lower = msg.toLowerCase();
    final tips = <String>[
      _t(
        'project_deploy_tip_open_logs',
        'Open the latest build logs and copy/share the error snippet.',
      ),
      _t(
        'project_deploy_tip_retry_preview_first',
        'Retry preview deploy first (then production).',
      ),
      _t(
        'project_deploy_tip_check_github_access',
        'Check GitHub collaborator/bot access to the repo.',
      ),
      _t(
        'project_deploy_tip_check_env_vars',
        'Check environment variables (and sync to Vercel).',
      ),
    ];
    if (lower.contains('permission') || lower.contains('access denied')) {
      tips.insert(
        0,
        _t(
          'project_deploy_tip_permission',
          'This looks like a permission issue — verify GitHub access and tokens.',
        ),
      );
    }
    if (lower.contains('env') ||
        lower.contains('secret') ||
        lower.contains('key')) {
      tips.insert(
        0,
        _t(
          'project_deploy_tip_env_issue',
          'This looks like an env var issue — verify required secrets are set.',
        ),
      );
    }
    if (lower.contains('build') ||
        lower.contains('compile') ||
        lower.contains('typescript')) {
      tips.insert(
        0,
        _t(
          'project_deploy_tip_build_issue',
          'This looks like a build failure — check compilation errors in logs.',
        ),
      );
    }
    return tips.toSet().toList();
  }

  Future<void> _retryLastDeployment() async {
    if (_retryingLast) return;
    if (_deployments.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: _t('retry', 'Retry'),
        message: _t('project_deploy_no_history', 'No deployment history yet.'),
      );
      return;
    }
    final last = _deployments.first;
    final env = last.environment.toLowerCase().trim();
    final isProd = env == 'prod' || env == 'production';
    setState(() => _retryingLast = true);
    try {
      await _confirmAndDeploy(
        title: isProd
            ? _t('project_deploy_retry_prod_title', 'Retry production deploy?')
            : _t('project_deploy_retry_preview_title', 'Retry preview deploy?'),
        message: isProd
            ? _t(
                'project_deploy_retry_prod_message',
                'This will compare dev/main, merge if needed, then trigger a new production deployment.',
              )
            : _t(
                'project_deploy_retry_preview_message',
                'This will trigger a new preview (dev) deployment.',
              ),
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
              child: Text(_t('cancel', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_t('confirm', 'Confirm')),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await action();
  }

  String _formatTimeAgo(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return _t('project_deploy_time_just_now', 'just now');
      }
      if (difference.inMinutes < 60) {
        return _t(
          'project_deploy_time_minutes_ago',
          '{minutes}m ago',
        ).replaceAll('{minutes}', difference.inMinutes.toString());
      }
      if (difference.inHours < 24) {
        return _t(
          'project_deploy_time_hours_ago',
          '{hours}h ago',
        ).replaceAll('{hours}', difference.inHours.toString());
      }
      if (difference.inDays < 7) {
        return _t(
          'project_deploy_time_days_ago',
          '{days}d ago',
        ).replaceAll('{days}', difference.inDays.toString());
      }
      final localeTag = Localizations.localeOf(context).toLanguageTag();
      return DateFormat.yMd(localeTag).format(dateTime);
    } catch (_) {
      return '';
    }
  }

  String _getDeploymentLabel(String? url) {
    final normalized = _normalizeHttpUrl(url);
    if (normalized == null || normalized.isEmpty) {
      return _t('project_deploy_configure_later', 'Configure later');
    }
    try {
      final uri = Uri.parse(normalized);
      return uri.host;
    } catch (_) {
      return normalized;
    }
  }

  String? _activeFlowHint() {
    if (_revertingCommit) {
      final shortSha = (_revertingCommitSha ?? '').trim();
      final suffix = shortSha.isEmpty ? '' : ' (${shortSha.substring(0, 7)})';
      return _t(
        'project_deploy_active_reverting',
        'Rolling back commit{suffix} and triggering preview deploy...',
      ).replaceAll('{suffix}', suffix);
    }
    if (_deployingProduction) {
      return _t(
        'project_deploy_active_prod',
        'Production release in progress: {phase}',
      ).replaceAll('{phase}', _productionPhaseLabel.replaceAll('...', ''));
    }
    if (_deployingPreview) {
      return _t(
        'project_deploy_active_preview',
        'Preview deployment in progress...',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDeployments();
        await _loadReleases();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeployControlDeck(project, isWide: isWide),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildReleasesCard(project)),
                      const SizedBox(width: 16),
                      Expanded(flex: 7, child: _buildDeploymentHistoryCard()),
                    ],
                  )
                else ...[
                  _buildReleasesCard(project),
                  const SizedBox(height: 16),
                  _buildDeploymentHistoryCard(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeployControlDeck(UserProject project, {required bool isWide}) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: _buildCommandCenterCard(project)),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: _buildEnvironmentSnapshotCard(project)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommandCenterCard(project),
        const SizedBox(height: 16),
        _buildEnvironmentSnapshotCard(project),
      ],
    );
  }

  Widget _buildCommandCenterCard(UserProject project) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeHint = _activeFlowHint();
    final previewReady = (project.preferredPreviewUrl ?? '').trim().isNotEmpty;
    final prodReady = (project.latestProdDeploymentUrl ?? '').trim().isNotEmpty;
    final branch = _resolveDevBranch();
    final releaseBranch = _resolveMainBranch();

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Color.alphaBlend(
                    colorScheme.primary.withValues(alpha: 0.12),
                    colorScheme.surface,
                  ),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('project_deploy_control_title', 'Release control'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activeHint ??
                          (prodReady
                              ? _t(
                                  'project_deploy_coach_prod_live',
                                  'Production is live. Keep shipping with small preview iterations.',
                                )
                              : previewReady
                              ? _t(
                                  'project_deploy_coach_preview_ready',
                                  'Preview is ready. Recommended next step: release to production.',
                                )
                              : _t(
                                  'project_deploy_coach_no_preview',
                                  'No preview yet. Start with a preview deploy to reduce release risk.',
                                )),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.92,
                        ),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _DeployInlinePill(
                          icon: Icons.alt_route,
                          text: '$branch -> $releaseBranch',
                          monospace: true,
                        ),
                        _DeployInlinePill(
                          icon: Icons.history_toggle_off,
                          text:
                              '${_deployments.length} ${_t('project_deploy_history', 'History').toLowerCase()}',
                        ),
                        if (_isLoadingReleases)
                          _DeployInlinePill(
                            icon: Icons.sync,
                            text: _t(
                              'project_deploy_loading_releases',
                              'Refreshing releases',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: FilledButton.icon(
                  onPressed: _deployingProduction
                      ? null
                      : () => _confirmAndDeploy(
                          title: _t(
                            'project_deploy_confirm_prod_title',
                            'Deploy to production?',
                          ),
                          message: _t(
                            'project_deploy_confirm_prod_message',
                            'This will compare dev/main, merge if needed, then trigger a production deployment.',
                          ),
                          action: _triggerProductionDeploy,
                        ),
                  icon: _deployingProduction
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    _deployingProduction
                        ? _productionPhaseLabel
                        : _t(
                            'project_deploy_action_deploy_prod',
                            'Deploy production',
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: _deployingPreview
                      ? null
                      : () => _confirmAndDeploy(
                          title: _t(
                            'project_deploy_confirm_preview_title',
                            'Redeploy preview?',
                          ),
                          message: _t(
                            'project_deploy_confirm_preview_message',
                            'This will trigger a new preview (dev) deployment on Vercel.',
                          ),
                          action: _triggerPreviewDeploy,
                        ),
                  icon: _deployingPreview
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _t(
                      'project_deploy_action_redeploy_preview',
                      'Redeploy preview',
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed:
                      (_deployingPreview ||
                          _deployingProduction ||
                          _retryingLast)
                      ? null
                      : _retryLastDeployment,
                  icon: _retryingLast
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.replay_rounded),
                  label: Text(
                    _t('project_deploy_retry_last', 'Retry last deployment'),
                  ),
                ),
              ),
            ],
          ),
          if (_deployingProduction) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t(
                        'project_deploy_release_flow',
                        'Release flow: {phase}',
                      ).replaceAll(
                        '{phase}',
                        _productionPhaseLabel.replaceAll('...', ''),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            _t('project_deploy_troubleshooting', 'Failure triage'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'project_deploy_troubleshooting_hint',
              'Start with the shortest path to isolate build, config, and permission issues.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 260,
                child: _TroubleRow(
                  icon: Icons.receipt_long,
                  text: _t(
                    'project_deploy_tip_short_logs',
                    'Open build logs and share error snippet',
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: _TroubleRow(
                  icon: Icons.key,
                  text: _t(
                    'project_deploy_tip_short_env',
                    'Env vars configured (and synced to Vercel)',
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: _TroubleRow(
                  icon: Icons.code,
                  text: _t(
                    'project_deploy_tip_short_github',
                    'GitHub access / repo permissions',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (widget.onAskAi != null)
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onAskAi!(
                      '${_t('project_deploy_ai_prompt_vercel_prefix', 'My Vercel deployment failed for project')} "${project.projectName}". '
                      '${_t('project_deploy_ai_prompt_vercel_middle', 'Give a step-by-step debugging checklist based on common Vercel/Remix issues.')} '
                      '${_t('project_deploy_ai_prompt_vercel_suffix', 'Also suggest what logs/env vars to check first.')}',
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_t('project_deploy_ask_ai', 'Ask AI')),
                ),
              TextButton.icon(
                onPressed: _isLoading ? null : _loadDeployments,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(_t('refresh', 'Refresh')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentSnapshotCard(UserProject project) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final productionUrl = _normalizeHttpUrl(
      project.latestProdDeploymentUrl ?? project.vercelProdDomain,
    );
    final previewUrl = _normalizeHttpUrl(project.preferredPreviewUrl);

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('project_deploy_current_deployments', 'Current Deployments'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'project_deploy_snapshot_hint',
              'Use this as the source of truth for what is live now and what is safe to release next.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _buildDeploymentSurfaceTile(
            title: _t('project_deploy_filter_production', 'Production'),
            url: productionUrl,
            icon: Icons.public,
            iconColor: colorScheme.tertiary,
            onAskAiPrompt: _t(
              'project_deploy_ai_prompt_prod',
              'Can you provide insights and recommendations about the Production deployment, including performance optimization, troubleshooting, and best practices?',
            ),
          ),
          const SizedBox(height: 12),
          _buildDeploymentSurfaceTile(
            title: _t('project_deploy_filter_preview', 'Preview'),
            url: previewUrl,
            icon: Icons.preview,
            iconColor: colorScheme.primary,
            onAskAiPrompt: _t(
              'project_deploy_ai_prompt_preview',
              'Can you provide insights and recommendations about the Preview deployment, including performance optimization, troubleshooting, and best practices?',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeploymentSurfaceTile({
    required String title,
    required String? url,
    required IconData icon,
    required Color iconColor,
    required String onAskAiPrompt,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAvailable = url != null && url.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Color.alphaBlend(
          iconColor.withValues(alpha: 0.05),
          colorScheme.surface,
        ),
        border: Border.all(
          color: Color.alphaBlend(
            iconColor.withValues(alpha: 0.16),
            colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isAvailable
                          ? _getDeploymentLabel(url)
                          : _t(
                              'project_deploy_no_surface',
                              'Not available yet',
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isAvailable
                            ? iconColor
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isAvailable ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isAvailable)
                FilledButton.tonalIcon(
                  onPressed: () => _openUrl(url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(_t('project_deploy_open', 'Open')),
                ),
              if (isAvailable)
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (!mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: _t('copied', 'Copied'),
                      message: url,
                    );
                  },
                  icon: const Icon(Icons.content_copy_outlined, size: 16),
                  label: Text(_t('project_deploy_copy', 'Copy')),
                ),
              if (widget.onAskAi != null)
                TextButton.icon(
                  onPressed: () => widget.onAskAi?.call(onAskAiPrompt),
                  icon: const Icon(Icons.smart_toy_outlined, size: 16),
                  label: Text(_t('project_deploy_ask_ai', 'Ask AI')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReleasesCard(UserProject project) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groups = _buildReleaseGroups(_releaseCommits);
    final productionUrl = _normalizeHttpUrl(
      project.latestProdDeploymentUrl ?? project.vercelProdDomain,
    );
    final productionHost = _getDeploymentLabel(productionUrl);

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _t('project_deploy_releases', 'Releases'),
                style:
                    theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ) ??
                    const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                _t('project_deploy_releases_main', '(main)'),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _t(
                  'project_deploy_refresh_releases',
                  'Refresh releases',
                ),
                onPressed: _isLoadingReleases ? null : _loadReleases,
                icon: _isLoadingReleases
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          if (productionUrl != null && productionUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      productionHost,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openUrl(productionUrl),
                    child: Text(_t('project_deploy_open', 'Open')),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: productionUrl),
                      );
                      if (!mounted) return;
                      SnackBarHelper.showSuccess(
                        context,
                        title: _t('copied', 'Copied'),
                        message: productionUrl,
                      );
                    },
                    child: Text(_t('project_deploy_copy', 'Copy')),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_isLoadingReleases)
            const Column(
              children: [
                SkeletonListTile(hasLeading: false, hasThreeLines: true),
                SizedBox(height: 8),
                SkeletonListTile(hasLeading: false, hasThreeLines: true),
              ],
            )
          else if (_releaseError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _releaseError!,
                    style: TextStyle(fontSize: 12, color: colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: _loadReleases,
                  child: Text(_t('retry', 'Retry')),
                ),
              ],
            )
          else if (groups.isEmpty && _releaseCommits.isEmpty)
            Text(
              _t(
                'project_deploy_no_releases',
                'No releases detected on main yet.',
              ),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            )
          else if (groups.isEmpty)
            Column(
              children: _releaseCommits.take(8).map((c) {
                final title = c.message.split('\n').first.trim();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    title.isEmpty
                        ? _t('project_deploy_no_message', '(no message)')
                        : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${c.sha.substring(0, 7)} • ${_formatTimeAgo(c.authoredAt)}',
                  ),
                );
              }).toList(),
            )
          else
            Column(
              children: groups.map((group) {
                final mergeTitle = group.merge.message.split('\n').first.trim();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mergeTitle.isEmpty
                            ? _t(
                                'project_deploy_merge_into_main',
                                'Merge into main',
                              )
                            : mergeTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.merge.sha.substring(0, 7)} • ${group.merge.authorName.isEmpty ? _t('project_deploy_unknown', 'unknown') : group.merge.authorName} • ${_formatTimeAgo(group.merge.authoredAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (group.items.isEmpty)
                        Text(
                          _t(
                            'project_deploy_no_change_commits',
                            'No change commits between adjacent releases.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Column(
                          children: group.items.take(8).map((item) {
                            final itemTitle = item.message
                                .split('\n')
                                .first
                                .trim();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      itemTitle.isEmpty
                                          ? _t(
                                              'project_deploy_no_message',
                                              '(no message)',
                                            )
                                          : itemTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.sha.substring(0, 7),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
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
            style:
                theme.textTheme.labelSmall?.copyWith(
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
                _t(
                  'project_deploy_history_empty',
                  'No deployments yet — deploy your project to see history here.',
                ),
                style:
                    theme.textTheme.bodyMedium?.copyWith(
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
                        bottom: entry.key == _deployments.length - 1 ? 0 : 12,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('project_deploy_history_title', 'Deployment History'),
                      style:
                          theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ) ??
                          const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        'project_deploy_history_hint',
                        'Review recent deploy outcomes, open logs, and roll back specific commits when needed.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              countPill,
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                _t('project_deploy_history', 'History'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<_DeploymentEnvFilter>(
                value: _envFilter,
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _envFilter = v);
                  await _loadDeployments();
                },
                items: [
                  DropdownMenuItem(
                    value: _DeploymentEnvFilter.all,
                    child: Text(_t('project_deploy_filter_all', 'All')),
                  ),
                  DropdownMenuItem(
                    value: _DeploymentEnvFilter.dev,
                    child: Text(_t('project_deploy_filter_preview', 'Preview')),
                  ),
                  DropdownMenuItem(
                    value: _DeploymentEnvFilter.prod,
                    child: Text(
                      _t('project_deploy_filter_production', 'Production'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: _t('refresh', 'Refresh'),
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
          const SizedBox(height: 8),
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
                          style:
                              theme.textTheme.bodyMedium?.copyWith(
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
                          label: Text(_t('project_deploy_open', 'Open')),
                        ),
                      if (deployment.vercelDeploymentId != null &&
                          deployment.vercelDeploymentId!.trim().isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _openLog(deployment),
                          icon: const Icon(Icons.subject, size: 16),
                          label: Text(_t('project_deploy_logs', 'Logs')),
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
        title: _t('project_deploy_no_logs', 'No logs'),
        message: _t(
          'project_deploy_no_logs_message',
          'This deployment has no Vercel deployment id.',
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeploymentLogScreen(
          vercelDeploymentId: id,
          title: _t(
            'project_deploy_logs_title',
            '{env} logs',
          ).replaceAll('{env}', deployment.environmentLabel),
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
    final canRevert =
        deployment.primaryCommitSha != null &&
        deployment.primaryCommitSha!.trim().isNotEmpty;

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
                  _t(
                    'project_deploy_environment_deployment',
                    '{env} deployment',
                  ).replaceAll('{env}', deployment.environmentLabel),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${deployment.statusLabel} • ${deployment.id}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (deployment.statusMessage != null &&
                    deployment.statusMessage!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      deployment.statusMessage!.trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: canOpenUrl ? () => _openUrl(url) : null,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(_t('project_deploy_open', 'Open')),
                    ),
                    OutlinedButton.icon(
                      onPressed: canViewLogs
                          ? () {
                              Navigator.of(context).pop();
                              _openLog(deployment);
                            }
                          : null,
                      icon: const Icon(Icons.subject),
                      label: Text(
                        _t('project_deploy_build_logs', 'Build logs'),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: (canRevert && !_revertingCommit)
                          ? () {
                              Navigator.of(context).pop();
                              _confirmRevertDeployment(deployment);
                            }
                          : null,
                      icon: _revertingCommit
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.rotate_left),
                      label: Text(
                        _revertingCommit &&
                                _revertingCommitSha ==
                                    deployment.primaryCommitSha?.trim()
                            ? _t('project_deploy_reverting', 'Reverting...')
                            : _t(
                                'project_deploy_revert_preview',
                                'Revert + Preview',
                              ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onAskAi == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              final question = _t(
                                'project_deploy_ai_prompt_environment',
                                'Can you provide insights and recommendations about the {env} deployment, including performance optimization, troubleshooting, and best practices?',
                              ).replaceAll('{env}', deployment.environmentLabel);
                              widget.onAskAi?.call(question);
                            },
                      icon: const Icon(Icons.smart_toy),
                      label: Text(_t('project_deploy_ask_ai', 'Ask AI')),
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
    final normalized = _normalizeHttpUrl(url);
    final uri = normalized == null ? null : Uri.tryParse(normalized);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_deploy_open_url_failed', 'Cannot open URL'),
        message: _t(
          'project_deploy_open_url_failed_message',
          'Could not open {url}',
        ).replaceAll('{url}', uri.toString()),
      );
    }
  }
}

class _DeployInlinePill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool monospace;

  const _DeployInlinePill({
    required this.icon,
    required this.text,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
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

String? _normalizeHttpUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('//')) return 'https:$value';
  return 'https://$value';
}
