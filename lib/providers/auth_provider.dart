import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/onboarding.dart';
import '../services/d1vai_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final D1vaiService _d1vaiService = D1vaiService();
  final StorageService _storageService = StorageService();

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

      await _storageService.saveAuthToken(token);

      _user = await _d1vaiService.getUserProfile();
      _user = _user?.copyWith(bearerToken: token);

      // 检查是否需要 onboarding
      if (_user != null && !_user!.isOnboarded) {
        _onboardingData = OnboardingData();
        await _storageService.saveOnboardingData(_onboardingData!);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 使用验证码登录
  Future<void> verifyCodeAndLogin(String email, String code) async {
    try {
      final token = await _d1vaiService.postUserLogin(email, code);

      await _storageService.saveAuthToken(token);

      _user = await _d1vaiService.getUserProfile();
      _user = _user?.copyWith(bearerToken: token);

      // 检查是否需要 onboarding
      if (_user != null && !_user!.isOnboarded) {
        _onboardingData = OnboardingData();
        await _storageService.saveOnboardingData(_onboardingData!);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 发送验证码
  Future<Map<String, dynamic>> sendVerifyCode(String email) async {
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
  Future<void> saveCompanyInfo(String name, String? website, String? industry) async {
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
      // 生成基于用户信息的随机种子
      final seed = _user?.email ?? _user?.sub ?? 'user';
      final random = Random(seed.hashCode);

      // 生成 4-6 个头像 URL（这里使用 DiceBear API 作为示例）
      final count = 4 + random.nextInt(3); // 4-6 个
      final avatars = <String>[];

      for (int i = 0; i < count; i++) {
        final avatarSeed = '$seed-${DateTime.now().millisecondsSinceEpoch}-$i-${random.nextInt(10000)}';
        // 使用 DiceBear 头像生成服务
        final avatarUrl = 'https://api.dicebear.com/7.x/avataaars/svg?seed=$avatarSeed&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc';
        avatars.add(avatarUrl);
      }

      return avatars;
    } catch (e) {
      rethrow;
    }
  }

  /// 上传头像
  Future<String> uploadAvatar(Uint8List imageBytes, String fileName) async {
    try {
      final avatarUrl = await _d1vaiService.postUserAvatarUpload(imageBytes, fileName);

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

  /// 更新 onboarding 步骤
  Future<void> updateOnboardingStep(OnboardingStep step) async {
    _onboardingData ??= OnboardingData();
    _onboardingData = _onboardingData!.copyWith(currentStep: step);
    await _storageService.saveOnboardingData(_onboardingData!);
    notifyListeners();
  }

  /// 登出
  Future<void> logout() async {
    await _storageService.clearAuthToken();
    await _storageService.clearOnboardingData();

    _user = null;
    _onboardingData = null;
    _isLoading = false;

    notifyListeners();
  }
}

