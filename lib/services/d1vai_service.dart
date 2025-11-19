import 'dart:typed_data';
import '../core/api_client.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../models/community_post.dart';

class D1vaiService {
  final ApiClient _apiClient;

  D1vaiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ============================================
  // Auth Methods - 认证相关方法
  // ============================================

  /// 发送验证码到邮箱
  Future<Map<String, dynamic>> postUserVerifyCode(String email) async {
    return _apiClient.post<Map<String, dynamic>>('/user/verify-code', {
      'email': email,
    });
  }

  /// 使用验证码登录
  Future<String> postUserLogin(String email, String pin) async {
    return _apiClient.post<String>('/user/login', {
      'email': email,
      'verify_code': pin,
    }, fromJsonT: (json) => json as String);
  }

  /// 使用密码登录
  Future<String> postUserPasswordLogin(String email, String password) async {
    return _apiClient.post<String>('/user/login/password', {
      'email': email,
      'password': password,
    }, fromJsonT: (json) => json as String);
  }

  /// 接受邀请码
  Future<void> postUserAcceptInvitation(String code) async {
    return _apiClient.post<void>('/user/accept-invitation', {'code': code});
  }

  // ============================================
  // User Methods - 用户相关方法
  // ============================================

  /// 获取用户资料
  Future<User> getUserProfile() async {
    return _apiClient.get<User>(
      '/user/info',
      fromJsonT: (json) => User.fromJson(json),
    );
  }

  /// 更新用户资料
  Future<User> putUserProfile(Map<String, dynamic> data) async {
    return _apiClient.put<User>(
      '/user/profile',
      data,
      fromJsonT: (json) => User.fromJson(json),
    );
  }

  /// 设置 onboarding 状态
  Future<void> postUserOnboardedSet(bool isOnboarded) async {
    return _apiClient.post<void>('/user/onboarded', {
      'is_onboarded': isOnboarded,
    });
  }

  /// 上传头像
  Future<String> postUserAvatarUpload(
    Uint8List imageBytes,
    String fileName,
  ) async {
    // 使用通用文件上传接口上传头像图片，并返回头像 URL
    return _apiClient.uploadFile(imageBytes, fileName);
  }

  // ============================================
  // Projects Methods - 项目相关方法
  // ============================================

  /// 获取用户项目列表
  Future<List<UserProject>> getUserProjects() async {
    return _apiClient.get<List<UserProject>>(
      '/projects',
      fromJsonT: (json) =>
          (json as List).map((e) => UserProject.fromJson(e)).toList(),
    );
  }

  /// 根据 ID 获取项目详情
  Future<UserProject> getUserProjectById(String id) async {
    return _apiClient.get<UserProject>(
      '/projects/$id',
      fromJsonT: (json) => UserProject.fromJson(json),
    );
  }

  /// 创建新项目
  Future<dynamic> createUserProject(Map<String, dynamic> data) async {
    // TODO: Define CreateProjectResponse model
    return _apiClient.post('/projects', data);
  }

  // ============================================
  // Community Methods - 社区相关方法
  // ============================================

  /// 获取社区帖子列表
  Future<List<CommunityPost>> getCommunityPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    return _apiClient.get<List<CommunityPost>>(
      '/community/posts?limit=$limit&offset=$offset',
      fromJsonT: (json) => (json as List)
          .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 发布社区帖子
  Future<dynamic> postCommunityPost(Map<String, dynamic> data) async {
    return _apiClient.post('/community/posts', data);
  }
}
