import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';
import 'github_repositories_screen.dart';
import 'github_quick_import_setup_screen.dart';

class GitHubSettingsScreen extends StatefulWidget {
  const GitHubSettingsScreen({super.key});

  @override
  State<GitHubSettingsScreen> createState() => _GitHubSettingsScreenState();
}

class _GitHubSettingsScreenState extends State<GitHubSettingsScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  final TextEditingController _tokenController = TextEditingController();

  bool _isConnecting = false;
  Map<String, dynamic>? _integrationStatus;
  Map<String, dynamic>? _githubUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIntegrationStatus();
  }

  Future<void> _loadIntegrationStatus() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final status = await _d1vaiService.getGitHubIntegrationStatus();

      if (mounted) {
        setState(() {
          _integrationStatus = status;
          _isLoading = false;
        });

        // 如果已连接，获取用户信息
        if (status['is_connected'] == true && status['token_valid'] == true) {
          _loadGitHubUser();
        }
      }
    } catch (e) {
      debugPrint('Failed to load GitHub integration status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Failed to load GitHub integration status',
        );
      }
    }
  }

  Future<void> _loadGitHubUser() async {
    try {
      final user = await _d1vaiService.getGitHubUser();
      if (mounted) {
        setState(() {
          _githubUser = user;
        });
      }
    } catch (e) {
      debugPrint('Failed to load GitHub user: $e');
    }
  }

  Future<void> _handleConnectGitHub() async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter your GitHub Personal Access Token',
      );
      return;
    }

    try {
      setState(() {
        _isConnecting = true;
      });

      await _d1vaiService.postGitHubIntegration(token);

      if (!mounted) return;

      setState(() {
        _tokenController.text = '';
        _isConnecting = false;
      });

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'GitHub account connected successfully!',
      );

      // 重新加载状态
      await _loadIntegrationStatus();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isConnecting = false;
      });

      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to connect GitHub account: $e',
      );
    }
  }

  Future<void> _handleDisconnectGitHub() async {
    try {
      await _d1vaiService.deleteGitHubIntegration();

      if (!mounted) return;

      setState(() {
        _integrationStatus = null;
        _githubUser = null;
      });

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'GitHub account disconnected successfully!',
      );
    } catch (e) {
      if (!mounted) return;

      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to disconnect GitHub account: $e',
      );
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// 构建统计项
  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Integration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                            Icon(Icons.code, color: Colors.deepPurple, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GitHub Account',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Connect your GitHub account to access your repositories and enable project imports.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_integrationStatus?['is_connected'] == true) ...[
                          // 已连接状态
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    if (_githubUser?['avatar_url'] != null)
                                      CircleAvatar(
                                        backgroundImage: NetworkImage(
                                          _githubUser!['avatar_url'] as String,
                                        ),
                                        radius: 24,
                                      )
                                    else
                                      CircleAvatar(
                                        radius: 24,
                                        child: Icon(Icons.person, size: 32),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _githubUser?['login'] ??
                                                _integrationStatus?['username'] ??
                                                'Connected',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_githubUser?['name'] != null)
                                            Text(
                                              _githubUser!['name'] as String,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // GitHub 用户统计信息
                                if (_githubUser != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem(
                                          'Repos',
                                          (_githubUser!['public_repos'] as int?)
                                              .toString(),
                                        ),
                                        Container(
                                          height: 40,
                                          width: 1,
                                          color: Colors.blue.shade200,
                                        ),
                                        _buildStatItem(
                                          'Followers',
                                          (_githubUser!['followers'] as int?)
                                              .toString(),
                                        ),
                                        Container(
                                          height: 40,
                                          width: 1,
                                          color: Colors.blue.shade200,
                                        ),
                                        _buildStatItem(
                                          'Following',
                                          (_githubUser!['following'] as int?)
                                              .toString(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _handleDisconnectGitHub,
                                        icon: const Icon(Icons.link_off),
                                        label: const Text('Disconnect'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // 未连接状态
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GitHub Personal Access Token',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _tokenController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  hintText:
                                      'ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a Personal Access Token in your GitHub Settings. The token needs repo permissions to access your repositories.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isConnecting ? null : _handleConnectGitHub,
                                  icon: _isConnecting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.link),
                                  label: Text(_isConnecting
                                      ? 'Connecting...'
                                      : 'Connect GitHub'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () {
                                    // TODO: 在浏览器中打开 GitHub 设置页面
                                    SnackBarHelper.showInfo(
                                      context,
                                      title: 'Info',
                                      message:
                                          'Please create a Personal Access Token in GitHub with repo permissions',
                                    );
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Open GitHub Settings'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_integrationStatus?['is_connected'] == true) ...[
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.folder_shared),
                          title: const Text('GitHub Repositories'),
                          subtitle: const Text('View and manage your repositories'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GitHubRepositoriesScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.cloud_download),
                          title: const Text('Import from GitHub'),
                          subtitle: const Text('Import repository as project'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GitHubRepositoriesScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.bolt),
                          title: const Text('Quick Import Setup'),
                          subtitle: const Text('Step-by-step guided import'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GitHubQuickImportSetupScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
