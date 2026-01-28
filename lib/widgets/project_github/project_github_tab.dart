import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../create_project_dialog/github_import/github_import_utils.dart';
import '../snackbar_helper.dart';

/// 项目详情页 - GitHub Tab
///
/// Note: current backend API focuses on "import" flows + github-ops. This tab
/// provides a practical "import/verify/accept" loop, instead of a placeholder.
class ProjectGithubTab extends StatefulWidget {
  final UserProject project;

  const ProjectGithubTab({super.key, required this.project});

  @override
  State<ProjectGithubTab> createState() => _ProjectGithubTabState();
}

class _ProjectGithubTabState extends State<ProjectGithubTab> {
  final _service = D1vaiService();
  bool _loading = false;
  String _botUsername = '…';
  String _error = '';

  final TextEditingController _repoUrlController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();

  bool _invitationAccepted = false;
  bool _accessVerified = false;
  Map<String, dynamic>? _repoInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBotUsername());
  }

  @override
  void dispose() {
    _repoUrlController.dispose();
    _projectNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBotUsername() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await _service.getGitHubBotUsername();
      final username =
          (res['username'] ?? res['bot_username'] ?? res['data'] ?? 'd1vai-bot')
              .toString()
              .trim();
      if (!mounted) return;
      setState(() {
        _botUsername = username.isEmpty ? 'd1vai-bot' : username;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _botUsername = 'd1vai-bot';
        _error = 'Failed to load bot username: ${humanizeError(e)}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _repoFullName() => parseGithubRepoFullName(_repoUrlController.text);

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    SnackBarHelper.showSuccess(context, title: 'Copied', message: label);
  }

  Future<void> _copyBotUsername() async {
    await Clipboard.setData(ClipboardData(text: _botUsername));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Copied',
      message: _botUsername,
    );
  }

  Future<void> _acceptInvitation() async {
    final full = _repoFullName();
    if (full == null) {
      setState(() => _error = 'Invalid repo URL');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _service.acceptGitHubInvitation(full);
      if (!mounted) return;
      setState(() {
        _invitationAccepted = true;
      });
      SnackBarHelper.showSuccess(
        context,
        title: 'Invitation',
        message: 'Accepted for $full',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Accept invitation failed: ${humanizeError(e)}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyAccess() async {
    final full = _repoFullName();
    if (full == null) {
      setState(() => _error = 'Invalid repo URL');
      return;
    }
    final parts = full.split('/');
    setState(() {
      _loading = true;
      _error = '';
      _accessVerified = false;
      _repoInfo = null;
    });
    try {
      final res = await _service.checkRepositoryAccess(parts[0], parts[1]);
      if (!mounted) return;
      setState(() {
        _repoInfo = res;
        _accessVerified = true;
        if (_projectNameController.text.trim().isEmpty) {
          _projectNameController.text =
              (res['repository_name'] ?? parts[1]).toString();
        }
      });
      SnackBarHelper.showSuccess(
        context,
        title: 'Access',
        message: 'Verified for $full',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Verify access failed: ${humanizeError(e)}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importProject() async {
    final full = _repoFullName();
    final repoInfo = _repoInfo;
    if (full == null || repoInfo == null) return;

    final projectName =
        _projectNameController.text.trim().isNotEmpty
            ? _projectNameController.text.trim()
            : (repoInfo['repository_name']?.toString().isNotEmpty ?? false)
            ? repoInfo['repository_name'].toString()
            : full.split('/')[1];

    final payload = <String, dynamic>{
      'repository_full_name': full,
      'project_name': projectName,
      'project_description':
          (repoInfo['description']?.toString().trim().isNotEmpty ?? false)
              ? repoInfo['description'].toString()
              : 'Imported from GitHub: $full',
      'repository_url': repoInfo['clone_url'],
      'repository_ssh_url': repoInfo['ssh_url'],
      'default_branch': repoInfo['default_branch'] ?? 'main',
      'is_private': repoInfo['is_private'] ?? false,
      'primary_language': repoInfo['language'],
    };

    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await _service.importProjectFromGithub(payload);
      if (!mounted) return;
      final normalized = normalizeImportedProject(res);
      final projectId = normalized.projectId;
      if (projectId == null || projectId.isEmpty) {
        throw Exception('Import succeeded but missing project id');
      }

      final provider = Provider.of<ProjectProvider>(context, listen: false);
      await provider.refresh();

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Imported',
        message: projectName,
      );
      context.go('/projects/$projectId');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Import failed: ${humanizeError(e)}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repoFullName = _repoFullName();
    final canGoStep2 = repoFullName != null;
    final canGoStep3 = _accessVerified && _repoInfo != null;

    final boundRepo = (widget.project.repositoryFullName ?? '').trim();
    final boundBranch =
        (widget.project.repositoryCurrentBranch ??
                widget.project.repositoryDefaultBranch ??
                '')
            .trim();
    final workspaceBranch = (widget.project.workspaceCurrentBranch ?? '').trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (boundRepo.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.link,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Connected Repository',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy repo',
                          onPressed: () => _copyText('Repo', boundRepo),
                          icon: const Icon(Icons.copy, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Open on GitHub',
                          onPressed: () => _openExternalUrl(
                            'https://github.com/$boundRepo',
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      boundRepo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.project.repositoryIsPrivate != null)
                          _Tag(
                            text: widget.project.repositoryIsPrivate == true
                                ? 'private'
                                : 'public',
                          ),
                        if (boundBranch.isNotEmpty) _Tag(text: 'repo: $boundBranch'),
                        if (workspaceBranch.isNotEmpty)
                          _Tag(text: 'workspace: $workspaceBranch'),
                        if ((widget.project.repositoryPlatform ?? '').trim().isNotEmpty)
                          _Tag(text: (widget.project.repositoryPlatform ?? '').trim()),
                      ],
                    ),
                    if ((widget.project.opcodeLastAccessedAt ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Last workspace sync: ${widget.project.opcodeLastAccessedAt}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if ((widget.project.repositoryCloneUrl ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Clone URL',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy clone URL',
                              onPressed: () => _copyText(
                                'Clone URL',
                                widget.project.repositoryCloneUrl!.trim(),
                              ),
                              icon: const Icon(Icons.copy, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.smart_toy,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'GitHub Import',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_loading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_error.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.error),
                      ),
                      child: Text(
                        _error,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'GitHub bot',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _botUsername,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copy',
                          onPressed: _copyBotUsername,
                          icon: const Icon(Icons.copy, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _repoUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Repository URL',
                      hintText: 'https://github.com/owner/repo',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() {
                        _invitationAccepted = false;
                        _accessVerified = false;
                        _repoInfo = null;
                        _error = '';
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading || !canGoStep2
                              ? null
                              : _acceptInvitation,
                          icon: const Icon(Icons.mail, size: 18),
                          label: Text(
                            _invitationAccepted ? 'Invitation accepted' : 'Accept invitation',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading || !canGoStep2 ? null : _verifyAccess,
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Verify access', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_repoInfo != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_repoInfo!['repository_name'] ?? repoFullName ?? '')
                                .toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (_repoInfo!['description'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Tag(
                                text: 'branch: ${_repoInfo!['default_branch'] ?? 'main'}',
                              ),
                              _Tag(
                                text: (_repoInfo!['is_private'] == true)
                                    ? 'private'
                                    : 'public',
                              ),
                              if ((_repoInfo!['language'] ?? '').toString().trim().isNotEmpty)
                                _Tag(text: (_repoInfo!['language'] ?? '').toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _projectNameController,
                      decoration: const InputDecoration(
                        labelText: 'Project name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading || !canGoStep3 ? null : _importProject,
                        icon: const Icon(Icons.download),
                        label: const Text('Import as new project'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
