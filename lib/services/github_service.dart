import '../core/api_client.dart';

class GitHubService {
  final ApiClient _apiClient;

  GitHubService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getAppStatus() async {
    return _apiClient.get<Map<String, dynamic>>('/api/github-app/status');
  }

  Future<String> getAppConnectUrl({String? redirectTo}) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      '/api/github-app/connect-url',
      queryParams: redirectTo == null || redirectTo.trim().isEmpty
          ? null
          : {'redirect_to': redirectTo.trim()},
    );
    return (data['url'] ?? '').toString();
  }

  Future<void> disconnectApp() async {
    await _apiClient.delete<Map<String, dynamic>>('/api/github-app/disconnect');
  }

  Future<List<Map<String, dynamic>>> getAppInstallations() async {
    final data = await _apiClient.get<List<dynamic>>(
      '/api/github-app/installations',
    );
    return data
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAppRepositories({
    required int installationId,
  }) async {
    final data = await _apiClient.get<List<dynamic>>(
      '/api/github-app/repositories',
      queryParams: {'installation_id': installationId.toString()},
    );
    return data
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> importProjectFromGitHubApp({
    required int installationId,
    required int repositoryId,
    String? projectName,
    String? projectDescription,
  }) async {
    return _apiClient.post<Map<String, dynamic>>('/api/github-app/import', {
      'installation_id': installationId,
      'repository_id': repositoryId,
      if (projectName != null && projectName.trim().isNotEmpty)
        'project_name': projectName.trim(),
      if (projectDescription != null && projectDescription.trim().isNotEmpty)
        'project_description': projectDescription.trim(),
    }, timeout: const Duration(minutes: 4));
  }

  /// Get GitHub integration status
  Future<Map<String, dynamic>?> getIntegrationStatus() async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/github/integration/status',
    );
  }

  /// Create GitHub integration
  Future<Map<String, dynamic>?> createIntegration({
    required String platformUsername,
    required String accessToken,
    required String tokenType,
  }) async {
    return _apiClient.post<Map<String, dynamic>>('/api/github/integration', {
      'platform': 'github',
      'platform_username': platformUsername,
      'access_token': accessToken,
      'token_type': tokenType,
    });
  }

  /// Delete GitHub integration
  Future<void> deleteIntegration() async {
    return _apiClient.delete<void>('/api/github/integration');
  }

  /// Verify GitHub integration
  Future<Map<String, dynamic>?> verifyIntegration() async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/github/integration/verify',
      {},
    );
  }

  /// Get GitHub user info
  Future<Map<String, dynamic>?> getGitHubUser() async {
    return _apiClient.get<Map<String, dynamic>>('/api/github/user');
  }

  /// Get user's repositories
  Future<List<Map<String, dynamic>>> getRepositories({
    int perPage = 100,
    int page = 1,
    String type = 'all',
    String sort = 'updated',
  }) async {
    final data = await _apiClient.get<List<dynamic>>(
      '/api/github/repositories?per_page=$perPage&page=$page&type=$type&sort=$sort',
    );
    return data.cast<Map<String, dynamic>>();
  }

  /// Get user's writable repositories
  Future<List<Map<String, dynamic>>> getWritableRepositories({
    int perPage = 100,
    int page = 1,
  }) async {
    final data = await _apiClient.get<List<dynamic>>(
      '/api/github/repositories/writable?per_page=$perPage&page=$page',
    );
    return data.cast<Map<String, dynamic>>();
  }

  /// Get specific repository info
  Future<Map<String, dynamic>?> getRepositoryInfo({
    required String owner,
    required String repo,
  }) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/github/repositories/$owner/$repo',
    );
  }

  /// Import project from GitHub
  Future<Map<String, dynamic>?> importProjectFromGitHub({
    required String repositoryFullName,
    required String projectName,
    required String projectDescription,
    String defaultBranch = 'main',
    String? repositoryUrl,
    String? repositorySshUrl,
    bool isPrivate = false,
    String? primaryLanguage,
  }) async {
    return _apiClient
        .post<Map<String, dynamic>>('/api/projects/import-from-github', {
          'repository_full_name': repositoryFullName,
          'project_name': projectName,
          'project_description': projectDescription,
          if (repositoryUrl != null) 'repository_url': repositoryUrl,
          if (repositorySshUrl != null) 'repository_ssh_url': repositorySshUrl,
          'default_branch': defaultBranch,
          'is_private': isPrivate,
          if (primaryLanguage != null) 'primary_language': primaryLanguage,
        }, timeout: const Duration(minutes: 4));
  }
}
