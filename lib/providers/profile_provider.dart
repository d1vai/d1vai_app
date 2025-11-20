import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/avatar_generator.dart';
import '../models/user.dart';
import '../services/d1vai_service.dart';

/// Profile Provider - 管理个人资料状态和编辑
class ProfileProvider extends ChangeNotifier {
  // 编辑状态
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  User? _user;

  // 表单控制器
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController companyWebsiteController =
      TextEditingController();
  final TextEditingController industryController = TextEditingController();
  final TextEditingController solWalletController = TextEditingController();
  final TextEditingController suiWalletController = TextEditingController();
  final TextEditingController evmWalletController = TextEditingController();

  // Getter
  bool get isEditing => _isEditing;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  final DeveloperAvatarGenerator _avatarGenerator = DeveloperAvatarGenerator();

  /// 初始化表单数据
  void initForm(User? user) {
    _user = user;
    if (user != null) {
      companyNameController.text = user.companyName;
      companyWebsiteController.text = user.companyWebsite;
      industryController.text = user.industry;
      solWalletController.text = user.solWallet;
      suiWalletController.text = user.suiWallet;
      evmWalletController.text = user.evmWallet;
    }
  }

  /// 切换编辑模式
  void toggleEditMode() {
    _isEditing = !_isEditing;
    notifyListeners();
  }

  /// 取消编辑
  void cancelEdit(User? user) {
    _isEditing = false;
    if (user != null) {
      initForm(user);
    }
    _error = null;
    notifyListeners();
  }

  /// 上传头像
  Future<String?> uploadAvatar(XFile imageFile) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final apiClient = ApiClient();
      final fileBytes = await imageFile.readAsBytes();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final avatarUrl = await apiClient.uploadFile(fileBytes, fileName);

      return avatarUrl;
    } catch (e) {
      _error = '上传头像失败: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存用户信息
  Future<bool> saveProfile() async {
    try {
      _isSaving = true;
      _error = null;
      notifyListeners();

      // 使用 D1vaiService 更新用户资料
      final d1vaiService = D1vaiService();
      await d1vaiService.putUserProfile({
        'company_name': companyNameController.text,
        'company_website': companyWebsiteController.text.isEmpty
            ? null
            : companyWebsiteController.text,
        'industry': industryController.text,
        'sol_wallet': solWalletController.text,
        'sui_wallet': suiWalletController.text,
        'evm_wallet': evmWalletController.text,
      });

      _isEditing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '保存失败: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 验证表单
  String? validateForm() {
    if (companyNameController.text.trim().isEmpty) {
      return '请输入公司名称';
    }
    if (industryController.text.trim().isEmpty) {
      return '请输入行业信息';
    }
    return null;
  }

  /// 生成AI头像
  Future<List<String>> generateAiAvatars() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      // 与 web 端保持一致：基于用户信息生成种子，并使用
      // DeveloperAvatarGenerator 生成多风格 AI 头像卡片
      final baseSeed =
          _user?.email ?? _user?.sub ?? 'user-${_user?.id ?? 'guest'}';
      final random = Random(baseSeed.hashCode);

      final count = 4 + random.nextInt(3); // 4-6 个
      final avatars = <String>[];

      for (var i = 0; i < count; i++) {
        // 移除时间戳，使用一致性种子生成
        final seed = '$baseSeed-$i-${random.nextInt(1000000)}';
        final url = _avatarGenerator.generateAvatar(
          seed,
          size: 160,
          consistent: false,
        );
        avatars.add(url);
      }

      return avatars;
    } catch (e) {
      _error = '生成头像失败: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    companyNameController.dispose();
    companyWebsiteController.dispose();
    industryController.dispose();
    solWalletController.dispose();
    suiWalletController.dispose();
    evmWalletController.dispose();
    super.dispose();
  }
}

/// 用户资料更新请求
class ProfileUpdateRequest {
  final String? companyName;
  final String? companyWebsite;
  final String? industry;
  final String? picture;
  final String? solWallet;
  final String? suiWallet;
  final String? evmWallet;

  const ProfileUpdateRequest({
    this.companyName,
    this.companyWebsite,
    this.industry,
    this.picture,
    this.solWallet,
    this.suiWallet,
    this.evmWallet,
  });

  Map<String, dynamic> toJson() {
    return {
      if (companyName != null) 'company_name': companyName,
      if (companyWebsite != null) 'company_website': companyWebsite,
      if (industry != null) 'industry': industry,
      if (picture != null) 'picture': picture,
      if (solWallet != null) 'sol_wallet': solWallet,
      if (suiWallet != null) 'sui_wallet': suiWallet,
      if (evmWallet != null) 'evm_wallet': evmWallet,
    };
  }
}
