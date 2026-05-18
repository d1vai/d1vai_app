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
import '../compact_selector.dart';
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

enum _DeployWorkspaceTab { timeline, deployments, releases }

class _TimelineCommit {
  final String sha;
  final String message;
  final String authorName;
  final String authoredAt;

  const _TimelineCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    required this.authoredAt,
  });
}

class _CommitDiffFile {
  final String filename;
  final String status;
  final int additions;
  final int deletions;
  final int changes;
  final String? patch;

  const _CommitDiffFile({
    required this.filename,
    required this.status,
    required this.additions,
    required this.deletions,
    required this.changes,
    this.patch,
  });
}

class _CommitDiffBundle {
  final String sha;
  final String message;
  final int additions;
  final int deletions;
  final int total;
  final List<_CommitDiffFile> files;

  const _CommitDiffBundle({
    required this.sha,
    required this.message,
    required this.additions,
    required this.deletions,
    required this.total,
    required this.files,
  });
}

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
  bool _isLoadingTimeline = false;
  bool _isLoadingDiff = false;
  bool _isLoadingReleases = false;
  String? _timelineError;
  String? _releaseError;
  final List<_TimelineCommit> _timelineCommits = [];
  final List<_ReleaseCommit> _releaseCommits = [];
  _DeployWorkspaceTab _activeTab = _DeployWorkspaceTab.timeline;
  String? _selectedTimelineSha;
  _CommitDiffBundle? _selectedCommitDiff;
  int _selectedDiffFileIndex = 0;
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
      _loadTimeline();
      _loadDeployments();
      _loadReleases();
    }
  }

  @override
  void didUpdateWidget(covariant ProjectDeployTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _loadTimeline();
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

  _TimelineCommit? _parseTimelineCommit(dynamic raw) {
    if (raw is! Map) return null;
    final sha = (raw['sha'] ?? '').toString().trim();
    if (sha.isEmpty) return null;
    final message = (raw['message'] ?? '').toString().trim();
    final author = raw['author'];
    final authorName = author is Map
        ? (author['name'] ?? '').toString().trim()
        : '';
    final authoredAt = author is Map
        ? (author['date'] ?? '').toString().trim()
        : '';
    return _TimelineCommit(
      sha: sha,
      message: message.isEmpty
          ? _t('project_deploy_no_message', '(no message)')
          : message,
      authorName: authorName,
      authoredAt: authoredAt,
    );
  }

  _CommitDiffBundle? _parseCommitDiff(dynamic raw) {
    if (raw is! Map) return null;
    final sha = (raw['sha'] ?? '').toString().trim();
    if (sha.isEmpty) return null;
    final message = (raw['message'] ?? '').toString().trim();
    final stats = raw['stats'];
    final statsMap = stats is Map ? stats : const <String, dynamic>{};
    final filesRaw = raw['files'];
    final files = filesRaw is List
        ? filesRaw
              .whereType<Map>()
              .map(
                (file) => _CommitDiffFile(
                  filename: (file['filename'] ?? '').toString(),
                  status: (file['status'] ?? 'modified').toString(),
                  additions:
                      int.tryParse((file['additions'] ?? 0).toString()) ?? 0,
                  deletions:
                      int.tryParse((file['deletions'] ?? 0).toString()) ?? 0,
                  changes: int.tryParse((file['changes'] ?? 0).toString()) ?? 0,
                  patch: file['patch']?.toString(),
                ),
              )
              .toList()
        : const <_CommitDiffFile>[];

    return _CommitDiffBundle(
      sha: sha,
      message: message.isEmpty
          ? _t('project_deploy_no_message', '(no message)')
          : message,
      additions: int.tryParse((statsMap['additions'] ?? 0).toString()) ?? 0,
      deletions: int.tryParse((statsMap['deletions'] ?? 0).toString()) ?? 0,
      total: int.tryParse((statsMap['total'] ?? 0).toString()) ?? 0,
      files: files,
    );
  }

  Future<void> _loadTimeline() async {
    if (_isLoadingTimeline) return;
    setState(() {
      _isLoadingTimeline = true;
      _timelineError = null;
    });
    try {
      final service = D1vaiService();
      final commits = await service.getGitHubBranchCommits(
        widget.project.id,
        branch: _resolveDevBranch(),
        limit: 40,
      );
      final parsed = commits
          .map(_parseTimelineCommit)
          .whereType<_TimelineCommit>()
          .toList();
      if (!mounted) return;
      setState(() {
        _timelineCommits
          ..clear()
          ..addAll(parsed);
        _selectedTimelineSha = parsed.isEmpty ? null : parsed.first.sha;
        _isLoadingTimeline = false;
      });
      if (parsed.isNotEmpty) {
        await _loadCommitDiff(parsed.first.sha);
      } else if (mounted) {
        setState(() {
          _selectedCommitDiff = null;
          _selectedDiffFileIndex = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      if (isAuthExpiredText(msg)) {
        AuthExpiryBus.trigger(
          endpoint: '/api/github-ops/${widget.project.id}/commits',
        );
        setState(() {
          _isLoadingTimeline = false;
          _timelineError = null;
        });
        return;
      }
      setState(() {
        _isLoadingTimeline = false;
        _timelineError = msg;
      });
    }
  }

  Future<void> _loadCommitDiff(String sha) async {
    setState(() {
      _selectedTimelineSha = sha;
      _isLoadingDiff = true;
      _selectedCommitDiff = null;
      _selectedDiffFileIndex = 0;
    });
    try {
      final service = D1vaiService();
      final diff = await service.getGitHubCommitDiff(
        widget.project.id,
        commitSha: sha,
      );
      final parsed = _parseCommitDiff(
        diff['data'] is Map ? diff['data'] : diff,
      );
      if (!mounted) return;
      setState(() {
        _selectedCommitDiff = parsed;
        _isLoadingDiff = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      setState(() {
        _timelineError = msg;
        _isLoadingDiff = false;
      });
    }
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
        await _loadTimeline();
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
                _buildDeploySummaryStrip(project),
                const SizedBox(height: 12),
                _buildDeployControlDeck(project, isWide: isWide),
                const SizedBox(height: 16),
                _buildWorkspaceTabs(),
                const SizedBox(height: 14),
                _buildWorkspaceBody(project, isWide: isWide),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceTabs() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget tab(_DeployWorkspaceTab value, IconData icon, String label) {
      final active = _activeTab == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            setState(() => _activeTab = value);
            if (value == _DeployWorkspaceTab.timeline &&
                _timelineCommits.isEmpty &&
                !_isLoadingTimeline) {
              await _loadTimeline();
            } else if (value == _DeployWorkspaceTab.deployments &&
                _deployments.isEmpty &&
                !_isLoading) {
              await _loadDeployments();
            } else if (value == _DeployWorkspaceTab.releases &&
                _releaseCommits.isEmpty &&
                !_isLoadingReleases) {
              await _loadReleases();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? Color.alphaBlend(
                      cs.primary.withValues(alpha: 0.14),
                      cs.surface,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? cs.primary.withValues(alpha: 0.24)
                    : cs.outlineVariant.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: active ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(
          _DeployWorkspaceTab.timeline,
          Icons.timeline_rounded,
          _t('project_deploy_tab_timeline', 'Timeline'),
        ),
        const SizedBox(width: 10),
        tab(
          _DeployWorkspaceTab.deployments,
          Icons.rocket_launch_outlined,
          _t('project_deployment_tab_deployments', 'Deployments'),
        ),
        const SizedBox(width: 10),
        tab(
          _DeployWorkspaceTab.releases,
          Icons.inventory_2_outlined,
          _t('project_deploy_releases', 'Releases'),
        ),
      ],
    );
  }

  Widget _buildWorkspaceBody(UserProject project, {required bool isWide}) {
    switch (_activeTab) {
      case _DeployWorkspaceTab.timeline:
        return _buildTimelineTab(project, isWide: isWide);
      case _DeployWorkspaceTab.deployments:
        return _buildDeploymentHistoryCard();
      case _DeployWorkspaceTab.releases:
        return _buildReleasesCard(project);
    }
  }

  Widget _buildTimelineTab(UserProject project, {required bool isWide}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedCommit = _timelineCommits.cast<_TimelineCommit?>().firstWhere(
      (item) => item?.sha == _selectedTimelineSha,
      orElse: () => _timelineCommits.isEmpty ? null : _timelineCommits.first,
    );
    final latestSha = _timelineCommits.isEmpty ? null : _timelineCommits.first.sha;
    final canRevert = selectedCommit != null && selectedCommit.sha != latestSha;

    Widget commitRail() {
      if (_isLoadingTimeline) {
        return const Column(
          children: [
            SkeletonListTile(hasLeading: false, hasThreeLines: true),
            SizedBox(height: 8),
            SkeletonListTile(hasLeading: false, hasThreeLines: true),
            SizedBox(height: 8),
            SkeletonListTile(hasLeading: false, hasThreeLines: true),
          ],
        );
      }
      if (_timelineError != null) {
        return _InlineDeployError(message: _timelineError!, onRetry: _loadTimeline);
      }
      if (_timelineCommits.isEmpty) {
        return _EmptyDeployState(
          icon: Icons.timeline_rounded,
          title: _t('project_deploy_no_timeline', 'No timeline yet'),
          message: _t(
            'project_deploy_no_timeline_hint',
            'No recent commits found on the development branch.',
          ),
        );
      }
      return Column(
        children: _timelineCommits.asMap().entries.map((entry) {
          final commit = entry.value;
          final active = commit.sha == _selectedTimelineSha;
          final title = commit.message.split('\n').first.trim();
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == _timelineCommits.length - 1 ? 0 : 10,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _loadCommitDiff(commit.sha),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active
                      ? Color.alphaBlend(
                          cs.primary.withValues(alpha: 0.12),
                          cs.surface,
                        )
                      : cs.surfaceContainerLow.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? cs.primary.withValues(alpha: 0.24)
                        : cs.outlineVariant.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: active ? cs.primary : cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (title.isNotEmpty ? title.substring(0, 1) : '•')
                              .toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: active ? cs.onPrimary : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty
                                ? _t('project_deploy_no_message', '(no message)')
                                : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${commit.sha.substring(0, 7)} • ${commit.authorName.isEmpty ? _t('project_deploy_unknown', 'unknown') : commit.authorName} • ${_formatTimeAgo(commit.authoredAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return CustomCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('project_deploy_dev_timeline', 'Dev Timeline'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        'project_deploy_dev_timeline_hint',
                        'Inspect recent commits on the dev branch before you promote them to production.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoadingTimeline ? null : _loadTimeline,
                    icon: _isLoadingTimeline
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(_t('refresh', 'Refresh')),
                  ),
                  OutlinedButton.icon(
                    onPressed: canRevert && !_revertingCommit
                        ? () => _revertCommitAndPreviewRedeploy(selectedCommit.sha)
                        : null,
                    icon: const Icon(Icons.rotate_left_rounded),
                    label: Text(_t('project_deploy_revert_preview', 'Revert + Preview')),
                  ),
                  FilledButton.icon(
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
                    icon: const Icon(Icons.call_merge_rounded),
                    label: Text(
                      _t('project_deploy_action_deploy_prod', 'Deploy production'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: commitRail()),
                const SizedBox(width: 16),
                Expanded(
                  flex: 7,
                  child: CustomCard(
                    padding: const EdgeInsets.all(16),
                    child: _buildTimelineDiffPanel(),
                  ),
                ),
              ],
            )
          else ...[
            commitRail(),
            const SizedBox(height: 16),
            CustomCard(
              padding: const EdgeInsets.all(16),
              child: _buildTimelineDiffPanel(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineDiffPanel() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedFile = (_selectedCommitDiff != null &&
            _selectedCommitDiff!.files.isNotEmpty &&
            _selectedDiffFileIndex >= 0 &&
            _selectedDiffFileIndex < _selectedCommitDiff!.files.length)
        ? _selectedCommitDiff!.files[_selectedDiffFileIndex]
        : null;

    if (_isLoadingDiff) {
      return const Column(
        children: [
          SkeletonListTile(hasLeading: false, hasThreeLines: true),
          SizedBox(height: 8),
          SkeletonListTile(hasLeading: false, hasThreeLines: true),
        ],
      );
    }
    if (_selectedCommitDiff == null) {
      return _EmptyDeployState(
        icon: Icons.difference_outlined,
        title: _t('project_deploy_select_commit', 'Select a commit'),
        message: _t(
          'project_deploy_select_commit_hint',
          'Choose a commit on the left to inspect changed files and patches.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedCommitDiff!.message.split('\n').first.trim(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DeployInlinePill(
              icon: Icons.commit,
              text: _selectedCommitDiff!.sha.substring(0, 7),
              monospace: true,
            ),
            _DeployInlinePill(
              icon: Icons.add,
              text: '+${_selectedCommitDiff!.additions}',
            ),
            _DeployInlinePill(
              icon: Icons.remove,
              text: '-${_selectedCommitDiff!.deletions}',
            ),
            _DeployInlinePill(
              icon: Icons.article_outlined,
              text: '${_selectedCommitDiff!.files.length} files',
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_selectedCommitDiff!.files.isEmpty)
          _EmptyDeployState(
            icon: Icons.insert_drive_file_outlined,
            title: _t('project_deploy_no_diff_files', 'No file diff'),
            message: _t(
              'project_deploy_no_diff_files_hint',
              'This commit did not return any changed file patches.',
            ),
          )
        else ...[
          SizedBox(
            height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedCommitDiff!.files.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                final file = _selectedCommitDiff!.files[index];
                final active = index == _selectedDiffFileIndex;
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => _selectedDiffFileIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? cs.primary.withValues(alpha: 0.14)
                          : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active
                            ? cs.primary.withValues(alpha: 0.24)
                            : cs.outlineVariant.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      file.filename.split('/').last,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildPatchViewer(selectedFile),
        ],
      ],
    );
  }

  Widget _buildPatchViewer(_CommitDiffFile? file) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (file == null) return const SizedBox.shrink();
    final patch = (file.patch ?? '').trim();
    if (patch.isEmpty) {
      return _EmptyDeployState(
        icon: Icons.notes_outlined,
        title: file.filename,
        message: _t(
          'project_deploy_patch_unavailable',
          'Patch preview is unavailable for this file.',
        ),
      );
    }
    final lines = patch.split('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.filename,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((line) {
                  Color? bg;
                  Color fg = cs.onSurfaceVariant;
                  if (line.startsWith('+') && !line.startsWith('+++')) {
                    bg = Colors.green.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.08,
                    );
                    fg = theme.brightness == Brightness.dark
                        ? Colors.green.shade200
                        : Colors.green.shade800;
                  } else if (line.startsWith('-') && !line.startsWith('---')) {
                    bg = Colors.red.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.08,
                    );
                    fg = theme.brightness == Brightness.dark
                        ? Colors.red.shade200
                        : Colors.red.shade800;
                  } else if (line.startsWith('@@')) {
                    bg = cs.primary.withValues(alpha: 0.10);
                    fg = cs.primary;
                  }
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11.8,
                        height: 1.32,
                        color: fg,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeploySummaryStrip(UserProject project) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previewReady = (project.preferredPreviewUrl ?? '').trim().isNotEmpty;
    final prodReady = (project.latestProdDeploymentUrl ?? '').trim().isNotEmpty;
    final activeFlow = _activeFlowHint();

    Widget item(String label, String value, {bool mono = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        item(
          _t('project_deploy_control_title', 'Release control'),
          activeFlow ??
              _t('project_deploy_idle_short', 'Ready for next deployment'),
        ),
        item(
          _t('project_deploy_filter_preview', 'Preview'),
          previewReady ? 'Ready' : 'Missing',
        ),
        item(
          _t('project_deploy_filter_production', 'Production'),
          prodReady ? 'Live' : 'Not live',
        ),
        item(
          _t('project_deploy_branch', 'Branch'),
          _resolveDevBranch(),
          mono: true,
        ),
        item(
          _t('project_deploy_release_branch', 'Release'),
          _resolveMainBranch(),
          mono: true,
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('project_deploy_control_title', 'Release control'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 6),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Text(
            _t('project_deploy_troubleshooting', 'Failure triage'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('project_deploy_current_deployments', 'Current Deployments'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
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
              CompactSelector(
                value: _envFilter.name,
                minWidth: 96,
                maxWidth: 138,
                placeholder: _t('project_deploy_filter_all', 'All'),
                options: [
                  CompactSelectorOption(
                    value: _DeploymentEnvFilter.all.name,
                    label: _t('project_deploy_filter_all', 'All'),
                  ),
                  CompactSelectorOption(
                    value: _DeploymentEnvFilter.dev.name,
                    label: _t('project_deploy_filter_preview', 'Preview'),
                  ),
                  CompactSelectorOption(
                    value: _DeploymentEnvFilter.prod.name,
                    label: _t('project_deploy_filter_production', 'Production'),
                  ),
                ],
                onChanged: (value) async {
                  final next = _DeploymentEnvFilter.values.firstWhere(
                    (item) => item.name == value,
                    orElse: () => _DeploymentEnvFilter.all,
                  );
                  setState(() => _envFilter = next);
                  await _loadDeployments();
                },
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

class _EmptyDeployState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyDeployState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineDeployError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _InlineDeployError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.error,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
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
