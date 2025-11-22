import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/github_service.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/import_repository_dialog.dart';

class GitHubIntegrationScreen extends StatefulWidget {
  const GitHubIntegrationScreen({super.key});

  @override
  State<GitHubIntegrationScreen> createState() => _GitHubIntegrationScreenState();
}

class _GitHubIntegrationScreenState extends State<GitHubIntegrationScreen> {
  final GitHubService _githubService = GitHubService();
  bool _isLoading = false;
  String _token = '';
  bool _isConnected = false;
  Map<String, dynamic>? _githubUser;
  List<dynamic> _repositories = [];
  List<dynamic> _writableRepositories = [];
  List<String> _tokenScopes = [];
  bool _loadingRepositories = false;
  bool _loadingWritableRepositories = false;
  String _activeRepoTab = 'all';

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _githubService.getIntegrationStatus();

      if (!mounted) return;

      if (status != null && status['is_connected'] == true) {
        setState(() {
          _isConnected = true;
          // 获取 token 权限信息
          final scopes = status['scopes'] as List?;
          _tokenScopes = scopes != null ? List<String>.from(scopes) : [];
        });
        await _fetchGitHubUser();
        await _fetchRepositories();
        await _fetchWritableRepositories();
      }
    } catch (e) {
      debugPrint('Failed to check GitHub integration status: $e');
      // 如果未连接或检查失败，保持 _isConnected = false
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connectGitHub() async {
    if (!mounted) return;

    if (_token.trim().isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter your GitHub Personal Access Token',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 创建 GitHub 集成
      await _githubService.createIntegration(
        platformUsername: '', // 后端会自动从 token 获取
        accessToken: _token,
        tokenType: 'personal_access_token',
      );

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'GitHub account connected successfully!',
      );

      setState(() {
        _isConnected = true;
        _token = '';
      });

      await _fetchGitHubUser();
      await _fetchRepositories();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to connect GitHub account: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _disconnectGitHub() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _githubService.deleteIntegration();

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'GitHub account disconnected',
      );

      setState(() {
        _isConnected = false;
        _githubUser = null;
        _repositories = [];
        _writableRepositories = [];
        _tokenScopes = [];
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to disconnect GitHub account: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchGitHubUser() async {
    try {
      final user = await _githubService.getGitHubUser();

      if (!mounted) return;

      setState(() {
        _githubUser = user;
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to fetch GitHub user info: $e',
      );
    }
  }

  Future<void> _fetchRepositories() async {
    setState(() {
      _loadingRepositories = true;
    });

    try {
      final repos = await _githubService.getRepositories(
        perPage: 100,
        page: 1,
        type: 'all',
        sort: 'updated',
      );

      if (!mounted) return;

      setState(() {
        _repositories = repos;
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to fetch repositories: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingRepositories = false;
        });
      }
    }
  }

  Future<void> _fetchWritableRepositories() async {
    setState(() {
      _loadingWritableRepositories = true;
    });

    try {
      final repos = await _githubService.getWritableRepositories(
        perPage: 100,
        page: 1,
      );

      if (!mounted) return;

      setState(() {
        _writableRepositories = repos;
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to fetch writable repositories: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingWritableRepositories = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Integration'),
      ),
      body: _isConnected ? _buildConnectedState() : _buildDisconnectedState(),
    );
  }

  Widget _buildDisconnectedState() {
    return ListView(
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
                            'Connect GitHub Account',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect your GitHub account to import repositories',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'GitHub Personal Access Token',
                    hintText: 'ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    setState(() {
                      _token = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a Personal Access Token in your GitHub Settings',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _connectGitHub,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(_isLoading ? 'Connecting...' : 'Connect GitHub'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Connected Account Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_githubUser?['avatar_url'] != null)
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(_githubUser!['avatar_url']),
                      )
                    else
                      CircleAvatar(
                        radius: 24,
                        child: Icon(Icons.person, size: 32),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _githubUser?['login'] ?? 'GitHub User',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_githubUser?['name'] != null)
                            Text(
                              _githubUser!['name'],
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Connected',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Repositories',
                      '${_githubUser?['public_repos'] ?? 0}',
                    ),
                    _buildStatItem(
                      'Followers',
                      '${_githubUser?['followers'] ?? 0}',
                    ),
                    _buildStatItem(
                      'Following',
                      '${_githubUser?['following'] ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Token Permissions
                if (_tokenScopes.isNotEmpty) ...[
                  Text(
                    'Token Permissions:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getPermissionBadges(_tokenScopes)
                        .map((permission) => _buildPermissionBadge(permission))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _disconnectGitHub,
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    label: const Text(
                      'Disconnect',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Repositories Section
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Your GitHub Repositories'),
                subtitle: Text(
                  _activeRepoTab == 'all'
                      ? '${_repositories.length} repositories'
                      : '${_writableRepositories.length} writable repositories',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _activeRepoTab == 'all'
                      ? (_loadingRepositories ? null : _fetchRepositories)
                      : (_loadingWritableRepositories
                          ? null
                          : _fetchWritableRepositories),
                ),
              ),
              const Divider(height: 1),

              // Tab Buttons
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        'all',
                        'All Repositories (${_repositories.length})',
                        _activeRepoTab == 'all',
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        'writable',
                        'Writable (${_writableRepositories.length})',
                        _activeRepoTab == 'writable',
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Content
              if (_activeRepoTab == 'all')
                _buildRepositoriesList(_repositories, _loadingRepositories)
              else
                _buildRepositoriesList(
                    _writableRepositories, _loadingWritableRepositories),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 获取权限徽章信息
  List<Map<String, String>> _getPermissionBadges(List<String>? scopes) {
    if (scopes == null || scopes.isEmpty) return [];

    final permissionMap = <String, Map<String, String>>{
      'repo': {'label': 'Full Repository Access', 'color': '0xFF4CAF50'}, // green
      'public_repo': {'label': 'Public Repositories', 'color': '0xFF2196F3'}, // blue
      'read:user': {'label': 'Read User Profile', 'color': '0xFF9C27B0'}, // purple
      'user:email': {'label': 'User Email', 'color': '0xFFFF9800'}, // orange
      'read:org': {'label': 'Read Organization', 'color': '0xFFE91E63'}, // pink
      'workflow': {'label': 'GitHub Actions', 'color': '0xFFFFC107'}, // yellow
    };

    return scopes.map((scope) {
      final info = permissionMap[scope] ?? {'label': scope, 'color': '0xFF757575'};
      return {
        'scope': scope,
        'label': info['label']!,
        'color': info['color']!,
      };
    }).toList();
  }

  /// 构建权限徽章组件
  Widget _buildPermissionBadge(Map<String, String> permission) {
    final color = Color(int.parse(permission['color']!));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        permission['label']!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建标签页按钮
  Widget _buildTabButton(String tab, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeRepoTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab == 'all' ? Icons.folder : Icons.shield,
              size: 16,
              color: isActive ? Colors.deepPurple : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? Colors.deepPurple : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建仓库列表
  Widget _buildRepositoriesList(List<dynamic> repositories, bool isLoading) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (repositories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _activeRepoTab == 'all'
                ? 'No repositories found — check your GitHub connection or try syncing again.'
                : 'No writable repositories — grant access or switch to a different repo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      children: repositories
          .map((repo) => _buildRepositoryCard(repo, isWritable: _activeRepoTab == 'writable'))
          .toList(),
    );
  }

  /// 格式化更新时间为易读格式
  String _formatUpdatedTime(String? updatedAt) {
    if (updatedAt == null || updatedAt.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(updatedAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildRepositoryCard(dynamic repo, {bool isWritable = false}) {
    // GitHub API 返回的字段名
    final name = repo['name'] ?? '';
    final description = repo['description'];
    final language = repo['language'];
    final stars = repo['stargazers_count'] ?? repo['stars'] ?? 0;
    final forks = repo['forks_count'] ?? repo['forks'] ?? 0;
    final isPrivate = repo['private'] ?? false;
    final updatedAt = repo['updated_at'] as String?;
    final defaultBranch = repo['default_branch'] as String?;
    final updatedTimeText = _formatUpdatedTime(updatedAt);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: ListTile(
        leading: Icon(
          isPrivate ? Icons.lock : Icons.folder,
          color: Colors.deepPurple,
        ),
        title: Row(
          children: [
            Expanded(child: Text(name)),
            if (isPrivate)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            if (isWritable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield,
                      size: 10,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Writable',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            // 第一行：语言、星标、分叉
            Row(
              children: [
                if (language != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      language,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ),
                if (language != null) const SizedBox(width: 8),
                Icon(Icons.star, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '$stars',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.call_split, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '$forks',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 第二行：默认分支、更新时间
            Row(
              children: [
                if (defaultBranch != null && defaultBranch.isNotEmpty) ...[
                  Icon(Icons.account_tree, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    defaultBranch,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 12),
                ],
                if (updatedTimeText.isNotEmpty) ...[
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    updatedTimeText,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => ImportRepositoryDialog(repository: repo),
          );

          // If import was successful, optionally navigate or refresh
          if (result == true && mounted) {
            // Optionally refresh repositories or navigate to projects page
            SnackBarHelper.showInfo(
              context,
              title: 'Import Complete',
              message: 'Check your projects to see the imported repository',
            );

            // Navigate to projects page after a short delay
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                context.go('/projects');
              }
            });
          }
        },
      ),
    );
  }
}
