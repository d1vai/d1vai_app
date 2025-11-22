import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';

enum QuickImportStep {
  addBot,
  acceptInvitation,
  importProject,
}

class GitHubQuickImportSetupScreen extends StatefulWidget {
  const GitHubQuickImportSetupScreen({super.key});

  @override
  State<GitHubQuickImportSetupScreen> createState() =>
      _GitHubQuickImportSetupScreenState();
}

class _GitHubQuickImportSetupScreenState
    extends State<GitHubQuickImportSetupScreen> {
  final D1vaiService _d1vaiService = D1vaiService();

  QuickImportStep _currentStep = QuickImportStep.addBot;
  String _botUsername = 'd1v-dev';
  final TextEditingController _repoUrlController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();

  bool _isLoading = false;
  bool _invitationAccepted = false;
  bool _accessVerified = false;
  Map<String, dynamic>? _repoInfo;

  @override
  void initState() {
    super.initState();
    _loadBotUsername();
  }

  Future<void> _loadBotUsername() async {
    try {
      final response = await _d1vaiService.getGitHubBotUsername();
      if (response['username'] != null) {
        setState(() {
          _botUsername = response['username'] as String;
        });
      }
    } catch (e) {
      debugPrint('Failed to load bot username: $e');
    }
  }

  @override
  void dispose() {
    _repoUrlController.dispose();
    _projectNameController.dispose();
    super.dispose();
  }

  Future<void> _copyBotUsername() async {
    await Clipboard.setData(ClipboardData(text: _botUsername));
    if (mounted) {
      SnackBarHelper.showSuccess(
        context,
        title: 'Copied',
        message: 'Bot username copied to clipboard',
      );
    }
  }

  void _openGitHubSettings() {
    // 提示用户打开 GitHub 设置页面
    SnackBarHelper.showInfo(
      context,
      title: 'GitHub Settings',
      message: 'Please go to GitHub Settings > Repositories to add collaborator',
    );
  }

  Future<void> _handleAcceptInvitation() async {
    final repoUrl = _repoUrlController.text.trim();

    if (repoUrl.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter a repository URL',
      );
      return;
    }

    // 从 URL 中提取 owner/repo
    final match = RegExp(r'github\.com/([^\/]+)/([^\/\?#]+)').firstMatch(repoUrl);
    if (match == null) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Invalid GitHub repository URL',
      );
      return;
    }

    final owner = match.group(1)!;
    final repo = match.group(2)!.replaceAll('.git', '');
    final fullName = '$owner/$repo';

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _d1vaiService.acceptGitHubInvitation(fullName);

      if (response['success'] == true) {
        setState(() {
          _invitationAccepted = true;
          _currentStep = QuickImportStep.importProject;
        });

        if (!mounted) return;
        SnackBarHelper.showSuccess(
          context,
          title: 'Success',
          message: response['message'] ?? 'Invitation accepted successfully',
        );

        // 自动验证访问权限
        await _verifyAccess(owner, repo);
      } else {
        if (!mounted) return;
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: response['message'] ?? 'No pending invitation found',
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to accept invitation: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyAccess(String owner, String repo) async {
    try {
      final response = await _d1vaiService.checkRepositoryAccess(owner, repo);

      if (!mounted) return;

      if (response['has_access'] == true) {
        setState(() {
          _accessVerified = true;
          _repoInfo = response;
        });

        // 设置项目名称默认值
        if (_projectNameController.text.isEmpty) {
          _projectNameController.text = response['repository_name'] ?? repo;
        }

        SnackBarHelper.showSuccess(
          context,
          title: 'Success',
          message: 'Access verified to ${response['repository_full_name']}',
        );
      } else {
        setState(() {
          _accessVerified = false;
        });
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Bot does not have access to this repository yet',
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to verify repository access: $e',
      );
    }
  }

  Future<void> _handleImportProject() async {
    if (!_accessVerified || _repoInfo == null) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please complete previous steps first',
      );
      return;
    }

    final projectName = _projectNameController.text.trim();
    if (projectName.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter a project name',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _d1vaiService.postProjectsImportFromGitHub(
        projectName: projectName,
        projectDescription: _repoInfo!['description'] ??
            'Imported from ${_repoInfo!['repository_full_name']}',
        repositoryFullName: _repoInfo!['repository_full_name'] as String,
        repositoryUrl: _repoInfo!['clone_url'] as String,
        repositorySshUrl: _repoInfo!['ssh_url'] as String,
        defaultBranch: _repoInfo!['default_branch'] as String? ?? 'main',
        isPrivate: _repoInfo!['is_private'] as bool? ?? false,
        primaryLanguage: _repoInfo!['language'] as String?,
      );

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Project "$projectName" imported successfully!',
      );

      // 延迟跳转到项目页面
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        context.pop(); // 返回 GitHub 设置页面
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to import project: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Import Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code, color: Colors.blue.shade600, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Quick Import Setup',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow these steps to import your GitHub repository as a project',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Step 1: Add Bot Collaborator
          _buildStepCard(
            stepNumber: 1,
            title: 'Add Bot Collaborator',
            isCompleted: false, // 这个步骤无法在 app 内完成
            isActive: _currentStep == QuickImportStep.addBot,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add $_botUsername as a collaborator to your repository',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _botUsername,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: _copyBotUsername,
                              tooltip: 'Copy username',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _openGitHubSettings,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Go to GitHub'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Step 2: Accept Invitation
          _buildStepCard(
            stepNumber: 2,
            title: 'Accept Invitation',
            isCompleted: _invitationAccepted,
            isActive: _currentStep == QuickImportStep.acceptInvitation,
            child: Column(
              children: [
                TextField(
                  controller: _repoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Repository URL',
                    hintText: 'https://github.com/owner/repository',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_invitationAccepted,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _invitationAccepted
                        ? null
                        : (_isLoading ? null : _handleAcceptInvitation),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_invitationAccepted
                        ? 'Invitation Accepted'
                        : (_isLoading ? 'Accepting...' : 'Accept Invitation')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _invitationAccepted
                          ? Colors.green
                          : Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Step 3: Import Project
          _buildStepCard(
            stepNumber: 3,
            title: 'Import Project',
            isCompleted: false,
            isActive: _currentStep == QuickImportStep.importProject,
            child: Column(
              children: [
                if (!_invitationAccepted)
                  Text(
                    'Complete steps 1–2 to proceed',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  )
                else if (_accessVerified && _repoInfo != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repository:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _repoInfo!['repository_full_name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_repoInfo!['language'] != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _repoInfo!['language'] as String,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _projectNameController,
                    decoration: const InputDecoration(
                      labelText: 'Project Name',
                      hintText: 'Enter project name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleImportProject,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.cloud_download),
                      label: Text(_isLoading ? 'Importing...' : 'Import Project'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else if (_invitationAccepted && !_accessVerified)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Verifying repository access...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required Widget child,
    required bool isCompleted,
    required bool isActive,
  }) {
    final stepColor = isCompleted
        ? Colors.green
        : isActive
            ? Colors.blue
            : Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: stepColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : Icons.circle,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: stepColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
