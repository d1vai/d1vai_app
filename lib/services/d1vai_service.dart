import 'dart:typed_data';
import '../core/api_client.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../models/community_post.dart';
import 'cache_service.dart';

class D1vaiService {
  final ApiClient _apiClient;
  final CacheService _cacheService;

  D1vaiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        _cacheService = CacheService();

  // ============================================
  // Auth Methods - 认证相关方法
  // ============================================

  /// 发送验证码到邮箱
  Future<Map<String, dynamic>?> postUserVerifyCode(String email) async {
    // 使用 POST 方法 + 查询参数（与 web 端完全一致）
    // 验证码发送成功后返回 data: null，所以我们检查状态即可
    await _apiClient.postWithQuery<void>(
      '/api/user/verify-code',
      {'email': email},  // 查询参数
      {'email': email},  // 请求体（与 web 端一致）
    );
    // 返回空 map 表示发送成功（与 Web 端逻辑一致）
    return {};
  }

  /// 使用验证码登录
  Future<String?> postUserLogin(String email, String pin) async {
    return _apiClient.post<String?>(
      '/api/user/login',
      {
        'email': email,
        'verify_code': pin,
      },
      fromJsonT: (json) => json as String?,
    );
  }

  /// 使用密码登录
  Future<String?> postUserPasswordLogin(String email, String password) async {
    return _apiClient.post<String?>(
      '/api/user/login/password',
      {
        'email': email,
        'password': password,
      },
      fromJsonT: (json) => json as String?,
    );
  }

  /// 接受邀请码
  Future<void> postUserAcceptInvitation(String code) async {
    return _apiClient.post<void>('/api/user/invitation/accept', {
      'invite_code': code,
    });
  }

  // ============================================
  // User Methods - 用户相关方法
  // ============================================

  /// 获取用户资料
  Future<User> getUserProfile() async {
    return _apiClient.get<User>(
      '/api/user/info',
      fromJsonT: (json) => User.fromJson(json),
    );
  }

  /// 更新用户资料
  Future<User> putUserProfile(Map<String, dynamic> data) async {
    return _apiClient.put<User>(
      '/api/user/info',
      data,
      fromJsonT: (json) => User.fromJson(json),
    );
  }

  /// 设置 onboarding 状态
  Future<void> postUserOnboardedSet(bool isOnboarded) async {
    return _apiClient.post<void>('/api/user/onboarded/set', {'value': isOnboarded});
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

  /// 获取用户项目列表（带缓存）
  Future<List<UserProject>> getUserProjects() async {
    const cacheKey = 'user_projects';

    // 尝试从缓存获取
    final cachedData = await _cacheService.get<List<UserProject>>(
      cacheKey,
      (json) {
        final data = json['data'] as List;
        return data.map((e) => UserProject.fromJson(e)).toList();
      },
    );

    if (cachedData != null) {
      return cachedData;
    }

    // 缓存未命中，从 API 获取
    final data = await _apiClient.get<List<UserProject>>(
      '/api/projects',
      fromJsonT: (json) =>
          (json as List).map((e) => UserProject.fromJson(e)).toList(),
    );

    // 存入缓存，设置 5 分钟过期
    await _cacheService.set<List<UserProject>>(
      cacheKey,
      data,
      (projects) => {'data': projects.map((p) => p.toJson()).toList()},
      ttl: const Duration(minutes: 5),
    );

    return data;
  }

  /// 根据 ID 获取项目详情
  Future<UserProject> getUserProjectById(String id) async {
    return _apiClient.get<UserProject>(
      '/api/projects/$id',
      fromJsonT: (json) => UserProject.fromJson(json),
    );
  }

  /// 创建新项目
  Future<dynamic> createUserProject(Map<String, dynamic> data) async {
    // TODO: Define CreateProjectResponse model
    return _apiClient.post('/api/projects', data);
  }

  // ============================================
  // Community Methods - 社区相关方法
  // ============================================

  /// 获取社区帖子列表（带缓存）
  Future<List<CommunityPost>> getCommunityPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = 'community_posts_${limit}_$offset';

    // 尝试从缓存获取
    final cachedData = await _cacheService.get<List<CommunityPost>>(
      cacheKey,
      (json) {
        final data = json['data'] as List;
        return data
            .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );

    if (cachedData != null) {
      return cachedData;
    }

    // 缓存未命中，从 API 获取
    final data = await _apiClient.get<List<CommunityPost>>(
      '/api/community/posts?limit=$limit&offset=$offset',
      fromJsonT: (json) => (json as List)
          .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    // 存入缓存，设置 3 分钟过期（社区帖子更新更频繁）
    await _cacheService.set<List<CommunityPost>>(
      cacheKey,
      data,
      (posts) => {'data': posts.map((p) => p.toJson()).toList()},
      ttl: const Duration(minutes: 3),
    );

    return data;
  }

  /// 发布社区帖子
  Future<dynamic> postCommunityPost(Map<String, dynamic> data) async {
    // 清除社区帖子缓存，确保下次获取最新数据
    await _cacheService.clearCommunityCache();
    return _apiClient.post('/api/community/posts', data);
  }
}
