import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/github_service.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/import_repository_dialog.dart';
import '../../widgets/login_required_view.dart';
import '../../widgets/snackbar_helper.dart';

class SettingsGithubTab extends StatefulWidget {
  const SettingsGithubTab({super.key});

  @override
  State<SettingsGithubTab> createState() => _SettingsGithubTabState();
}

class _SettingsGithubTabState extends State<SettingsGithubTab>
    with WidgetsBindingObserver {
  final GitHubService _githubService = GitHubService();

  bool _loading = true;
  bool _actionLoading = false;
  bool _repositoriesLoading = false;
  String? _error;
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _installations = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _repositories = const <Map<String, dynamic>>[];
  int? _selectedInstallationId;

  bool get _isConnected =>
      _status?['connected'] == true && _status?['token_valid'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadStatus(force: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadStatus(force: true));
    }
  }

  Future<void> _loadStatus({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      if (force) _error = null;
    });

    try {
      final status = await _githubService.getAppStatus();
      List<Map<String, dynamic>> installations = const <Map<String, dynamic>>[];
      if (status['connected'] == true && status['token_valid'] == true) {
        installations = await _githubService.getAppInstallations();
      }

      if (!mounted) return;
      final nextInstallationId = installations.isEmpty
          ? null
          : (installations.any((item) => item['id'] == _selectedInstallationId)
                ? _selectedInstallationId
                : (installations.first['id'] as num?)?.toInt());

      setState(() {
        _status = status;
        _installations = installations;
        _selectedInstallationId = nextInstallationId;
        if (installations.isEmpty) {
          _repositories = const <Map<String, dynamic>>[];
        }
      });

      if (nextInstallationId != null) {
        await _loadRepositories(nextInstallationId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRepositories(int installationId) async {
    if (!mounted) return;
    setState(() {
      _repositoriesLoading = true;
      _error = null;
    });
    try {
      final repositories = await _githubService.getAppRepositories(
        installationId: installationId,
      );
      if (!mounted) return;
      setState(() {
        _repositories = repositories;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _repositories = const <Map<String, dynamic>>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _repositoriesLoading = false;
        });
      }
    }
  }

  Future<void> _handleConnect() async {
    if (!mounted) return;
    setState(() {
      _actionLoading = true;
    });
    try {
      final redirectTo = 'https://www.d1v.ai/settings?tab=github';
      final url = await _githubService.getAppConnectUrl(redirectTo: redirectTo);
      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('Invalid GitHub connect URL');
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Failed to open GitHub authorization page');
      if (!mounted) return;
      SnackBarHelper.showInfo(
        context,
        title: 'GitHub',
        message: 'Finish authorization in the browser, then return here.',
        position: SnackBarPosition.top,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'GitHub',
        message: 'Failed to start GitHub authorization: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _handleDisconnect() async {
    if (!mounted) return;
    setState(() {
      _actionLoading = true;
    });
    try {
      await _githubService.disconnectApp();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'GitHub',
        message: 'GitHub account disconnected',
      );
      await _loadStatus(force: true);
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'GitHub',
        message: 'Failed to disconnect GitHub: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _openImportDialog(Map<String, dynamic> repository) async {
    final installationId = _selectedInstallationId;
    if (installationId == null) return;
    final imported = await showDialog<bool>(
      context: context,
      builder: (context) => ImportRepositoryDialog(
        repository: repository,
        installationId: installationId,
      ),
    );
    if (imported == true && mounted) {
      unawaited(_loadRepositories(installationId));
    }
  }

  String _statusLabel(AppLocalizations? loc) {
    if (_status?['configured'] != true) {
      return loc?.translate('error') ?? 'Not configured';
    }
    if (_isConnected) return loc?.translate('connected') ?? 'Connected';
    if (_status?['connected'] == true && _status?['token_valid'] != true) {
      return 'Reauthorize';
    }
    return loc?.translate('not_connected') ?? 'Not connected';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = Provider.of<AuthProvider>(context).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return LoginRequiredView(
        message:
            loc?.translate('login_required_github_message') ??
            'Please login first.',
        onAction: () => context.go('/login'),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadStatus(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.code,
                        color: AppColors.primaryBrand,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc?.translate('github_integration') ??
                                  'GitHub Integration',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _statusLabel(loc),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _isConnected
                                    ? Colors.green
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isConnected
                                  ? '@${(_status?['github_login'] ?? '').toString()}'
                                  : (loc?.translate(
                                          'github_connect_description',
                                        ) ??
                                        'Connect your GitHub account to import repositories'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_error != null && _error!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(
                          alpha: isDark ? 0.18 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Button(
                          onPressed: _actionLoading
                              ? null
                              : (_isConnected
                                    ? _handleDisconnect
                                    : _handleConnect),
                          icon: Icon(
                            _isConnected ? Icons.link_off : Icons.link,
                            size: 18,
                          ),
                          text: _isConnected ? 'Disconnect' : 'Connect GitHub',
                          backgroundColor: _isConnected ? Colors.black : null,
                          foregroundColor: _isConnected ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 104,
                        child: Button(
                          variant: ButtonVariant.secondary,
                          onPressed: _actionLoading
                              ? null
                              : () => unawaited(_loadStatus(force: true)),
                          icon: const Icon(Icons.refresh, size: 18),
                          text: 'Refresh',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isConnected) ...[
            CustomCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Installations',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose the GitHub account or organization you want to import from.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_installations.isEmpty)
                      Text(
                        'No GitHub App installations found yet. Connect GitHub and install the app to at least one account.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _installations.map((item) {
                          final id = (item['id'] as num?)?.toInt();
                          final selected =
                              id != null && id == _selectedInstallationId;
                          final label =
                              (item['account_login'] ?? 'Installation')
                                  .toString();
                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: id == null
                                ? null
                                : (_) {
                                    setState(() {
                                      _selectedInstallationId = id;
                                    });
                                    unawaited(_loadRepositories(id));
                                  },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Repositories',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_repositoriesLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Import a repository as a new project. The app will wait for preview deploy when possible.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedInstallationId == null)
                      Text(
                        'Select an installation first.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      )
                    else if (_repositories.isEmpty && !_repositoriesLoading)
                      Text(
                        'No repositories found for this installation.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      )
                    else
                      ..._repositories.map((repo) {
                        final fullName =
                            (repo['full_name'] ?? repo['name'] ?? '')
                                .toString();
                        final description = (repo['description'] ?? '')
                            .toString()
                            .trim();
                        final isPrivate =
                            repo['is_private'] == true ||
                            repo['private'] == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderSubtleDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      fullName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isPrivate
                                                  ? Colors.orange
                                                  : Colors.green)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isPrivate ? 'private' : 'public',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isPrivate
                                                ? Colors.orange.shade400
                                                : Colors.green.shade400,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: Button(
                                  onPressed: () => _openImportDialog(repo),
                                  icon: const Icon(Icons.download, size: 18),
                                  text: 'Import as Project',
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
