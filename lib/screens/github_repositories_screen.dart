import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';

class GitHubRepositoriesScreen extends StatefulWidget {
  const GitHubRepositoriesScreen({super.key});

  @override
  State<GitHubRepositoriesScreen> createState() =>
      _GitHubRepositoriesScreenState();
}

class _GitHubRepositoriesScreenState extends State<GitHubRepositoriesScreen>
    with TickerProviderStateMixin {
  final D1vaiService _d1vaiService = D1vaiService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _repositories = [];
  List<Map<String, dynamic>> _writableRepositories = [];
  String? _error;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRepositories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRepositories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 并行加载所有仓库和可写仓库
      final results = await Future.wait([
        _d1vaiService.getGitHubRepositories(),
        _d1vaiService.getGitHubWritableRepositories(),
      ]);

      if (!mounted) return;

      setState(() {
        _repositories = results[0];
        _writableRepositories = results[1];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load repositories: $e';
        _isLoading = false;
      });

      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to load repositories',
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Repositories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_shared, size: 18),
                  const SizedBox(width: 8),
                  Text('All Repos'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield, size: 18),
                  const SizedBox(width: 8),
                  Text('Writable'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRepositories,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRepositoriesTab(_repositories),
                    _buildWritableRepositoriesTab(),
                  ],
                ),
    );
  }

  Widget _buildRepositoriesTab(List<Map<String, dynamic>> repositories) {
    if (repositories.isEmpty) {
      return const Center(
        child: Text('No repositories found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRepositories,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: repositories.length,
        itemBuilder: (context, index) {
          final repo = repositories[index];
          return _buildRepositoryCard(repo);
        },
      ),
    );
  }

  Widget _buildWritableRepositoriesTab() {
    return RefreshIndicator(
      onRefresh: _loadRepositories,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _writableRepositories.length,
        itemBuilder: (context, index) {
          final repo = _writableRepositories[index];
          return _buildRepositoryCard(repo, isWritable: true);
        },
      ),
    );
  }

  Widget _buildRepositoryCard(Map<String, dynamic> repo,
      {bool isWritable = false}) {
    final name = repo['full_name'] ?? repo['name'] ?? 'Unknown';
    final description = repo['description'] as String?;
    final language = repo['language'] as String?;
    final stars = repo['stars'] as int? ?? 0;
    final forks = repo['forks'] as int? ?? 0;
    final isPrivate = repo['is_private'] as bool? ?? false;
    final defaultBranch = repo['default_branch'] as String? ?? 'main';
    final updatedAt = repo['updated_at'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isPrivate ? Icons.lock : Icons.lock_open,
                            size: 16,
                            color: isPrivate ? Colors.red : Colors.green,
                          ),
                          if (isWritable) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Writable',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          if (language != null)
                            _buildInfoChip(
                              icon: Icons.code,
                              label: language,
                            ),
                          _buildInfoChip(
                            icon: Icons.star,
                            label: stars.toString(),
                          ),
                          _buildInfoChip(
                            icon: Icons.call_split,
                            label: forks.toString(),
                          ),
                          _buildInfoChip(
                            icon: Icons.code,
                            label: defaultBranch,
                          ),
                          if (updatedAt != null)
                            _buildInfoChip(
                              icon: Icons.update,
                              label: _formatDate(updatedAt),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'just now';
      }
    } catch (e) {
      return dateString;
    }
  }
}
