import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';

/// Onboarding 向导组件 - 管理完整的 Onboarding 流程
class OnboardingWizard extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingWizard({super.key, this.onCompleted});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Onboarding 步骤相关
  String _inviteCode = '';
  String _companyName = '';
  String _companyWebsite = '';
  String _industry = '';
  String _avatarUrl = '';

  // UI 状态
  bool _isLoading = false;
  bool _isGeneratingAvatars = false;
  List<String> _aiAvatars = [];

  // 行业列表
  final List<String> _industries = [
    'Technology',
    'Finance',
    'Healthcare',
    'Education',
    'E-commerce',
    'Manufacturing',
    'Media & Entertainment',
    'Real Estate',
    'Energy',
    'Other',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 处理步骤完成
  void _handleNext() async {
    if (_currentStep < 3) {
      // 保存当前步骤数据
      await _saveCurrentStepData();

      // 跳转到下一步
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 完成 Onboarding
      await _completeOnboarding();
    }
  }

  /// 处理返回上一步
  void _handlePrevious() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 保存当前步骤数据
  Future<void> _saveCurrentStepData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    switch (_currentStep) {
      case 0: // 邀请码步骤
        if (_inviteCode.isNotEmpty) {
          await authProvider.acceptInvitation(_inviteCode);
        }
        break;
      case 1: // 公司信息步骤
        if (_companyName.isNotEmpty) {
          await authProvider.saveCompanyInfo(
            _companyName,
            _companyWebsite.isNotEmpty ? _companyWebsite : null,
            _industry.isNotEmpty ? _industry : null,
          );
        }
        break;
      case 2: // 头像步骤
        // 头像已在选择时保存
        break;
    }
  }

  /// 完成 Onboarding
  Future<void> _completeOnboarding() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.completeOnboarding();

      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else {
        // 默认行为：关闭向导
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('完成 Onboarding 失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 生成 AI 头像
  Future<void> _generateAiAvatars() async {
    if (!mounted) return;
    setState(() => _isGeneratingAvatars = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final avatars = await authProvider.generateAiAvatars();
      if (!mounted) return;
      setState(() {
        _aiAvatars = avatars;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('生成 AI 头像失败: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingAvatars = false);
    }
  }

  /// 选择头像
  Future<void> _selectAvatar(String url) async {
    if (!mounted) return;
    setState(() => _avatarUrl = url);
    try {
      final authProvider =
          Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateAvatar(url);
      if (!mounted) return;
      _showSuccess('Avatar updated successfully');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to update avatar: $e');
    }
  }

  /// 从相册选择图片
  Future<void> _pickImageFromGallery() async {
    if (!mounted) return;
    try {
      // 先获取 AuthProvider 引用，避免异步操作中使用 context
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        final file = File(pickedFile.path);
        final bytes = await file.readAsBytes();

        final url = await authProvider.uploadAvatar(
          bytes,
          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (!mounted) return;
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('选择图片失败: $e');
    }
  }

  /// 显示错误消息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// 显示成功消息
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// 构建步骤指示器
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == _currentStep ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index <= _currentStep
                ? Colors.deepPurple
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  /// 构建步骤标题
  Widget _buildStepTitle() {
    final titles = [
      'Welcome to d1v.ai 🎉',
      'Tell us about your organization',
      'Add your avatar',
      'Finish setup',
    ];
    final subtitles = [
      'Enter your invite code to join your team.',
      'This helps us tailor templates and recommendations for your team.',
      'Upload a profile image so collaborators can recognize you at a glance.',
      'You are almost ready to start building.',
    ];

    return Column(
      children: [
        Text(
          titles[_currentStep],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitles[_currentStep],
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 步骤指示器
            _buildStepIndicator(),
            const SizedBox(height: 24),

            // 步骤标题
            _buildStepTitle(),
            const SizedBox(height: 24),

            // 步骤内容
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildInviteStep(),
                  _buildCompanyStep(),
                  _buildAvatarStep(),
                  _buildCompleteStep(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 操作按钮
            Row(
              children: [
                if (_currentStep > 0) ...[
                  TextButton(
                    onPressed: _isLoading ? null : _handlePrevious,
                    child: const Text('上一步'),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _currentStep == 3 ? '完成' : '下一步',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建邀请码步骤
  Widget _buildInviteStep() {
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.card_giftcard, size: 80, color: Colors.deepPurple),
        const SizedBox(height: 24),
        TextField(
          decoration: const InputDecoration(
            labelText: '邀请码',
            hintText: '请输入您的邀请码',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _inviteCode = value;
          },
        ),
        const SizedBox(height: 16),
        Text(
          '提示：邀请码已发送到您的邮箱，请查收',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const Spacer(),
      ],
    );
  }

  /// 构建公司信息步骤
  Widget _buildCompanyStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 公司名称
          TextField(
            decoration: const InputDecoration(
              labelText: '公司名称 *',
              hintText: '请输入您的公司名称',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _companyName = value;
            },
          ),
          const SizedBox(height: 16),

          // 公司网站
          TextField(
            decoration: const InputDecoration(
              labelText: '公司网站',
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _companyWebsite = value;
            },
          ),
          const SizedBox(height: 16),

          // 所属行业
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '所属行业',
              border: OutlineInputBorder(),
            ),
            items: _industries
                .map(
                  (industry) =>
                      DropdownMenuItem(value: industry, child: Text(industry)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _industry = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  /// 构建头像选择步骤
  Widget _buildAvatarStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile picture + description (mirrors web layout)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _avatarUrl.isNotEmpty
                    ? NetworkImage(_avatarUrl) as ImageProvider
                    : null,
                child: _avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 32, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Profile picture',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recommended: square image, PNG/JPG/WEBP, up to 5MB.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // AI Avatar Cards (AI 抽卡)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI Avatar Cards',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _isGeneratingAvatars ? null : _generateAiAvatars,
                    child: _isGeneratingAvatars
                        ? const Text('Generating…')
                        : const Text('AI Random'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_aiAvatars.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _aiAvatars.length,
                  itemBuilder: (context, index) {
                    final avatarUrl = _aiAvatars[index];
                    final isSelected = _avatarUrl == avatarUrl;

                    return GestureDetector(
                      onTap: () => _selectAvatar(avatarUrl),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(avatarUrl),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "AI Random" to draw your AI avatar cards.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 上传头像按钮
          OutlinedButton.icon(
            onPressed: _pickImageFromGallery,
            icon: const Icon(Icons.upload),
            label: const Text('Choose File'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建完成步骤
  Widget _buildCompleteStep() {
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.check_circle, size: 100, color: Colors.green),
        const SizedBox(height: 24),
        const Text(
          '设置完成！',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '欢迎加入 d1vai，您即将进入应用',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
      ],
    );
  }
}
