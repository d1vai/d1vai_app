import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../models/user.dart';
import '../widgets/login_required_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showLoginRequiredDialog();
      } else {
        Provider.of<ProfileProvider>(context, listen: false).initForm(user);
      }
    });
  }

  /// 显示登录提示对话框
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              if (profileProvider.isEditing) {
                return IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    final user = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).user;
                    profileProvider.cancelEdit(user);
                  },
                );
              }
              return IconButton(
                icon: const Icon(Icons.edit),
                onPressed: profileProvider.toggleEditMode,
              );
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, ProfileProvider>(
        builder: (context, authProvider, profileProvider, child) {
          final user = authProvider.user;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileProvider.isEditing) {
            return _buildEditMode(context, user, profileProvider);
          } else {
            return _buildViewMode(context, user, profileProvider);
          }
        },
      ),
    );
  }

  /// 构建查看模式
  Widget _buildViewMode(
    BuildContext context,
    User user,
    ProfileProvider profileProvider,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 头像区域
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: user.picture.isNotEmpty
                    ? CachedNetworkImageProvider(user.picture)
                    : null,
                child: user.picture.isEmpty
                    ? Text(
                        user.companyName.isNotEmpty
                            ? user.companyName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () =>
                        _showAvatarOptions(context, profileProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 基本信息
        _buildSectionTitle('Basic Information'),
        const SizedBox(height: 12),
        _buildInfoCard(
          'Company Name',
          user.companyName.isNotEmpty ? user.companyName : 'Not set',
          Icons.business,
        ),
        _buildInfoCard('Email', user.email ?? 'Not set', Icons.email),
        _buildInfoCard(
          'Industry',
          user.industry.isNotEmpty ? user.industry : 'Not set',
          Icons.work,
        ),
        if (user.companyWebsite.isNotEmpty)
          _buildInfoCard(
            'Website',
            user.companyWebsite,
            Icons.language,
            isLink: true,
          ),

        const SizedBox(height: 24),

        // 钱包地址
        _buildSectionTitle('Wallet Addresses'),
        const SizedBox(height: 12),
        _buildWalletCard('SOL Wallet', user.solWallet, Icons.currency_bitcoin),
        _buildWalletCard('SUI Wallet', user.suiWallet, Icons.wallet),
        _buildWalletCard(
          'EVM Wallet',
          user.evmWallet,
          Icons.account_balance_wallet,
        ),

        const SizedBox(height: 24),

        // 其他信息
        _buildSectionTitle('Other'),
        const SizedBox(height: 12),
        _buildInfoCard('Referral Code', user.referralCode, Icons.card_giftcard),
        _buildInfoCard('Invite Code', user.inviteCode, Icons.group_add),

        const SizedBox(height: 24),

        // 编辑按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: profileProvider.toggleEditMode,
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建编辑模式
  Widget _buildEditMode(
    BuildContext context,
    User user,
    ProfileProvider profileProvider,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 头像区域
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: user.picture.isNotEmpty
                    ? CachedNetworkImageProvider(user.picture)
                    : null,
                child: user.picture.isEmpty
                    ? Text(
                        user.companyName.isNotEmpty
                            ? user.companyName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () =>
                        _showAvatarOptions(context, profileProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 错误提示
        if (profileProvider.error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profileProvider.error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: profileProvider.clearError,
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // 编辑表单
        _buildSectionTitle('Basic Information'),
        const SizedBox(height: 12),
        TextField(
          controller: profileProvider.companyNameController,
          decoration: const InputDecoration(
            labelText: 'Company Name *',
            hintText: 'Enter your company name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: profileProvider.companyWebsiteController,
          decoration: const InputDecoration(
            labelText: 'Company Website',
            hintText: 'https://example.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.language),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: profileProvider.industryController,
          decoration: const InputDecoration(
            labelText: 'Industry *',
            hintText: 'Enter your industry',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.work),
          ),
        ),

        const SizedBox(height: 24),

        // 钱包地址
        _buildSectionTitle('Wallet Addresses'),
        const SizedBox(height: 12),
        TextField(
          controller: profileProvider.solWalletController,
          decoration: const InputDecoration(
            labelText: 'SOL Wallet',
            hintText: 'Enter your SOL wallet address',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_bitcoin),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: profileProvider.suiWalletController,
          decoration: const InputDecoration(
            labelText: 'SUI Wallet',
            hintText: 'Enter your SUI wallet address',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.wallet),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: profileProvider.evmWalletController,
          decoration: const InputDecoration(
            labelText: 'EVM Wallet',
            hintText: 'Enter your EVM wallet address',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
        ),

        const SizedBox(height: 32),

        // 保存按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: profileProvider.isSaving
                ? null
                : () async {
                    final validation = profileProvider.validateForm();
                    if (validation != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(validation)));
                      return;
                    }

                    final success = await profileProvider.saveProfile();
                    if (!context.mounted) return;

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully'),
                        ),
                      );

                      // 刷新用户数据
                      await Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).fetchUser();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            profileProvider.error ?? 'Failed to update profile',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
            icon: profileProvider.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              profileProvider.isSaving ? 'Saving...' : 'Save Changes',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// 显示头像选择选项
  void _showAvatarOptions(
    BuildContext context,
    ProfileProvider profileProvider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    await _handleAvatarUpload(image, profileProvider);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    await _handleAvatarUpload(image, profileProvider);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('AI Random'),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleAiAvatarGeneration(profileProvider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 处理头像上传
  Future<void> _handleAvatarUpload(
    XFile image,
    ProfileProvider profileProvider,
  ) async {
    final avatarUrl = await profileProvider.uploadAvatar(image);
    if (!mounted || avatarUrl == null) return;

    // 更新用户头像
    await Provider.of<AuthProvider>(
      context,
      listen: false,
    ).updateAvatar(avatarUrl);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar updated successfully')),
    );
  }

  /// 处理AI头像生成
  Future<void> _handleAiAvatarGeneration(
    ProfileProvider profileProvider,
  ) async {
    final avatars = await profileProvider.generateAiAvatars();
    if (!mounted) return;

    if (avatars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileProvider.error ?? 'Failed to generate avatars'),
        ),
      );
      return;
    }

    if (!mounted || avatars.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('AI Avatar Cards'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                final avatarUrl = avatars[index];
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(dialogContext);

                    if (!mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await authProvider.updateAvatar(avatarUrl);

                    if (!mounted) return;

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Avatar updated successfully'),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 构建区块标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  /// 构建信息卡片
  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon, {
    bool isLink = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(label),
        subtitle: isLink
            ? GestureDetector(
                onTap: () => {/* TODO: Open link */},
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            : Text(value),
        trailing: isLink ? const Icon(Icons.open_in_new, size: 16) : null,
      ),
    );
  }

  /// 构建钱包卡片
  Widget _buildWalletCard(String label, String address, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(label),
        subtitle: Text(
          address.isNotEmpty ? address : 'Not set',
          style: TextStyle(
            color: address.isNotEmpty ? null : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
