import 'dart:typed_data';
import '../core/api_client.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../models/community_post.dart';
import '../models/prompt_activity.dart';

import '../models/deployment.dart';
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
      {'email': email}, // 查询参数
      {'email': email}, // 请求体（与 web 端一致）
    );
    // 返回空 map 表示发送成功（与 Web 端逻辑一致）
    return {};
  }

  /// 使用验证码登录
  Future<String?> postUserLogin(String email, String pin) async {
    return _apiClient.post<String?>('/api/user/login', {
      'email': email,
      'verify_code': pin,
    }, fromJsonT: (json) => json as String?);
  }

  /// 使用密码登录
  Future<String?> postUserPasswordLogin(String email, String password) async {
    return _apiClient.post<String?>('/api/user/login/password', {
      'email': email,
      'password': password,
    }, fromJsonT: (json) => json as String?);
  }

  /// 接受邀请码
  Future<void> postUserAcceptInvitation(String code) async {
    return _apiClient.post<void>('/api/user/invitation/accept', {
      'invite_code': code,
    });
  }

  /// Solana 钱包登录
  Future<String?> postUserSolanaLogin(
    String walletAddress,
    String message,
    List<int> signature,
  ) async {
    return _apiClient.post<String?>('/api/solana/login', {
      'wallet_address': walletAddress,
      'message': message,
      'signature': signature,
    }, fromJsonT: (json) => json as String?);
  }

  /// Sui 钱包登录
  Future<String?> postUserSuiLogin(
    String walletAddress,
    String message,
    String signature,
  ) async {
    return _apiClient.post<String?>('/api/sui/login', {
      'wallet_address': walletAddress,
      'message': message,
      'signature': signature,
    }, fromJsonT: (json) => json as String?);
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
    return _apiClient.post<void>('/api/user/onboarded/set', {
      'value': isOnboarded,
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

  /// 发送绑定邮箱验证码
  Future<void> postUserBindEmailSend(String email) async {
    return _apiClient.post<void>('/api/user/bind-email/send', {'email': email});
  }

  /// 确认绑定邮箱
  Future<void> postUserBindEmailConfirm(String email, String code) async {
    return _apiClient.post<void>('/api/user/bind-email/confirm', {
      'email': email,
      'code': code,
    });
  }

  /// 发送更改邮箱验证码
  Future<void> postUserChangeEmailSend(String newEmail) async {
    return _apiClient.post<void>('/api/user/email/change/send', {
      'new_email': newEmail,
    });
  }

  /// 确认更改邮箱
  Future<void> postUserChangeEmailConfirm(String newEmail, String code) async {
    return _apiClient.post<void>('/api/user/email/change/confirm', {
      'new_email': newEmail,
      'code': code,
    });
  }

  /// 设置密码
  Future<void> postUserPasswordSet(String password) async {
    return _apiClient.post<void>('/api/user/password/set', {
      'password': password,
    });
  }

  /// 发送忘记密码验证码
  Future<void> postUserPasswordForgotSend(String email) async {
    return _apiClient.post<void>('/api/user/password/forgot/send', {
      'email': email,
    });
  }

  /// 重置密码
  Future<void> postUserPasswordReset(
    String email,
    String code,
    String newPassword,
  ) async {
    return _apiClient.post<void>('/api/user/password/reset', {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  /// 验证验证码
  Future<void> postVerifyCodeCheck(
    String email,
    String code,
    String purpose,
  ) async {
    return _apiClient.post<void>('/api/user/verify-code/check', {
      'email': email,
      'code': code,
      'purpose': purpose,
    });
  }

  /// 获取邀请的用户列表
  Future<List<dynamic>> getMyInvitees() async {
    return _apiClient.get<List<dynamic>>('/api/user/invitations');
  }

  /// 获取公共用户信息（按 ID）
  Future<Map<String, dynamic>> getPublicUser(String userId) async {
    return _apiClient.get<Map<String, dynamic>>('/api/user/public/$userId');
  }

  /// 获取公共用户信息（按 Slug）
  Future<Map<String, dynamic>> getPublicUserBySlug(String slug) async {
    return _apiClient.get<Map<String, dynamic>>('/api/user/public/slug/$slug');
  }

  /// 获取当前用户最近 N 天 prompt 活跃度（GitHub-style heatmap）
  Future<PromptDailyActivity> getPromptDailyActivity({
    int days = 90,
    String? projectId,
  }) async {
    final qp = <String, String>{'days': days.toString()};
    final pid = (projectId ?? '').trim();
    if (pid.isNotEmpty) {
      // Backend may ignore this param if unsupported; safe fallback to global activity.
      qp['project_id'] = pid;
    }
    return _apiClient.get<PromptDailyActivity>(
      '/api/user/activity/prompt-daily',
      queryParams: qp,
      fromJsonT: (json) =>
          PromptDailyActivity.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 获取指定用户（slug）最近 N 天 prompt 活跃度（公开接口）
  Future<PromptDailyActivity> getPublicPromptDailyActivityBySlug(
    String slug, {
    int days = 90,
  }) async {
    return _apiClient.get<PromptDailyActivity>(
      '/api/user/activity/prompt-daily/slug/$slug',
      queryParams: {'days': days.toString()},
      fromJsonT: (json) =>
          PromptDailyActivity.fromJson(json as Map<String, dynamic>),
    );
  }

  // ============================================
  // Projects Methods - 项目相关方法
  // ============================================

  /// 获取用户项目列表（带缓存）
  Future<List<UserProject>> getUserProjects({bool forceRefresh = false}) async {
    const cacheKey = 'user_projects';

    if (!forceRefresh) {
      // 尝试从缓存获取
      final cachedData = await _cacheService.get<List<UserProject>>(cacheKey, (
        json,
      ) {
        final data = json['data'] as List;
        return data.map((e) => UserProject.fromJson(e)).toList();
      });

      if (cachedData != null) {
        return cachedData;
      }
    }

    // 缓存未命中或强制刷新，从 API 获取
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
  Future<Map<String, dynamic>> createUserProject(
    Map<String, dynamic> data,
  ) async {
    // Backend response: BaseResponse<{ project, session }>
    return _apiClient.post<Map<String, dynamic>>('/api/projects', data);
  }

  /// AI 生成项目元数据
  Future<Map<String, dynamic>> generateProjectMeta({
    required String prompt,
    int? maxDescLen,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/ai/generate-meta',
      {'prompt': prompt, if (maxDescLen != null) 'max_desc_len': maxDescLen},
    );
  }

  /// 创建带集成的项目
  Future<dynamic> createProjectWithIntegrations({
    required String prompt,
    int? maxDescLen,
    bool? enablePay,
    bool? enableDatabase,
    bool? enableResend,
  }) async {
    return _apiClient.post(
      '/api/projects/create-with-integrations',
      {
        'prompt': prompt,
        if (maxDescLen != null) 'max_desc_len': maxDescLen,
        if (enablePay != null) 'enable_pay': enablePay,
        if (enableDatabase != null) 'enable_database': enableDatabase,
        if (enableResend != null) 'enable_resend': enableResend,
      },
      // Project bootstrap may involve remote template/git/bootstrap work.
      // Give it more headroom and retry transient network disconnects.
      retries: 2,
      timeout: const Duration(minutes: 8),
    );
  }

  /// 更新项目信息
  Future<Map<String, dynamic>> updateUserProject(
    String projectId,
    Map<String, dynamic> data,
  ) async {
    return _apiClient.put<Map<String, dynamic>>(
      '/api/projects/$projectId',
      data,
    );
  }

  /// 获取数据库信息
  Future<Map<String, dynamic>> getDatabaseByProjectId(String id) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/user_project/database/$id',
    );
  }

  // ============================================
  // Project Session Methods - 项目会话方法
  // ============================================

  /// 执行项目会话
  Future<Map<String, dynamic>> executeProjectSession(
    String projectId,
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/sessions/execute',
      payload,
    );
  }

  /// 取消项目会话
  Future<Map<String, dynamic>> cancelProjectSession(String sessionId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/sessions/$sessionId/cancel',
      {},
    );
  }

  // ============================================
  // Project History Methods - 项目历史记录方法
  // ============================================

  /// 获取项目历史记录
  Future<List<dynamic>> getProjectHistory(
    String projectId, {
    int limit = 30,
    String? beforeTs,
    String? direction,
    String? messageType,
    bool includePayload = true,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'include_payload': includePayload.toString(),
    };
    if (beforeTs != null) queryParams['before_ts'] = beforeTs;
    if (direction != null) queryParams['direction'] = direction;
    if (messageType != null) queryParams['message_type'] = messageType;

    return _apiClient.get<List<dynamic>>(
      '/api/projects/$projectId/history',
      queryParams: queryParams,
    );
  }

  /// 获取项目历史详情
  Future<Map<String, dynamic>> getProjectHistoryDetail(
    String projectId,
    int historyId,
  ) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/$projectId/history/$historyId',
    );
  }

  // ============================================
  // Storage Methods - 存储相关方法
  // ============================================

  /// 获取项目存储结构
  Future<Map<String, dynamic>> getProjectStorageStructure(
    String projectId, {
    String? subPath,
    List<String>? exts,
  }) async {
    final queryParams = <String, String>{};
    if (subPath != null) {
      queryParams['sub_path'] = subPath.replaceAll(RegExp(r'^/+'), '');
    }
    if (exts != null && exts.isNotEmpty) {
      final normalizedExts = exts
          .map((e) => e.trim().replaceAll(RegExp(r'^\.'), '').toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (normalizedExts.isNotEmpty) {
        queryParams['ext'] = normalizedExts.join(',');
      }
    }

    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/storage/$projectId/structure',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 获取项目存储文件
  Future<Map<String, dynamic>> getProjectStorageFile(
    String projectId,
    String filePath,
  ) async {
    final cleanPath = filePath.replaceAll(RegExp(r'^/+'), '');
    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/storage/$projectId/files/$cleanPath',
    );
  }

  // ============================================
  // Community Methods - 社区相关方法
  // ============================================

  /// 获取社区帖子列表（带缓存）
  Future<List<CommunityPost>> getCommunityPosts({
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    final cacheKey =
        'community_posts_${limit}_$offset${searchQuery != null ? '_q_$searchQuery' : ''}';

    // 尝试从缓存获取
    final cachedData = await _cacheService.get<List<CommunityPost>>(cacheKey, (
      json,
    ) {
      final data = json['data'] as List;
      return data
          .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    if (cachedData != null) {
      return cachedData;
    }

    // 构建查询参数
    final queryParams = <String>['limit=$limit', 'offset=$offset'];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams.add('q=${Uri.encodeQueryComponent(searchQuery)}');
    }

    // 缓存未命中，从 API 获取
    final data = await _apiClient.get<List<CommunityPost>>(
      '/api/community/posts?${queryParams.join('&')}',
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

  /// 发布社区帖子并公开
  Future<dynamic> postCommunityPublish(int postId) async {
    await _cacheService.clearCommunityCache();
    return _apiClient.post('/api/community/posts/$postId/publish', {});
  }

  /// 取消发布社区帖子
  Future<dynamic> postCommunityUnpublish(int postId) async {
    await _cacheService.clearCommunityCache();
    return _apiClient.post('/api/community/posts/$postId/unpublish', {});
  }

  /// 获取社区帖子详情（slug）
  ///
  /// Backend: GET /api/community/posts/{slug}
  Future<CommunityPost> getCommunityPostDetails(String slug) async {
    return _apiClient.get<CommunityPost>(
      '/api/community/posts/$slug',
      fromJsonT: (json) => CommunityPost.fromJson(json),
    );
  }

  // ============================================
  // Database Methods - 数据库相关方法
  // ============================================

  /// 获取项目数据库 Schema
  Future<Map<String, dynamic>> getProjectDbSchema(
    String projectId, {
    String? branch,
    bool includeViews = false,
    bool withRowCounts = false,
    bool includeSystemSchemas = false,
  }) async {
    final queryParams = <String, String>{};
    if (branch != null) queryParams['branch'] = branch;
    if (includeViews) queryParams['include_views'] = 'true';
    if (withRowCounts) queryParams['with_row_counts'] = 'true';
    if (includeSystemSchemas) {
      queryParams['include_system_schemas'] = 'true';
    }

    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/$projectId/db/schema',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 获取项目数据库数据
  Future<Map<String, dynamic>> getProjectDbData(
    String projectId, {
    String? branch,
    int limitPerTable = 100,
    bool includeViews = false,
    bool includeSystemSchemas = false,
  }) async {
    final queryParams = <String, String>{
      'limit_per_table': limitPerTable.toString(),
    };
    if (branch != null) queryParams['branch'] = branch;
    if (includeViews) queryParams['include_views'] = 'true';
    if (includeSystemSchemas) {
      queryParams['include_system_schemas'] = 'true';
    }

    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/$projectId/db/data',
      queryParams: queryParams,
    );
  }

  /// 获取数据库表行数据
  Future<List<dynamic>> listDbRows(
    String projectId,
    String schema,
    String table, {
    String? branch,
    int limit = 100,
    int offset = 0,
    String? filters,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (branch != null) queryParams['branch'] = branch;
    if (filters != null) queryParams['filters'] = filters;

    return _apiClient.get<List<dynamic>>(
      '/api/projects/$projectId/db/tables/$schema/$table/rows',
      queryParams: queryParams,
    );
  }

  /// 创建数据库表
  Future<Map<String, dynamic>> createDbTable(
    String projectId, {
    required String tableName,
    required List<Map<String, dynamic>> columns,
    String? schemaName,
    List<String>? primaryKey,
    String? branch,
  }) async {
    return _apiClient
        .post<Map<String, dynamic>>('/api/projects/$projectId/db/tables', {
          'table_name': tableName,
          'columns': columns,
          if (schemaName != null) 'schema_name': schemaName,
          if (primaryKey != null) 'primary_key': primaryKey,
          if (branch != null) 'branch': branch,
        });
  }

  /// 重命名数据库表
  Future<Map<String, dynamic>> renameDbTable(
    String projectId,
    String schema,
    String table, {
    required String newTableName,
    String? branch,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/db/tables/$schema/$table/rename',
      {'new_table_name': newTableName, if (branch != null) 'branch': branch},
    );
  }

  /// 插入数据库行
  Future<Map<String, dynamic>> insertDbRow(
    String projectId,
    String schema,
    String table, {
    required Map<String, dynamic> values,
    String? branch,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/db/tables/$schema/$table/rows',
      {'values': values, if (branch != null) 'branch': branch},
    );
  }

  /// 更新数据库行
  Future<Map<String, dynamic>> updateDbRows(
    String projectId,
    String schema,
    String table, {
    required Map<String, dynamic> where,
    required Map<String, dynamic> values,
    String? branch,
  }) async {
    return _apiClient.patch<Map<String, dynamic>>(
      '/api/projects/$projectId/db/tables/$schema/$table/rows',
      {'where': where, 'values': values, if (branch != null) 'branch': branch},
    );
  }

  /// 删除数据库行
  Future<Map<String, dynamic>> deleteDbRows(
    String projectId,
    String schema,
    String table, {
    required Map<String, dynamic> where,
    String? branch,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/db/tables/$schema/$table/rows/delete',
      {'where': where, if (branch != null) 'branch': branch},
    );
  }

  /// 获取项目数据库分支列表
  Future<List<dynamic>> getProjectDbBranches(String projectId) async {
    return _apiClient.get<List<dynamic>>(
      '/api/projects/$projectId/db/branches',
    );
  }

  // ============================================
  // Analytics Methods - 分析相关方法
  // ============================================

  /// 启用项目分析
  Future<Map<String, dynamic>> enableProjectAnalytics(String projectId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/analytics/$projectId/enable',
      {},
    );
  }

  /// 获取项目分析追踪代码
  Future<Map<String, dynamic>> getProjectAnalyticsTrackingCode(
    String projectId,
  ) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/$projectId/tracking-code',
    );
  }

  /// 获取项目分析摘要
  Future<Map<String, dynamic>> getProjectAnalyticsSummary(
    String projectId, {
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/$projectId/summary',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 禁用项目分析
  Future<Map<String, dynamic>> disableProjectAnalytics(String projectId) async {
    return _apiClient.delete<Map<String, dynamic>>(
      '/api/analytics/$projectId/disable',
    );
  }

  /// 初始化项目分析
  Future<Map<String, dynamic>> initProjectAnalytics(String projectId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/analytics/$projectId/init',
      {},
    );
  }

  /// 绑定分析用户
  Future<Map<String, dynamic>> bindAnalyticsUser(String projectId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/analytics/$projectId/bind-analytics',
      {},
    );
  }

  // ============================================
  // Umami Data Methods - Umami 数据相关方法
  // ============================================

  /// 获取 Umami 网站信息
  Future<Map<String, dynamic>> getUmamiWebsite(String projectId) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/data/$projectId/website',
    );
  }

  /// 获取 Umami 活跃访客数
  Future<Map<String, dynamic>> getUmamiActiveVisitors(String projectId) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/data/$projectId/website/active',
    );
  }

  /// 获取 Umami 网站值
  Future<Map<String, dynamic>> getUmamiWebsiteValues(
    String projectId, {
    required int startAt,
    required int endAt,
  }) async {
    final queryParams = <String, String>{
      'startAt': startAt.toString(),
      'endAt': endAt.toString(),
    };

    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/data/$projectId/website/values',
      queryParams: queryParams,
    );
  }

  /// 获取 Umami 指标
  Future<List<dynamic>> getUmamiMetrics(
    String projectId,
    Map<String, dynamic> params, {
    List<Map<String, dynamic>>? filters,
  }) async {
    final queryParams = <String, String>{
      'type': params['type'],
      'startAt': params['startAt'].toString(),
      'endAt': params['endAt'].toString(),
      if (params['limit'] != null) 'limit': params['limit'].toString(),
    };

    if (filters != null && filters.isNotEmpty) {
      for (var filter in filters) {
        final key = filter['column'];
        final value = filter['value'];
        final operator = filter['operator'] ?? 'eq';
        final prefix = operator == 'eq'
            ? ''
            : operator == 'neq'
            ? '!'
            : operator == 'c'
            ? '~'
            : '!~';
        queryParams[key] = '$prefix$value';
      }
    }

    return _apiClient.get<List<dynamic>>(
      '/api/analytics/data/$projectId/metrics',
      queryParams: queryParams,
    );
  }

  /// 获取 Umami 页面浏览量
  Future<Map<String, dynamic>> getUmamiPageviews(
    String projectId,
    Map<String, dynamic> params, {
    List<Map<String, dynamic>>? filters,
  }) async {
    final queryParams = <String, String>{
      'unit': params['unit'],
      'timezone': params['timezone'],
      'startAt': params['startAt'].toString(),
      'endAt': params['endAt'].toString(),
    };

    if (filters != null && filters.isNotEmpty) {
      for (var filter in filters) {
        final key = filter['column'];
        final value = filter['value'];
        final operator = filter['operator'] ?? 'eq';
        final prefix = operator == 'eq'
            ? ''
            : operator == 'neq'
            ? '!'
            : operator == 'c'
            ? '~'
            : '!~';
        queryParams[key] = '$prefix$value';
      }
    }

    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/data/$projectId/pageviews',
      queryParams: queryParams,
    );
  }

  /// 获取 Umami 事件
  Future<List<dynamic>> getUmamiEvents(
    String projectId, {
    required int startAt,
    required int endAt,
    List<Map<String, dynamic>>? filters,
  }) async {
    final queryParams = <String, String>{
      'startAt': startAt.toString(),
      'endAt': endAt.toString(),
    };

    if (filters != null && filters.isNotEmpty) {
      for (var filter in filters) {
        final key = filter['column'];
        final value = filter['value'];
        final operator = filter['operator'] ?? 'eq';
        final prefix = operator == 'eq'
            ? ''
            : operator == 'neq'
            ? '!'
            : operator == 'c'
            ? '~'
            : '!~';
        queryParams[key] = '$prefix$value';
      }
    }

    return _apiClient.get<List<dynamic>>(
      '/api/analytics/data/$projectId/events',
      queryParams: queryParams,
    );
  }

  /// 获取 Umami 事件指标
  Future<List<dynamic>> getUmamiEventMetrics(
    String projectId,
    Map<String, dynamic> params, {
    List<Map<String, dynamic>>? filters,
  }) async {
    final queryParams = <String, String>{
      'startAt': params['startAt'].toString(),
      'endAt': params['endAt'].toString(),
      if (params['unit'] != null) 'unit': params['unit'],
      if (params['timezone'] != null) 'timezone': params['timezone'],
    };

    if (filters != null && filters.isNotEmpty) {
      for (var filter in filters) {
        final key = filter['column'];
        final value = filter['value'];
        final operator = filter['operator'] ?? 'eq';
        final prefix = operator == 'eq'
            ? ''
            : operator == 'neq'
            ? '!'
            : operator == 'c'
            ? '~'
            : '!~';
        queryParams[key] = '$prefix$value';
      }
    }

    return _apiClient.get<List<dynamic>>(
      '/api/analytics/data/$projectId/events/series',
      queryParams: queryParams,
    );
  }

  /// 获取 Umami 事件数据统计
  Future<Map<String, dynamic>> getUmamiEventDataStats(
    String projectId, {
    required int startAt,
    required int endAt,
    List<Map<String, dynamic>>? filters,
  }) async {
    final queryParams = <String, String>{
      'startAt': startAt.toString(),
      'endAt': endAt.toString(),
    };

    if (filters != null && filters.isNotEmpty) {
      for (var filter in filters) {
        final key = filter['column'];
        final value = filter['value'];
        final operator = filter['operator'] ?? 'eq';
        final prefix = operator == 'eq'
            ? ''
            : operator == 'neq'
            ? '!'
            : operator == 'c'
            ? '~'
            : '!~';
        queryParams[key] = '$prefix$value';
      }
    }

    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/data/$projectId/event-data/stats',
      queryParams: queryParams,
    );
  }

  /// 获取 Umami 会话数据
  Future<Map<String, dynamic>> getUmamiSessions(
    String projectId,
    Map<String, dynamic> params, {
    List<Map<String, dynamic>>? filters,
  }) async {
    final queryParams = <String, String>{
      'startAt': params['startAt'].toString(),
      'endAt': params['endAt'].toString(),
      if (params['page'] != null) 'page': params['page'].toString(),
      if (params['pageSize'] != null) 'pageSize': params['pageSize'].toString(),
    };

    if (filters != null && filters.isNotEmpty) {
      for (var filter in filters) {
        final key = filter['column'];
        final value = filter['value'];
        final operator = filter['operator'] ?? 'eq';
        final prefix = operator == 'eq'
            ? ''
            : operator == 'neq'
            ? '!'
            : operator == 'c'
            ? '~'
            : '!~';
        queryParams[key] = '$prefix$value';
      }
    }

    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/data/$projectId/sessions',
      queryParams: queryParams,
    );
  }

  /// 获取 Umami 实时数据
  Future<Map<String, dynamic>> getUmamiRealtime(String projectId) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/analytics/data/$projectId/realtime',
    );
  }

  // ============================================
  // GitHub Integration Methods - GitHub 集成方法
  // ============================================

  /// 获取 GitHub 机器人用户名
  Future<Map<String, dynamic>> getGitHubBotUsername() async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/github-import/bot-username',
    );
  }

  /// 接受 GitHub 仓库邀请
  Future<Map<String, dynamic>> acceptGitHubInvitation(
    String repositoryFullName,
  ) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/github-import/accept-invitation',
      {'repository_full_name': repositoryFullName},
    );
  }

  /// 检查仓库访问权限
  Future<Map<String, dynamic>> checkRepositoryAccess(
    String owner,
    String repo,
  ) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/github-import/check-access/$owner/$repo',
    );
  }

  /// 从 GitHub 导入项目
  Future<dynamic> importProjectFromGithub(Map<String, dynamic> payload) async {
    // GitHub collaborator import can take longer due to auto DB migrations + deployment.
    return _apiClient.post(
      '/api/projects/import-from-github',
      payload,
      timeout: const Duration(minutes: 4),
    );
  }

  /// 导入公开仓库到组织
  Future<dynamic> importPublicRepoToOrg(Map<String, dynamic> payload) async {
    return _apiClient.post(
      '/api/projects/import-public-to-org',
      payload,
      timeout: const Duration(minutes: 4),
    );
  }

  // ============================================
  // Payment/Pay Methods - 支付相关方法
  // ============================================

  // ============================================
  // GitHub Ops Methods - GitHub 代码操作（对齐 d1vai web CodeViewer 保存逻辑）
  // ============================================

  /// Sync a file to GitHub and best-effort sync opcode workspace git state.
  ///
  /// Aligns with d1vai web: `POST /api/github-ops/{project_id}/sync-file`
  Future<Map<String, dynamic>> syncFileToGitHub(
    String projectId, {
    required String filePath,
    required String content,
    String? commitMessage,
    String? branch,
  }) async {
    return _apiClient
        .post<Map<String, dynamic>>('/api/github-ops/$projectId/sync-file', {
          'file_path': filePath,
          'content': content,
          if (commitMessage != null) 'commit_message': commitMessage,
          if (branch != null) 'branch': branch,
        }, timeout: const Duration(minutes: 2));
  }

  /// 激活项目支付
  Future<Map<String, dynamic>> activateProjectPay(String projectId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/integrations/activate-pay',
      {},
    );
  }

  /// 获取支付产品列表
  Future<List<dynamic>> getPayProducts(String projectId) async {
    return _apiClient.get<List<dynamic>>(
      '/api/projects/$projectId/pay/products',
    );
  }

  /// 获取支付产品链接
  Future<Map<String, dynamic>> getPayProductPaymentLink(
    String projectId,
    String productId, {
    String? prefilledEmail,
  }) async {
    final queryParams = <String, String>{};
    if (prefilledEmail != null) {
      queryParams['prefilled_email'] = prefilledEmail;
    }

    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/$projectId/pay/products/$productId/payment-link',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 创建支付链接
  Future<Map<String, dynamic>> createPayPaymentLink(
    String projectId, {
    required String productId,
    required String userId,
    required String successUrl,
    required String cancelUrl,
    Map<String, dynamic>? customFields,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/pay/create-payment-link',
      {
        'productId': productId,
        'userId': userId,
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
        if (customFields != null) 'customFields': customFields,
      },
    );
  }

  /// 获取支付交易记录
  Future<List<dynamic>> getPayTransactions(
    String projectId, {
    int? createdAfter,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (createdAfter != null) {
      queryParams['created_after'] = createdAfter.toString();
    }
    if (status != null) queryParams['status'] = status;

    return _apiClient.get<List<dynamic>>(
      '/api/projects/$projectId/pay/transactions',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 获取支付仪表板指标
  Future<Map<String, dynamic>> getPayDashboardMetrics(
    String projectId, {
    String? days,
  }) async {
    final queryParams = <String, String>{};
    if (days != null) queryParams['days'] = days;

    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/$projectId/pay/dashboard/metrics',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 获取支付收入数据
  Future<List<dynamic>> getPayRevenue(String projectId, {String? days}) async {
    final queryParams = <String, String>{};
    if (days != null) queryParams['days'] = days;

    return _apiClient.get<List<dynamic>>(
      '/api/projects/$projectId/pay/dashboard/revenue',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  // ============================================
  // Environment Variables Methods - 环境变量方法
  // ============================================

  /// 列出环境变量
  Future<List<dynamic>> listEnvVars(
    String projectId, {
    bool showValues = false,
  }) async {
    final queryParams = showValues ? {'show_values': 'true'} : null;

    return _apiClient.get<List<dynamic>>(
      '/api/projects/$projectId/env-vars',
      queryParams: queryParams,
    );
  }

  /// 创建环境变量
  Future<Map<String, dynamic>> createEnvVar(
    String projectId,
    Map<String, dynamic> data,
  ) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/env-vars',
      data,
    );
  }

  /// 更新环境变量
  Future<Map<String, dynamic>> updateEnvVar(
    String projectId,
    int varId,
    Map<String, dynamic> data,
  ) async {
    return _apiClient.patch<Map<String, dynamic>>(
      '/api/projects/$projectId/env-vars/$varId',
      data,
    );
  }

  /// 删除环境变量
  Future<void> deleteEnvVar(String projectId, int varId) async {
    await _apiClient.delete('/api/projects/$projectId/env-vars/$varId');
  }

  /// 导出环境变量
  Future<Map<String, dynamic>> exportEnvVars(String projectId) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/$projectId/env-vars/export',
    );
  }

  /// 批量导入环境变量
  Future<Map<String, dynamic>> batchImportEnvVars(
    String projectId,
    Map<String, dynamic> data,
  ) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/env-vars/batch-import',
      data,
    );
  }

  /// 同步环境变量到 Vercel
  Future<Map<String, dynamic>> syncEnvToVercel(String projectId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/env-vars/sync-vercel',
      {},
    );
  }

  // ============================================
  // Deployment Methods - 部署相关方法
  // ============================================

  /// 获取项目部署历史
  Future<Map<String, dynamic>> getProjectDeployments(
    String projectId, {
    String? environment,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (environment != null) queryParams['environment'] = environment;
    if (limit != null) queryParams['limit'] = limit.toString();

    return _apiClient.get<Map<String, dynamic>>(
      '/api/deployment/$projectId/deployments',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 获取部署日志
  Future<Map<String, dynamic>> getDeploymentLogs(
    String vercelDeploymentId,
  ) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/deployment/logs/$vercelDeploymentId',
    );
  }

  /// 获取项目部署历史（带类型转换）
  Future<List<DeploymentHistory>> getProjectDeploymentHistory(
    String projectId, {
    String? environment,
    int? limit,
  }) async {
    final response = await getProjectDeployments(
      projectId,
      environment: environment,
      limit: limit,
    );

    // Try to extract the deployments list from the response
    List<dynamic> deploymentsList = [];
    if (response['data'] != null && response['data'] is List) {
      deploymentsList = response['data'] as List;
    } else if (response['items'] != null && response['items'] is List) {
      deploymentsList = response['items'] as List;
    } else if (response['deployments'] != null &&
        response['deployments'] is List) {
      deploymentsList = response['deployments'] as List;
    }

    return deploymentsList
        .map((item) => DeploymentHistory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 部署到生产环境
  Future<Map<String, dynamic>> deployProjectToProduction(
    String projectId,
  ) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/deployment/$projectId/production',
      {},
    );
  }

  /// 部署预览版本
  Future<Map<String, dynamic>> deployProjectPreview(String projectId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/deployment/$projectId/preview',
      {},
    );
  }

  // ============================================
  // Project Management Methods - 项目管理
  // ============================================

  /// 删除项目（对齐 Web: `DELETE /api/projects/{id}`）
  Future<Map<String, dynamic>> deleteProject(String projectId) async {
    return _apiClient.delete<Map<String, dynamic>>('/api/projects/$projectId');
  }

  /// 转移项目所有权（对齐 Web: `POST /api/projects/{id}/transfer`）
  Future<Map<String, dynamic>> transferProject(
    String projectId, {
    required String targetEmail,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/transfer',
      {'target_email': targetEmail},
    );
  }

  // ============================================
  // Community Methods - 社区发布
  // ============================================

  /// 获取项目对应的社区帖子（对齐 Web: `GET /api/community/projects/{id}/post`）
  Future<dynamic> getCommunityPostForProject(String projectId) async {
    return _apiClient.get<dynamic>('/api/community/projects/$projectId/post');
  }

  /// 创建或更新社区帖子（对齐 Web: `POST /api/community/posts`）
  Future<Map<String, dynamic>> upsertCommunityPost({
    required String projectId,
    required String title,
    required String summary,
    required bool publish,
  }) async {
    return _apiClient.post<Map<String, dynamic>>('/api/community/posts', {
      'project_id': projectId,
      'title': title,
      'summary': summary,
      'publish': publish,
    });
  }

  /// 发布社区帖子（对齐 Web: `POST /api/community/posts/{id}/publish`）
  Future<Map<String, dynamic>> publishCommunityPost(int postId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/community/posts/$postId/publish',
      {},
    );
  }

  /// 取消发布社区帖子（对齐 Web: `POST /api/community/posts/{id}/unpublish`）
  Future<Map<String, dynamic>> unpublishCommunityPost(int postId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/community/posts/$postId/unpublish',
      {},
    );
  }

  // ============================================
  // GitHub Ops Methods - GitHub 操作（用于发布流程）
  // ============================================

  /// 获取分支提交列表（对齐 Web: `GET /api/github-ops/{projectId}/commits`）
  Future<List<dynamic>> getGitHubBranchCommits(
    String projectId, {
    required String branch,
    int limit = 50,
    bool includeStats = false,
  }) async {
    return _apiClient.get<List<dynamic>>(
      '/api/github-ops/$projectId/commits',
      queryParams: {
        'branch': branch,
        'limit': limit.toString(),
        'include_stats': includeStats ? 'true' : 'false',
      },
    );
  }

  /// 合并分支（对齐 Web: `POST /api/github-ops/{projectId}/merge`）
  Future<Map<String, dynamic>> mergeGitHubBranches(
    String projectId, {
    required String baseBranch,
    required String headBranch,
    String? commitMessage,
  }) async {
    return _apiClient
        .post<Map<String, dynamic>>('/api/github-ops/$projectId/merge', {
          'base_branch': baseBranch,
          'head_branch': headBranch,
          if (commitMessage != null) 'commit_message': commitMessage,
        });
  }

  // ============================================
  // Wallet & Billing Methods - 钱包和计费方法
  // ============================================

  /// 获取用户钱包发行记录
  Future<List<dynamic>> getWalletIssuances({int? limit, String? before}) async {
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (before != null) queryParams['before'] = before;

    return _apiClient.get<List<dynamic>>(
      '/api/wallet/credit-issuances',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 创建订阅链接
  Future<Map<String, dynamic>> createSubscribeLink(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/package_order/subscribe-plan-web',
      payload,
    );
  }

  /// 初始化充值
  Future<Map<String, dynamic>> initiateTopup(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/wallet/topup/initiate',
      payload,
    );
  }

  /// 获取用户订单
  Future<List<dynamic>> getUserOrders({
    bool? includeTopups,
    int? limit,
    String? before,
  }) async {
    final queryParams = <String, String>{};
    if (includeTopups != null) {
      queryParams['include_topups'] = includeTopups.toString();
    }
    if (limit != null) queryParams['limit'] = limit.toString();
    if (before != null) queryParams['before'] = before;

    return _apiClient.get<List<dynamic>>(
      '/api/package_order/my-orders',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 获取 LLM 使用量
  Future<Map<String, dynamic>> getLlmUsage(int months) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/billing/usage?months=$months',
    );
  }

  // ============================================
  // Upload & File Methods - 上传和文件方法
  // ============================================

  /// 获取图片上传 token
  Future<Map<String, dynamic>> getImageKitToken(String fileName) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/upload/imagekit/token?file_name=$fileName',
    );
  }

  // ============================================
  // Admin & Invite Methods - 管理和邀请方法
  // ============================================

  /// 检查管理员邀请码
  Future<Map<String, dynamic>> checkAdminInviteCode(String code) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/invites/admin-code/check?code=$code',
    );
  }

  // ============================================
  // Database Consumption Methods - 数据库消耗量方法
  // ============================================

  /// 获取用户所有项目的数据库消耗量
  Future<Map<String, dynamic>> getUserProjectsDbConsumption({
    required String fromIso,
    required String toIso,
    String granularity = 'daily',
  }) async {
    final queryParams = <String, String>{
      'from_iso': fromIso,
      'to_iso': toIso,
      'granularity': granularity,
    };

    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/consumption',
      queryParams: queryParams,
    );
  }

  /// 获取单个项目的数据库消耗量
  Future<Map<String, dynamic>> getProjectDbConsumption(
    String projectId, {
    required String fromIso,
    required String toIso,
    String granularity = 'daily',
  }) async {
    final queryParams = <String, String>{
      'from_iso': fromIso,
      'to_iso': toIso,
      'granularity': granularity,
    };

    return _apiClient.get<Map<String, dynamic>>(
      '/api/projects/$projectId/db/consumption',
      queryParams: queryParams,
    );
  }

  // ============================================
  // Database Integration Methods - 数据库集成方法
  // ============================================

  /// 激活项目数据库
  Future<Map<String, dynamic>> activateProjectDatabase(String projectId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/integrations/activate-database',
      {},
    );
  }

  // ============================================
  // Migration Methods - 迁移相关方法
  // ============================================

  /// 规划迁移
  Future<Map<String, dynamic>> migrationPlan({
    required String projectId,
    String? intent,
    required String proposedSql,
  }) async {
    return _apiClient.post<Map<String, dynamic>>('/api/migrations/plan', {
      'project_id': projectId,
      'intent': intent ?? 'schema_change',
      'proposed_sql': proposedSql,
    });
  }

  /// 验证迁移计划
  Future<Map<String, dynamic>> migrationValidate({
    required String planId,
    String? sql,
  }) async {
    return _apiClient.post<Map<String, dynamic>>('/api/migrations/validate', {
      'plan_id': planId,
      if (sql != null) 'sql': sql,
    });
  }

  /// 创建迁移批准请求
  Future<Map<String, dynamic>> migrationCreateApproval({
    required String planId,
    String? riskSummary,
    int? expiresInMinutes,
  }) async {
    return _apiClient.post<Map<String, dynamic>>('/api/migrations/approvals', {
      'plan_id': planId,
      if (riskSummary != null) 'risk_summary': riskSummary,
      if (expiresInMinutes != null) 'expires_in_minutes': expiresInMinutes,
    });
  }

  /// 自动审查迁移批准
  Future<Map<String, dynamic>> migrationAutoReview(String approvalId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/migrations/approvals/$approvalId/auto-review',
      {},
    );
  }

  /// 手动批准迁移
  Future<Map<String, dynamic>> migrationApprove(String approvalId) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/migrations/approvals/$approvalId/approve',
      {},
    );
  }

  /// 执行迁移
  Future<Map<String, dynamic>> migrationExecute({
    required String planId,
    required String approvalToken,
  }) async {
    return _apiClient.post<Map<String, dynamic>>('/api/migrations/execute', {
      'plan_id': planId,
      'approval_token': approvalToken,
    });
  }

  /// 获取项目迁移历史
  Future<Map<String, dynamic>> getProjectMigrationHistory(
    String projectId, {
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    return _apiClient.get<Map<String, dynamic>>(
      '/api/migrations/history/$projectId',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// 获取迁移计划详情
  Future<Map<String, dynamic>> getMigrationPlanDetail(String planId) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/api/migrations/plans/$planId/detail',
    );
  }

  // ============================================
  // Project Token Methods - 项目令牌方法
  // ============================================

  /// 发行项目令牌
  Future<Map<String, dynamic>> issueProjectToken(
    String projectId, {
    List<String>? scopes,
    int? ttlSeconds,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/project-token/issue',
      {
        if (scopes != null) 'scopes': scopes,
        if (ttlSeconds != null) 'ttl_seconds': ttlSeconds,
      },
    );
  }

  /// 刷新项目令牌
  Future<Map<String, dynamic>> refreshProjectToken(
    String projectId, {
    List<String>? scopes,
    int? ttlSeconds,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/projects/$projectId/project-token/refresh',
      {
        if (scopes != null) 'scopes': scopes,
        if (ttlSeconds != null) 'ttl_seconds': ttlSeconds,
      },
    );
  }
}
