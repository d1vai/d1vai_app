import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import 'ai_avatar_selector_dialog.dart';
import 'avatar_image.dart';
import 'button.dart' as d1v;
import 'snackbar_helper.dart';

/// Onboarding 向导组件 - 管理完整的 Onboarding 流程
class OnboardingWizard extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingWizard({super.key, this.onCompleted});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  late final AnimationController _enterController;
  late final AnimationController _breathController;

  // Onboarding 步骤相关
  String _inviteCode = '';
  String _companyName = '';
  String _companyWebsite = '';
  String _industry = '';
  String _avatarUrl = '';

  // UI 状态
  bool _isLoading = false;
  bool _isGeneratingAvatars = false;
  final List<String> _aiAvatars = [];

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
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _enterController.dispose();
    _breathController.dispose();
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
      HapticFeedback.selectionClick();
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
      HapticFeedback.selectionClick();
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

  /// 生成 AI 头像 - 显示带动画的选择对话框
  Future<void> _generateAiAvatars() async {
    if (!mounted) return;

    setState(() => _isGeneratingAvatars = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final avatars = await authProvider.generateAiAvatars();

      if (!mounted) return;

      setState(() => _isGeneratingAvatars = false);

      if (avatars.isEmpty) {
        _showError('生成 AI 头像失败');
        return;
      }

      // 显示带动画的 AI Avatar 选择对话框
      if (!mounted) return;


      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // 将状态变量移到 StatefulBuilder 外部
          List<String> currentAvatars = List.from(avatars);
          bool isGenerating = false;

          return StatefulBuilder(
            builder: (dialogContext, dialogSetState) {
              return AiAvatarSelectorDialog(
                avatars: currentAvatars,
                selectedAvatar: _avatarUrl.isEmpty ? null : _avatarUrl,
                isGenerating: isGenerating,
                onSelect: (selectedAvatarUrl) async {
                  // 先关闭对话框，避免 Hero tag 冲突
                  Navigator.of(dialogContext).pop();
                  
                  if (!mounted) return;

                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);

                  try {
                    await authProvider.updateAvatar(selectedAvatarUrl);

                    if (!mounted) return;

                    setState(() => _avatarUrl = selectedAvatarUrl);
                    
                    // 等待一帧，确保对话框完全关闭
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    if (!mounted) return;
                    _showSuccess('头像选择成功');
                  } catch (e) {
                    if (!mounted) return;
                    
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    if (!mounted) return;
                    _showError('选择头像失败: $e');
                  }
                },
                onRefresh: () async {
                  dialogSetState(() {
                    isGenerating = true;
                  });

                  try {
                    final authProvider =
                        Provider.of<AuthProvider>(context, listen: false);
                    final newAvatars = await authProvider.generateAiAvatars();

                    if (!dialogContext.mounted) return;

                    dialogSetState(() {
                      currentAvatars.clear();
                      currentAvatars.addAll(newAvatars);
                      isGenerating = false;
                    });
                  } catch (e) {
                    if (!dialogContext.mounted) return;

                    dialogSetState(() {
                      isGenerating = false;
                    });

                    if (!mounted) return;
                    _showError('刷新头像失败: $e');
                  }
                },
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeneratingAvatars = false);
      _showError('生成 AI 头像失败: $e');
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
    SnackBarHelper.showError(
      context,
      title: 'Error',
      message: message,
    );
  }

  /// 显示成功消息
  void _showSuccess(String message) {
    SnackBarHelper.showSuccess(
      context,
      title: 'Success',
      message: message,
    );
  }

  /// 构建步骤指示器
  Widget _buildStepIndicator(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        final t = _breathController.value;
        final accent = Color.lerp(colorScheme.primary, colorScheme.secondary, 0.3)!;
        final glow = accent.withValues(alpha: isDark ? (0.10 + 0.10 * t) : (0.08 + 0.08 * t));
        final inactive = colorScheme.outlineVariant.withValues(alpha: 0.55);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isCurrent = index == _currentStep;
            final isDone = index < _currentStep;

            final double width = isCurrent ? (28.0 + 4.0 * t) : 8.0;
            final double height = 8.0;
            final bg = isDone
                ? colorScheme.tertiary.withValues(alpha: 0.85)
                : isCurrent
                    ? accent
                    : inactive;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: glow,
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }

  /// 构建步骤标题
  Widget _buildStepTitle(ThemeData theme) {
    final colorScheme = theme.colorScheme;
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey(_currentStep),
        children: [
          Text(
            titles[_currentStep],
            style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ) ??
                const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitles[_currentStep],
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  height: 1.25,
                ) ??
                TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  height: 1.25,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final maxH = MediaQuery.sizeOf(context).height * 0.76;
    final bg = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
      colorScheme.surface,
    );
    final border = colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.55);

    final enter = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    final scale = Tween<double>(begin: 0.98, end: 1).animate(enter);

    final primaryButton = AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        final t = _isLoading ? 0.0 : _breathController.value;
        final glow = colorScheme.primary.withValues(alpha: 0.10 + 0.10 * t);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isLoading
                ? null
                : [
                    BoxShadow(
                      color: glow,
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: d1v.Button(
        text: _currentStep == 3 ? '完成' : '下一步',
        onPressed: _isLoading ? null : _handleNext,
        height: 48,
        borderRadius: 14,
      ),
    );

    final secondaryButton = _currentStep > 0
        ? d1v.Button(
            variant: d1v.ButtonVariant.outline,
            text: '上一步',
            onPressed: _isLoading ? null : _handlePrevious,
            height: 48,
            borderRadius: 14,
          )
        : null;

    return FadeTransition(
      opacity: enter,
      child: ScaleTransition(
        scale: scale,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(maxWidth: 520, maxHeight: maxH),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                _buildStepIndicator(theme),
                const SizedBox(height: 18),
                _buildStepTitle(theme),
                const SizedBox(height: 16),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (secondaryButton != null) ...[
                      Expanded(child: secondaryButton),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: primaryButton),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建邀请码步骤
  Widget _buildInviteStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        const Spacer(),
        AnimatedBuilder(
          animation: _breathController,
          builder: (context, child) {
            final t = _breathController.value;
            final c = Color.lerp(
              colorScheme.primary,
              colorScheme.secondary,
              0.25 + 0.25 * t,
            )!;
            return Icon(Icons.card_giftcard, size: 72, color: c);
          },
        ),
        const SizedBox(height: 24),
        TextField(
          decoration: InputDecoration(
            labelText: '邀请码',
            hintText: '请输入您的邀请码',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          onChanged: (value) {
            _inviteCode = value;
          },
        ),
        const SizedBox(height: 16),
        Text(
          '提示：邀请码已发送到您的邮箱，请查收',
          style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              ) ??
              TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
      ],
    );
  }

  /// 构建公司信息步骤
  Widget _buildCompanyStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 公司名称
          TextField(
            decoration: InputDecoration(
              labelText: '公司名称 *',
              hintText: '请输入您的公司名称',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            onChanged: (value) {
              _companyName = value;
            },
          ),
          const SizedBox(height: 16),

          // 公司网站
          TextField(
            decoration: InputDecoration(
              labelText: '公司网站',
              hintText: 'https://example.com',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            onChanged: (value) {
              _companyWebsite = value;
            },
          ),
          const SizedBox(height: 16),

          // 所属行业
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: '所属行业',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          const SizedBox(height: 10),
          Text(
            '这将帮助我们提供更适合你的模板与建议。',
            style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                ) ??
                TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }

  /// 构建头像选择步骤
  Widget _buildAvatarStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile picture + description (mirrors web layout)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AvatarImage(
                key: ValueKey(_avatarUrl), // 添加 key 以确保头像更新时重新构建
                imageUrl: _avatarUrl.isEmpty ? 'placeholder' : _avatarUrl,
                size: 64,
                borderRadius: BorderRadius.circular(32),
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile picture',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ) ??
                          const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recommended: square image, PNG/JPG/WEBP, up to 5MB.',
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.9,
                            ),
                          ) ??
                          TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.9,
                            ),
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
                  Text(
                    'AI Avatar Cards',
                    style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ) ??
                        const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  AnimatedBuilder(
                    animation: _breathController,
                    builder: (context, child) {
                      final t = _isGeneratingAvatars ? 0.0 : _breathController.value;
                      final fg = Color.lerp(
                        colorScheme.primary,
                        colorScheme.secondary,
                        0.2 + 0.35 * t,
                      )!;
                      return TextButton(
                        onPressed: _isGeneratingAvatars ? null : _generateAiAvatars,
                        style: TextButton.styleFrom(foregroundColor: fg),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: Text(
                            _isGeneratingAvatars ? 'Generating…' : 'AI Random',
                            key: ValueKey(_isGeneratingAvatars),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      );
                    },
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
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.7,
                                  ),
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: AvatarImage(
                          imageUrl: avatarUrl,
                          size: 60,
                          borderRadius: BorderRadius.circular(30),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 40,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "AI Random" to draw your AI avatar cards.',
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.9,
                              ),
                            ) ??
                            TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.9,
                              ),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 上传头像按钮
          d1v.Button(
            variant: d1v.ButtonVariant.outline,
            icon: Icon(Icons.upload, color: colorScheme.onSurface),
            text: '选择文件',
            onPressed: _pickImageFromGallery,
            height: 48,
            borderRadius: 14,
          ),
        ],
      ),
    );
  }

  /// 构建完成步骤
  Widget _buildCompleteStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        const Spacer(),
        AnimatedBuilder(
          animation: _breathController,
          builder: (context, child) {
            final t = _breathController.value;
            return Transform.scale(
              scale: 0.98 + 0.03 * t,
              child: Icon(
                Icons.check_circle_rounded,
                size: 96,
                color: colorScheme.tertiary,
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          '设置完成！',
          style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ) ??
              const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          '欢迎加入 d1vai，您即将进入应用',
          style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              ) ??
              TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
      ],
    );
  }
}
