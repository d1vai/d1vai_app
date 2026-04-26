import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding.dart';
import '../models/user.dart';

/// 本地存储服务 - 管理应用程序的本地数据存储
class StorageService {
  static const String _onboardingKey = 'onboarding_data';
  static const String _authTokenKey = 'auth_token';
  static const String _authUserKey = 'auth_user';

  // 单例模式
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  /// 初始化存储服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// SharedPreferences 实例（仅供内部使用）
  SharedPreferences get _sharedPrefs => _prefs;

  // ============================================
  // Onboarding 数据持久化
  // ============================================

  /// 保存 Onboarding 数据
  Future<bool> saveOnboardingData(OnboardingData data) async {
    try {
      final jsonString = jsonEncode(data.toJson());
      return await _sharedPrefs.setString(_onboardingKey, jsonString);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 获取 Onboarding 数据
  OnboardingData? getOnboardingData() {
    try {
      final jsonString = _sharedPrefs.getString(_onboardingKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        return OnboardingData.fromJson(json);
      }
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
    }
    return null;
  }

  /// 清除 Onboarding 数据
  Future<bool> clearOnboardingData() async {
    try {
      return await _sharedPrefs.remove(_onboardingKey);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 检查是否有未完成的 Onboarding 数据
  bool hasIncompleteOnboarding() {
    final data = getOnboardingData();
    return data != null && !data.isCompleted;
  }

  // ============================================
  // 认证令牌管理
  // ============================================

  /// 保存认证令牌
  Future<bool> saveAuthToken(String token) async {
    try {
      return await _sharedPrefs.setString(_authTokenKey, token);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 获取认证令牌
  String? getAuthToken() {
    return _sharedPrefs.getString(_authTokenKey);
  }

  /// 清除认证令牌
  Future<bool> clearAuthToken() async {
    try {
      return await _sharedPrefs.remove(_authTokenKey);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 检查是否有认证令牌
  bool hasAuthToken() {
    return _sharedPrefs.containsKey(_authTokenKey);
  }

  /// 保存最近一次成功同步的用户信息，便于开发期后端重启后恢复会话。
  Future<bool> saveAuthUser(User user) async {
    try {
      return await _sharedPrefs.setString(_authUserKey, jsonEncode(user.toJson()));
    } catch (e) {
      return false;
    }
  }

  /// 获取本地缓存的用户信息。
  User? getAuthUser() {
    try {
      final jsonString = _sharedPrefs.getString(_authUserKey);
      if (jsonString == null || jsonString.isEmpty) return null;
      final json = jsonDecode(jsonString);
      if (json is Map<String, dynamic>) {
        return User.fromJson(json);
      }
      if (json is Map) {
        return User.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (e) {
      // Ignore malformed cache.
    }
    return null;
  }

  /// 清除缓存的用户信息。
  Future<bool> clearAuthUser() async {
    try {
      return await _sharedPrefs.remove(_authUserKey);
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // 通用数据存储
  // ============================================

  /// 保存字符串
  Future<bool> setString(String key, String value) async {
    try {
      return await _sharedPrefs.setString(key, value);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 获取字符串
  String? getString(String key) {
    return _sharedPrefs.getString(key);
  }

  /// 保存布尔值
  Future<bool> setBool(String key, bool value) async {
    try {
      return await _sharedPrefs.setBool(key, value);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 获取布尔值
  bool? getBool(String key) {
    return _sharedPrefs.getBool(key);
  }

  /// 保存整数
  Future<bool> setInt(String key, int value) async {
    try {
      return await _sharedPrefs.setInt(key, value);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 获取整数
  int? getInt(String key) {
    return _sharedPrefs.getInt(key);
  }

  /// 保存双精度浮点数
  Future<bool> setDouble(String key, double value) async {
    try {
      return await _sharedPrefs.setDouble(key, value);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 获取双精度浮点数
  double? getDouble(String key) {
    return _sharedPrefs.getDouble(key);
  }

  /// 保存字符串列表
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      return await _sharedPrefs.setStringList(key, value);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 获取字符串列表
  List<String>? getStringList(String key) {
    return _sharedPrefs.getStringList(key);
  }

  /// 移除指定键
  Future<bool> remove(String key) async {
    try {
      return await _sharedPrefs.remove(key);
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 检查是否包含指定键
  bool containsKey(String key) {
    return _sharedPrefs.containsKey(key);
  }

  /// 获取所有键
  Set<String> getKeys() {
    return _sharedPrefs.getKeys();
  }

  /// 清除所有数据
  Future<bool> clear() async {
    try {
      return await _sharedPrefs.clear();
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
      return false;
    }
  }

  /// 重新加载数据
  Future<void> reload() async {
    try {
      await _sharedPrefs.reload();
    } catch (e) {
      // 在生产环境中，应该使用日志记录而不是 print
    }
  }

  @override
  String toString() {
    return 'StorageService(initialized: true)';
  }
}
