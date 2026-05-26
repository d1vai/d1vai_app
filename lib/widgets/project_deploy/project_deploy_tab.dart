import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/deployment.dart';
import '../../models/project.dart';
import '../../services/app_analytics_service.dart';
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

class _ProjectDeployTabState extends State<ProjectDeployTab>
    with SingleTickerProviderStateMixin {
  static const double _wideWorkspaceBreakpoint = 980;
  static const double _compactWorkspaceBreakpoint = 720;

  final List<DeploymentHistory> _deployments = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _deployingPreview = false;
  bool _deployingProduction = false;
  bool _revertingCommit = false;
  String? _revertingCommitSha;
  bool _isLoadingTimeline = false;
  bool _isLoadingDiff = false;
  bool _isLoadingReleases = false;
  String? _timelineError;
  String? _releaseError;
  final List<_TimelineCommit> _timelineCommits = [];
  final List<_ReleaseCommit> _releaseCommits = [];
  final List<String> _branchOptions = [];
  _DeployWorkspaceTab _activeTab = _DeployWorkspaceTab.timeline;
  String? _selectedTimelineSha;
  _CommitDiffBundle? _selectedCommitDiff;
  int _selectedDiffFileIndex = 0;
  _DeploymentEnvFilter _envFilter = _DeploymentEnvFilter.all;
  bool _isLoadingBranches = false;
  String? _branchLoadError;
  late final AnimationController _ambientController;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  bool _isCompactWidth(double width) => width < _compactWorkspaceBreakpoint;

  String _sanitizeDisplayText(String input) {
    if (input.isEmpty) return input;
    final units = input.codeUnits;
    final buffer = StringBuffer();
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (i + 1 < units.length) {
          final next = units[i + 1];
          if (next >= 0xDC00 && next <= 0xDFFF) {
            buffer.writeCharCode(unit);
            buffer.writeCharCode(next);
            i++;
            continue;
          }
        }
        buffer.writeCharCode(0xFFFD);
        continue;
      }
      if (unit >= 0xDC00 && unit <= 0xDFFF) {
        buffer.writeCharCode(0xFFFD);
        continue;
      }
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  ButtonStyle _denseOutlinedButtonStyle(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.42)),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  ButtonStyle _denseFilledButtonStyle(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  ButtonStyle _denseTextButtonStyle(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.styleFrom(
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _copyToClipboard(String value, {required String label}) async {
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

  Future<void> _loadBranches({bool force = false}) async {
    if (_isLoadingBranches) return;
    if (!force && _branchOptions.isNotEmpty) return;

    setState(() {
      _isLoadingBranches = true;
      _branchLoadError = null;
    });

    try {
      final service = D1vaiService();
      final branches = await service.getGitHubBranches(widget.project.id);
      if (!mounted) return;
      setState(() {
        _branchOptions
          ..clear()
          ..addAll(branches);
        _isLoadingBranches = false;
        _branchLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      if (isAuthExpiredText(msg)) {
        AuthExpiryBus.trigger(
          endpoint: '/api/github-ops/${widget.project.id}/branches',
        );
        setState(() {
          _isLoadingBranches = false;
          _branchLoadError = null;
        });
        return;
      }
      setState(() {
        _isLoadingBranches = false;
        _branchLoadError = msg;
      });
      SnackBarHelper.showError(
        context,
        title: _t('failed_to_load', 'Failed to load'),
        message: msg,
      );
    }
  }

  Future<Map<String, dynamic>> _checkMergeable({
    required String baseBranch,
    required String headBranch,
  }) async {
    final service = D1vaiService();
    return service.checkGitHubMergeable(
      widget.project.id,
      baseBranch: baseBranch,
      headBranch: headBranch,
    );
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
    final message = _sanitizeDisplayText(
      (raw['message'] ?? '').toString().trim(),
    );
    final author = raw['author'];
    final authorName = author is Map
        ? _sanitizeDisplayText((author['name'] ?? '').toString().trim())
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
    final message = _sanitizeDisplayText(
      (raw['message'] ?? '').toString().trim(),
    );
    final author = raw['author'];
    final authorName = author is Map
        ? _sanitizeDisplayText((author['name'] ?? '').toString().trim())
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
    final message = _sanitizeDisplayText(
      (raw['message'] ?? '').toString().trim(),
    );
    final stats = raw['stats'];
    final statsMap = stats is Map ? stats : const <String, dynamic>{};
    final filesRaw = raw['files'];
    final files = filesRaw is List
        ? filesRaw
              .whereType<Map>()
              .map(
                (file) => _CommitDiffFile(
                  filename: _sanitizeDisplayText(
                    (file['filename'] ?? '').toString(),
                  ),
                  status: _sanitizeDisplayText(
                    (file['status'] ?? 'modified').toString(),
                  ),
                  additions:
                      int.tryParse((file['additions'] ?? 0).toString()) ?? 0,
                  deletions:
                      int.tryParse((file['deletions'] ?? 0).toString()) ?? 0,
                  changes: int.tryParse((file['changes'] ?? 0).toString()) ?? 0,
                  patch: file['patch'] == null
                      ? null
                      : _sanitizeDisplayText(file['patch'].toString()),
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
      unawaited(
        AppAnalyticsService.instance.trackDeployPreview(widget.project.id),
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
    setState(() => _deployingProduction = true);
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
        await service.mergeGitHubBranches(
          widget.project.id,
          baseBranch: baseBranch,
          headBranch: headBranch,
          commitMessage: 'Merge $headBranch into $baseBranch',
        );
      }

      if (!mounted) return;
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
      unawaited(
        AppAnalyticsService.instance.trackDeployProduction(widget.project.id),
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
        setState(() => _deployingProduction = false);
      }
    }
  }

  List<String> _mergeBranchOptions() {
    final ordered = <String>[];
    void add(String? value) {
      final branch = (value ?? '').trim();
      if (branch.isEmpty || ordered.contains(branch)) return;
      ordered.add(branch);
    }

    add(_resolveDevBranch());
    add(_resolveMainBranch());
    for (final branch in _branchOptions) {
      add(branch);
    }
    return ordered;
  }

  String _preferredHeadBranch(List<String> branches, String baseBranch) {
    final preferred = _resolveDevBranch();
    if (preferred != baseBranch && branches.contains(preferred)) {
      return preferred;
    }
    return branches.firstWhere(
      (branch) => branch != baseBranch,
      orElse: () => preferred,
    );
  }

  String _preferredBaseBranch(List<String> branches, String headBranch) {
    final preferred = _resolveMainBranch();
    if (preferred != headBranch && branches.contains(preferred)) {
      return preferred;
    }
    return branches.firstWhere(
      (branch) => branch != headBranch,
      orElse: () => preferred,
    );
  }

  Future<void> _openBranchMergeDialog() async {
    await _loadBranches();
    if (!mounted) return;

    List<String> dialogBranches = _mergeBranchOptions();
    if (dialogBranches.length < 2) {
      SnackBarHelper.showInfo(
        context,
        title: _t('project_deploy_merge_into_main', 'Merge branches'),
        message: 'At least two branches are required before merging.',
      );
      return;
    }

    var headBranch = _preferredHeadBranch(dialogBranches, _resolveMainBranch());
    var baseBranch = _preferredBaseBranch(dialogBranches, headBranch);
    var checkMsg = '';
    var checking = false;
    var merging = false;
    bool? mergeable;
    var bootstrapped = false;
    var requestSerial = 0;

    Future<void> runCheck(StateSetter setDialog) async {
      requestSerial += 1;
      final currentRequest = requestSerial;
      if (headBranch == baseBranch) {
        setDialog(() {
          checking = false;
          mergeable = false;
          checkMsg = 'Source and target branches must be different.';
        });
        return;
      }

      setDialog(() {
        checking = true;
        mergeable = null;
        checkMsg = 'Checking mergeability...';
      });

      try {
        final result = await _checkMergeable(
          baseBranch: baseBranch,
          headBranch: headBranch,
        );
        if (!mounted || currentRequest != requestSerial) return;
        final nextMergeable = result['mergeable'] == true;
        final message = (result['message'] ?? '').toString().trim();
        setDialog(() {
          checking = false;
          mergeable = nextMergeable;
          checkMsg = message.isNotEmpty
              ? message
              : nextMergeable
              ? 'No conflicts detected.'
              : 'Conflicts detected.';
        });
      } catch (e) {
        if (!mounted || currentRequest != requestSerial) return;
        final msg = humanizeError(e);
        if (isAuthExpiredText(msg)) {
          AuthExpiryBus.trigger(
            endpoint: '/api/github-ops/${widget.project.id}/merge-check',
          );
          return;
        }
        setDialog(() {
          checking = false;
          mergeable = null;
          checkMsg = msg;
        });
      }
    }

    Future<void> refreshBranches(StateSetter setDialog) async {
      await _loadBranches(force: true);
      if (!mounted) return;
      dialogBranches = _mergeBranchOptions();
      if (!dialogBranches.contains(headBranch) || headBranch == baseBranch) {
        headBranch = _preferredHeadBranch(dialogBranches, baseBranch);
      }
      if (!dialogBranches.contains(baseBranch) || baseBranch == headBranch) {
        baseBranch = _preferredBaseBranch(dialogBranches, headBranch);
      }
      setDialog(() {
        checkMsg = '';
        mergeable = null;
      });
      await runCheck(setDialog);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;
        return StatefulBuilder(
          builder: (dialogContext, setDialog) {
            if (!bootstrapped) {
              bootstrapped = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                unawaited(runCheck(setDialog));
              });
            }

            final statusColor = switch (mergeable) {
              true => Colors.green,
              false => cs.error,
              null => cs.onSurfaceVariant,
            };

            Future<void> submitMerge() async {
              if (merging || mergeable != true) return;
              setDialog(() {
                merging = true;
              });

              try {
                final service = D1vaiService();
                await service.mergeGitHubBranches(
                  widget.project.id,
                  baseBranch: baseBranch,
                  headBranch: headBranch,
                  commitMessage: 'Merge $headBranch into $baseBranch',
                );
                if (!dialogContext.mounted) return;
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                if (!mounted) return;
                SnackBarHelper.showSuccess(
                  context,
                  title: 'Branches merged',
                  message: 'Merged $headBranch into $baseBranch',
                );
                setState(() {
                  _activeTab = _DeployWorkspaceTab.releases;
                });
                await widget.onRefreshProject?.call();
                await _loadTimeline();
                await _loadReleases();
                await _loadDeployments();
              } catch (e) {
                if (!mounted) return;
                final msg = humanizeError(e);
                if (isAuthExpiredText(msg)) {
                  AuthExpiryBus.trigger(
                    endpoint: '/api/github-ops/${widget.project.id}/merge',
                  );
                  return;
                }
                setDialog(() {
                  merging = false;
                });
                SnackBarHelper.showError(
                  context,
                  title: 'Merge failed',
                  message: msg,
                );
              }
            }

            return AlertDialog(
              title: Text(
                _t('project_deploy_merge_into_main', 'Merge branches'),
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose the source branch to merge and the target branch to receive the changes.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'head-$headBranch-${dialogBranches.length}',
                      ),
                      initialValue: headBranch,
                      decoration: const InputDecoration(
                        labelText: 'Source branch',
                        border: OutlineInputBorder(),
                      ),
                      items: dialogBranches
                          .map(
                            (branch) => DropdownMenuItem<String>(
                              value: branch,
                              child: Text(branch),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: checking || merging
                          ? null
                          : (value) {
                              if (value == null || value == headBranch) return;
                              setDialog(() {
                                headBranch = value;
                                if (headBranch == baseBranch) {
                                  baseBranch = _preferredBaseBranch(
                                    dialogBranches,
                                    headBranch,
                                  );
                                }
                              });
                              unawaited(runCheck(setDialog));
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'base-$baseBranch-${dialogBranches.length}',
                      ),
                      initialValue: baseBranch,
                      decoration: const InputDecoration(
                        labelText: 'Target branch',
                        border: OutlineInputBorder(),
                      ),
                      items: dialogBranches
                          .map(
                            (branch) => DropdownMenuItem<String>(
                              value: branch,
                              child: Text(branch),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: checking || merging
                          ? null
                          : (value) {
                              if (value == null || value == baseBranch) return;
                              setDialog(() {
                                baseBranch = value;
                                if (baseBranch == headBranch) {
                                  headBranch = _preferredHeadBranch(
                                    dialogBranches,
                                    baseBranch,
                                  );
                                }
                              });
                              unawaited(runCheck(setDialog));
                            },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            checking
                                ? Icons.sync_rounded
                                : mergeable == true
                                ? Icons.check_circle_outline
                                : mergeable == false
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline_rounded,
                            size: 18,
                            color: statusColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              checkMsg.isEmpty
                                  ? 'Select branches to check mergeability.'
                                  : checkMsg,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: checking || merging
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(_t('cancel', 'Cancel')),
                ),
                TextButton.icon(
                  onPressed: _isLoadingBranches || checking || merging
                      ? null
                      : () => unawaited(refreshBranches(setDialog)),
                  icon: _isLoadingBranches
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_t('refresh', 'Refresh')),
                ),
                FilledButton.icon(
                  onPressed: mergeable == true && !checking && !merging
                      ? () => unawaited(submitMerge())
                      : null,
                  icon: merging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.call_merge_rounded, size: 16),
                  label: Text(merging ? 'Merging...' : 'Merge'),
                ),
              ],
            );
          },
        );
      },
    );
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
          final isWide = constraints.maxWidth >= _wideWorkspaceBreakpoint;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWorkspaceHeader(
                  project,
                  isCompact: _isCompactWidth(constraints.maxWidth),
                ),
                const SizedBox(height: 12),
                _buildWorkspaceTabs(
                  isCompact: _isCompactWidth(constraints.maxWidth),
                ),
                const SizedBox(height: 12),
                _buildWorkspaceBody(
                  project,
                  isWide: isWide,
                  isCompact: _isCompactWidth(constraints.maxWidth),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceTabs({required bool isCompact}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget tab(_DeployWorkspaceTab value, IconData icon, String label) {
      final active = _activeTab == value;
      final tabChild = InkWell(
        borderRadius: BorderRadius.circular(9),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? Color.alphaBlend(
                    cs.primary.withValues(alpha: 0.14),
                    cs.surface,
                  )
                : cs.surface.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? cs.primary.withValues(alpha: 0.24)
                  : cs.outlineVariant.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 11.5,
                    color: active ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (isCompact) {
        return tabChild;
      }

      return Expanded(child: tabChild);
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerLow.withValues(alpha: 0.72),
          cs.surface,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: isCompact
          ? Column(
              children: [
                tab(
                  _DeployWorkspaceTab.timeline,
                  Icons.timeline_rounded,
                  _t('project_deploy_tab_timeline', 'Timeline'),
                ),
                const SizedBox(height: 8),
                tab(
                  _DeployWorkspaceTab.deployments,
                  Icons.rocket_launch_outlined,
                  _t('project_deployment_tab_deployments', 'Deployments'),
                ),
                const SizedBox(height: 8),
                tab(
                  _DeployWorkspaceTab.releases,
                  Icons.inventory_2_outlined,
                  _t('project_deploy_releases', 'Releases'),
                ),
              ],
            )
          : Row(
              children: [
                tab(
                  _DeployWorkspaceTab.timeline,
                  Icons.timeline_rounded,
                  _t('project_deploy_tab_timeline', 'Timeline'),
                ),
                const SizedBox(width: 8),
                tab(
                  _DeployWorkspaceTab.deployments,
                  Icons.rocket_launch_outlined,
                  _t('project_deployment_tab_deployments', 'Deployments'),
                ),
                const SizedBox(width: 8),
                tab(
                  _DeployWorkspaceTab.releases,
                  Icons.inventory_2_outlined,
                  _t('project_deploy_releases', 'Releases'),
                ),
              ],
            ),
    );
  }

  Widget _buildWorkspaceHeader(UserProject project, {required bool isCompact}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final devBranch = _resolveDevBranch();
    final mainBranch = _resolveMainBranch();
    final previewUrl = _normalizeHttpUrl(project.preferredPreviewUrl);
    final prodUrl = _normalizeHttpUrl(
      project.latestProdDeploymentUrl ?? project.vercelProdDomain,
    );

    Widget pill(
      IconData icon,
      String text, {
      Color? tone,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      String? tooltip,
    }) {
      return _DeployInlinePill(
        icon: icon,
        text: text,
        tone: tone,
        onTap: onTap,
        onLongPress: onLongPress,
        tooltip: tooltip,
      );
    }

    return CustomCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isCompact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact)
                Expanded(child: _buildWorkspaceHeaderIntro(theme, cs)),
              if (isCompact) _buildWorkspaceHeaderIntro(theme, cs),
              SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 12 : 0),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  pill(
                    Icons.fork_right_rounded,
                    devBranch,
                    onTap: () =>
                        unawaited(_copyToClipboard(devBranch, label: 'Branch')),
                    tooltip: 'Copy workspace branch',
                  ),
                  pill(
                    Icons.outbox_rounded,
                    mainBranch,
                    tone: cs.tertiary,
                    onTap: () => unawaited(
                      _copyToClipboard(mainBranch, label: 'Branch'),
                    ),
                    tooltip: 'Copy release branch',
                  ),
                  if (prodUrl != null && prodUrl.isNotEmpty)
                    FilledButton.tonalIcon(
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
                      style: _denseFilledButtonStyle(context),
                      icon: const Icon(Icons.call_merge_rounded, size: 16),
                      label: Text(
                        _t(
                          'project_deploy_action_deploy_prod',
                          'Deploy production',
                        ),
                      ),
                    )
                  else if (previewUrl != null && previewUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _deployingPreview
                          ? null
                          : _triggerPreviewDeploy,
                      style: _denseOutlinedButtonStyle(context),
                      icon: const Icon(Icons.rocket_launch_outlined, size: 16),
                      label: Text(
                        _t(
                          'project_deploy_action_redeploy_preview',
                          'Redeploy preview',
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (previewUrl != null && previewUrl.isNotEmpty)
                pill(
                  Icons.visibility_outlined,
                  _getDeploymentLabel(previewUrl),
                  tone: cs.secondary,
                  onTap: () => unawaited(_openUrl(previewUrl)),
                  onLongPress: () => unawaited(
                    _copyToClipboard(previewUrl, label: 'Preview URL'),
                  ),
                  tooltip: 'Open preview, long press to copy URL',
                ),
              if (prodUrl != null && prodUrl.isNotEmpty)
                pill(
                  Icons.public,
                  _getDeploymentLabel(prodUrl),
                  tone: cs.primary,
                  onTap: () => unawaited(_openUrl(prodUrl)),
                  onLongPress: () => unawaited(
                    _copyToClipboard(prodUrl, label: 'Production URL'),
                  ),
                  tooltip: 'Open production, long press to copy URL',
                ),
              pill(
                Icons.history_toggle_off_rounded,
                '${_timelineCommits.length} recent commits',
                tone: cs.onSurfaceVariant,
                onTap: () =>
                    setState(() => _activeTab = _DeployWorkspaceTab.timeline),
                tooltip: 'Open commit timeline',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeaderIntro(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Release workflow',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review development commits, check branch promotion, and move safe changes to production.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceBody(
    UserProject project, {
    required bool isWide,
    required bool isCompact,
  }) {
    switch (_activeTab) {
      case _DeployWorkspaceTab.timeline:
        return _buildTimelineTab(project, isWide: isWide, isCompact: isCompact);
      case _DeployWorkspaceTab.deployments:
        return _buildDeploymentHistoryCard();
      case _DeployWorkspaceTab.releases:
        return _buildReleasesCard(project);
    }
  }

  Widget _buildBranchContextCard({required bool isCompact}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final devBranch = _resolveDevBranch();
    final mainBranch = _resolveMainBranch();

    Widget branchTile({
      required IconData icon,
      required String label,
      required String value,
      VoidCallback? onTap,
      String? tooltip,
    }) {
      final content = Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.32)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: cs.primary),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final interactive = onTap == null
          ? content
          : Tooltip(
              message: tooltip ?? value,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: onTap,
                  child: content,
                ),
              ),
            );

      if (isCompact) return interactive;
      return Expanded(child: interactive);
    }

    return CustomCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isCompact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branch release controls',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Inspect your working branch, choose any source/target pair, and run a safe merge check before releasing.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branch release controls',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Inspect your working branch, choose any source/target pair, and run a safe merge check before releasing.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 12 : 0),
              FilledButton.tonalIcon(
                onPressed: _openBranchMergeDialog,
                style: _denseFilledButtonStyle(context),
                icon: const Icon(Icons.call_merge_rounded, size: 18),
                label: const Text('Merge branches'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isCompact)
            Column(
              children: [
                branchTile(
                  icon: Icons.fork_right_rounded,
                  label: 'Workspace branch',
                  value: devBranch,
                  onTap: () =>
                      unawaited(_copyToClipboard(devBranch, label: 'Branch')),
                  tooltip: 'Copy workspace branch',
                ),
                const SizedBox(height: 12),
                branchTile(
                  icon: Icons.outbox_rounded,
                  label: 'Release branch',
                  value: mainBranch,
                  onTap: () =>
                      unawaited(_copyToClipboard(mainBranch, label: 'Branch')),
                  tooltip: 'Copy release branch',
                ),
              ],
            )
          else
            Row(
              children: [
                branchTile(
                  icon: Icons.fork_right_rounded,
                  label: 'Workspace branch',
                  value: devBranch,
                  onTap: () =>
                      unawaited(_copyToClipboard(devBranch, label: 'Branch')),
                  tooltip: 'Copy workspace branch',
                ),
                const SizedBox(width: 12),
                branchTile(
                  icon: Icons.outbox_rounded,
                  label: 'Release branch',
                  value: mainBranch,
                  onTap: () =>
                      unawaited(_copyToClipboard(mainBranch, label: 'Branch')),
                  tooltip: 'Copy release branch',
                ),
              ],
            ),
          if ((_branchLoadError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _branchLoadError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.error,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineTab(
    UserProject project, {
    required bool isWide,
    required bool isCompact,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedCommit = _timelineCommits.cast<_TimelineCommit?>().firstWhere(
      (item) => item?.sha == _selectedTimelineSha,
      orElse: () => _timelineCommits.isEmpty ? null : _timelineCommits.first,
    );
    final latestSha = _timelineCommits.isEmpty
        ? null
        : _timelineCommits.first.sha;
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
        return _InlineDeployError(
          message: _timelineError!,
          onRetry: _loadTimeline,
        );
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
                                ? _t(
                                    'project_deploy_no_message',
                                    '(no message)',
                                  )
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isCompact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact)
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
              if (isCompact)
                Column(
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
              SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 12 : 0),
              _buildTimelineActions(
                isCompact: isCompact,
                selectedCommit: selectedCommit,
                canRevert: canRevert,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBranchContextCard(isCompact: isCompact),
          const SizedBox(height: 14),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: commitRail()),
                const SizedBox(width: 14),
                Expanded(
                  flex: 7,
                  child: CustomCard(
                    padding: const EdgeInsets.all(14),
                    child: _buildTimelineDiffPanel(),
                  ),
                ),
              ],
            )
          else ...[
            commitRail(),
            const SizedBox(height: 14),
            CustomCard(
              padding: const EdgeInsets.all(14),
              child: _buildTimelineDiffPanel(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineActions({
    required bool isCompact,
    required _TimelineCommit? selectedCommit,
    required bool canRevert,
  }) {
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: _isLoadingTimeline ? null : _loadTimeline,
        style: _denseOutlinedButtonStyle(context),
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
        onPressed: _deployingPreview ? null : _triggerPreviewDeploy,
        style: _denseOutlinedButtonStyle(context),
        icon: _deployingPreview
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.rocket_launch_outlined),
        label: Text(
          _t('project_deploy_action_redeploy_preview', 'Redeploy preview'),
        ),
      ),
      OutlinedButton.icon(
        onPressed: canRevert && !_revertingCommit && selectedCommit != null
            ? () => _revertCommitAndPreviewRedeploy(selectedCommit.sha)
            : null,
        style: _denseOutlinedButtonStyle(context),
        icon: const Icon(Icons.rotate_left_rounded),
        label: Text(_t('project_deploy_revert_preview', 'Revert + Preview')),
      ),
      OutlinedButton.icon(
        onPressed: _openBranchMergeDialog,
        style: _denseOutlinedButtonStyle(context),
        icon: const Icon(Icons.merge_type_rounded),
        label: const Text('Merge branches'),
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
        style: _denseFilledButtonStyle(context),
        icon: const Icon(Icons.call_merge_rounded),
        label: Text(
          _t('project_deploy_action_deploy_prod', 'Deploy production'),
        ),
      ),
    ];

    if (!isCompact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: actions,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - 8) / 2
            : 160.0;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions
              .map(
                (action) =>
                    SizedBox(width: width.clamp(120.0, 220.0), child: action),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTimelineDiffPanel() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedFile =
        (_selectedCommitDiff != null &&
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
              onTap: () => unawaited(
                _copyToClipboard(_selectedCommitDiff!.sha, label: 'Commit SHA'),
              ),
              tooltip: 'Copy full commit SHA',
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
        const SizedBox(height: 12),
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
            height: 34,
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
                  onLongPress: () => unawaited(
                    _copyToClipboard(file.filename, label: 'File path'),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: active ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
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
          const SizedBox(height: 8),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
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
                style: IconButton.styleFrom(
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                ),
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
                    style: _denseTextButtonStyle(context),
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
                    style: _denseTextButtonStyle(context),
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                showShadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                itemHeight: 38,
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
                style: IconButton.styleFrom(
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                ),
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
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            statusColor.withValues(alpha: 0.06),
            colorScheme.surface,
          ),
          borderRadius: BorderRadius.circular(11),
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
                          style: _denseTextButtonStyle(context),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(_t('project_deploy_open', 'Open')),
                        ),
                      if (deployment.vercelDeploymentId != null &&
                          deployment.vercelDeploymentId!.trim().isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _openLog(deployment),
                          style: _denseTextButtonStyle(context),
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
      useRootNavigator: true,
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
  final Color? tone;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;

  const _DeployInlinePill({
    required this.icon,
    required this.text,
    this.monospace = false,
    this.tone,
    this.onTap,
    this.onLongPress,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = tone ?? colorScheme.onSurfaceVariant;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );

    final interactive = onTap != null || onLongPress != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              onLongPress: onLongPress,
              child: child,
            ),
          )
        : child;

    if ((tooltip ?? '').trim().isEmpty) {
      return interactive;
    }

    return Tooltip(message: tooltip, child: interactive);
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
