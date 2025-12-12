import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/avatar_generator.dart';
import '../models/user.dart';
import '../models/onboarding.dart';
import '../services/d1vai_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';
import '../widgets/avatar_image.dart';

class AuthProvider extends ChangeNotifier {
  final D1vaiService _d1vaiService = D1vaiService();
  final StorageService _storageService = StorageService();
  final CacheService _cacheService = CacheService();
  final DeveloperAvatarGenerator _avatarGenerator = DeveloperAvatarGenerator();

  User? _user;
  OnboardingData? _onboardingData;
  bool _isLoading = true;

  User? get user => _user;
  OnboardingData? get onboardingData => _onboardingData;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  /// 检查是否需要完成 onboarding
  bool get needsOnboarding {
    return _user != null && !_user!.isOnboarded;
  }

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    await _storageService.init();
    await _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final token = _storageService.getAuthToken();
      if (token != null) {
        _user = await _d1vaiService.getUserProfile();
        _user = _user?.copyWith(bearerToken: token);

        // 加载 onboarding 数据
        _onboardingData = _storageService.getOnboardingData();

        // 如果用户已完成 onboarding，清理 onboarding 数据
        if (_user?.isOnboarded == true) {
          await _storageService.clearOnboardingData();
          _onboardingData = null;
        }
      }
    } catch (e) {
      // Token invalid or expired
      await logout();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final token = await _d1vaiService.postUserPasswordLogin(email, password);

      if (token == null) {
        throw Exception('Login failed: invalid response');
      }

      await _storageService.saveAuthToken(token);

      _user = await _d1vaiService.getUserProfile();
      _user = _user?.copyWith(bearerToken: token);

      // 检查是否需要 onboarding
      if (_user != null && !_user!.isOnboarded) {
        _onboardingData = OnboardingData();
        await _storageService.saveOnboardingData(_onboardingData!);
      } else {
        _onboardingData = null;
      }

      // 只需调用一次 notifyListeners
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 使用验证码登录
  Future<void> verifyCodeAndLogin(String email, String code) async {
    try {
      final token = await _d1vaiService.postUserLogin(email, code);

      if (token == null) {
        throw Exception('Login failed: invalid response');
      }

      await _storageService.saveAuthToken(token);

      _user = await _d1vaiService.getUserProfile();
      _user = _user?.copyWith(bearerToken: token);

      // 检查是否需要 onboarding
      if (_user != null && !_user!.isOnboarded) {
        _onboardingData = OnboardingData();
        await _storageService.saveOnboardingData(_onboardingData!);
      } else {
        _onboardingData = null;
      }

      // 只需调用一次 notifyListeners
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 发送验证码
  Future<Map<String, dynamic>?> sendVerifyCode(String email) async {
    try {
      final response = await _d1vaiService.postUserVerifyCode(email);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 接受邀请码
  Future<void> acceptInvitation(String code) async {
    try {
      await _d1vaiService.postUserAcceptInvitation(code);

      // 更新 onboarding 数据
      _onboardingData ??= OnboardingData();
      _onboardingData = _onboardingData!.copyWith(inviteCode: code);
      await _storageService.saveOnboardingData(_onboardingData!);

      // 刷新用户信息
      _user = await _d1vaiService.getUserProfile();

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 保存公司信息
  Future<void> saveCompanyInfo(
    String name,
    String? website,
    String? industry,
  ) async {
    try {
      final updatedUser = await _d1vaiService.putUserProfile({
        'company_name': name,
        'company_website': website,
        'industry': industry,
      });

      _user = updatedUser;

      // 更新 onboarding 数据
      _onboardingData ??= OnboardingData();
      _onboardingData = _onboardingData!.copyWith(
        companyName: name,
        companyWebsite: website,
        industry: industry,
      );
      await _storageService.saveOnboardingData(_onboardingData!);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 生成 AI 随机头像列表
  Future<List<String>> generateAiAvatars() async {
    try {
      // 与 web 端保持一致：基于用户信息生成种子，并使用
      // DeveloperAvatarGenerator 生成多风格 AI 头像卡片
      final baseSeed =
          _user?.email ?? _user?.sub ?? 'user-${_user?.id ?? 'guest'}';
      final random = Random(baseSeed.hashCode);

      // 生成 4-6 个头像 URL
      final count = 4 + random.nextInt(3); // 4-6 个
      final avatars = <String>[];

      for (var i = 0; i < count; i++) {
        // 移除时间戳，使用一致性种子生成，确保相同用户生成相同头像列表
        final seed = '$baseSeed-$i-${random.nextInt(1000000)}';
        final avatarUrl = _avatarGenerator.generateAvatar(
          seed,
          size: 160,
          consistent: false,
        );
        avatars.add(avatarUrl);
      }

      return avatars;
    } catch (e) {
      rethrow;
    }
  }

  /// 重新从服务器获取当前用户信息
  Future<void> fetchUser() async {
    try {
      final token = _storageService.getAuthToken();

      if (token == null) {
        _user = null;
      } else {
        final user = await _d1vaiService.getUserProfile();
        _user = user.copyWith(bearerToken: token);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 上传头像
  Future<String> uploadAvatar(Uint8List imageBytes, String fileName) async {
    try {
      final avatarUrl = await _d1vaiService.postUserAvatarUpload(
        imageBytes,
        fileName,
      );

      // 更新用户信息
      final updatedUser = await _d1vaiService.putUserProfile({
        'picture': avatarUrl,
      });
      _user = updatedUser;

      // 更新 onboarding 数据
      _onboardingData ??= OnboardingData();
      _onboardingData = _onboardingData!.copyWith(avatarUrl: avatarUrl);

      notifyListeners();
      return avatarUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// 使用已上传的头像 URL 更新当前用户头像
  Future<void> updateAvatar(String avatarUrl) async {
    try {
      if (_user == null) return;

      // 清除旧头像缓存
      if (_user!.picture.isNotEmpty) {
        AvatarImage.clearCache(_user!.picture);
      }

      final updatedUser = await _d1vaiService.putUserProfile({
        'picture': avatarUrl,
      });

      _user = updatedUser;

      // 同步更新本地 onboarding 数据中的头像
      _onboardingData ??= OnboardingData();
      _onboardingData = _onboardingData!.copyWith(avatarUrl: avatarUrl);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 完成 onboarding
  Future<void> completeOnboarding() async {
    try {
      await _d1vaiService.postUserOnboardedSet(true);

      _user = await _d1vaiService.getUserProfile();

      // 清理 onboarding 数据
      await _storageService.clearOnboardingData();
      _onboardingData = null;

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    try {
      if (_user != null) {
        final token = _storageService.getAuthToken();
        _user = await _d1vaiService.getUserProfile();
        _user = _user?.copyWith(bearerToken: token);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh user error: $e');
      rethrow;
    }
  }

  /// 更新 onboarding 步骤
  Future<void> updateOnboardingStep(OnboardingStep step) async {
    _onboardingData ??= OnboardingData();
    _onboardingData = _onboardingData!.copyWith(currentStep: step);
    await _storageService.saveOnboardingData(_onboardingData!);
    notifyListeners();
  }

  /// 登出
  Future<void> logout() async {
    try {
      // 清除认证相关数据
      await _storageService.clearAuthToken();
      await _storageService.clearOnboardingData();

      // 清除所有缓存数据
      await _cacheService.clear();

      // 清除头像生成器缓存
      _avatarGenerator.clearCache();

      // 重置状态
      _user = null;
      _onboardingData = null;
      _isLoading = false;

      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      // 即使出错也要重置状态
      _user = null;
      _onboardingData = null;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
