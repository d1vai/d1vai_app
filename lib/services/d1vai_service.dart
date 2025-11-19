import '../core/api_client.dart';
import '../models/user.dart';
import '../models/project.dart';

class D1vaiService {
  final ApiClient _apiClient;

  D1vaiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // Auth
  Future<String> postUserLogin(String email, String pin) async {
    return _apiClient.post<String>(
      '/user/login',
      {'email': email, 'verify_code': pin},
      fromJsonT: (json) => json as String,
    );
  }

  Future<String> postUserPasswordLogin(String email, String password) async {
    return _apiClient.post<String>(
      '/user/login/password',
      {'email': email, 'password': password},
      fromJsonT: (json) => json as String,
    );
  }

  // User
  Future<User> getUserProfile() async {
    return _apiClient.get<User>(
      '/user/info',
      fromJsonT: (json) => User.fromJson(json),
    );
  }

  // Projects
  Future<List<UserProject>> getUserProjects() async {
    return _apiClient.get<List<UserProject>>(
      '/projects',
      fromJsonT: (json) => (json as List).map((e) => UserProject.fromJson(e)).toList(),
    );
  }

  Future<UserProject> getUserProjectById(String id) async {
    return _apiClient.get<UserProject>(
      '/projects/$id',
      fromJsonT: (json) => UserProject.fromJson(json),
    );
  }

  Future<dynamic> createUserProject(Map<String, dynamic> data) async {
    // TODO: Define CreateProjectResponse model
    return _apiClient.post(
      '/projects',
      data,
    );
  }

  // Community
  Future<dynamic> postCommunityPost(Map<String, dynamic> data) async {
    return _apiClient.post(
      '/community/posts',
      data,
    );
  }
}
