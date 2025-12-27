import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'avatar_image.dart';
import 'button.dart' as d1v;

/// AI Avatar 选择对话框 - 带有优雅的动画效果
class AiAvatarSelectorDialog extends StatefulWidget {
  final List<String> avatars;
  final String? selectedAvatar;
  final Function(String) onSelect;
  final VoidCallback onRefresh;
  final bool isGenerating;
  final bool enableBreathing;

  const AiAvatarSelectorDialog({
    super.key,
    required this.avatars,
    this.selectedAvatar,
    required this.onSelect,
    required this.onRefresh,
    this.isGenerating = false,
    this.enableBreathing = true,
  });

  @override
  State<AiAvatarSelectorDialog> createState() => _AiAvatarSelectorDialogState();
}

class _AiAvatarSelectorDialogState extends State<AiAvatarSelectorDialog>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<Offset>> _slideAnimations;
  late final AnimationController _breathController;
  late final AnimationController _spinController;

  String? _selectedAvatar;
  List<String> _currentAvatars = [];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.selectedAvatar;
    _currentAvatars = List.from(widget.avatars);
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.enableBreathing) {
      _breathController.repeat(reverse: true);
    }
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isGenerating) {
      _spinController.repeat();
    }
    _initializeAnimations();
    _startStaggeredAnimation();
  }

  @override
  void didUpdateWidget(AiAvatarSelectorDialog oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enableBreathing != widget.enableBreathing) {
      if (widget.enableBreathing) {
        _breathController.repeat(reverse: true);
      } else {
        _breathController.stop();
        _breathController.value = 0;
      }
    }

    if (oldWidget.isGenerating != widget.isGenerating) {
      if (widget.isGenerating) {
        _spinController.repeat();
      } else {
        _spinController.stop();
        _spinController.value = 0;
      }
    }

    // 检测到新的头像列表（使用内容比较而不是引用比较）
    if (widget.avatars.isNotEmpty &&
        !_listEquals(widget.avatars, _currentAvatars)) {
      _refreshAvatars();
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _initializeAnimations() {
    final count = widget.avatars.length;
    _controllers = List.generate(
      count,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOut,
        ),
      );
    }).toList();

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ),
      );
    }).toList();

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        ),
      );
    }).toList();
  }

  void _startStaggeredAnimation() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  Future<void> _refreshAvatars() async {
    // 淡出动画
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          _controllers[i].reverse();
        }
      });
    }

    // 等待淡出完成
    await Future.delayed(
      Duration(milliseconds: _controllers.length * 50 + 300),
    );

    if (!mounted) return;

    // 更新头像列表
    setState(() {
      _currentAvatars = List.from(widget.avatars);
    });

    // 重新初始化动画控制器（如果数量变化）
    if (widget.avatars.length != _controllers.length) {
      for (var controller in _controllers) {
        controller.dispose();
      }
      _initializeAnimations();
    }

    // 淡入动画
    _startStaggeredAnimation();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _breathController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final baseSurface = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
      colorScheme.surface,
    );
    final border = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.35 : 0.55,
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: baseSurface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(theme),

            // 头像网格
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildAvatarGrid(),
              ),
            ),

            // 底部按钮
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        final t = widget.enableBreathing ? _breathController.value : 0.0;
        final a = (0.22 + 0.12 * t).clamp(0.0, 1.0);
        final b = (0.08 + 0.08 * t).clamp(0.0, 1.0);
        final headerA = Color.alphaBlend(
          colorScheme.primary.withValues(alpha: a),
          isDark ? const Color(0xFF09090B) : colorScheme.surface,
        );
        final headerB = Color.alphaBlend(
          colorScheme.secondary.withValues(alpha: a),
          isDark ? const Color(0xFF09090B) : colorScheme.surface,
        );
        final border = Color.alphaBlend(
          colorScheme.primary.withValues(alpha: b),
          colorScheme.outlineVariant,
        );

        return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [headerA, headerB]),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                colorScheme.surface.withValues(alpha: 0.20),
                Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: colorScheme.onSurface,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Avatar Cards',
                  style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ) ??
                      TextStyle(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose your favorite avatar',
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
                ),
              ],
            ),
          ),
          // 刷新按钮
          Material(
            color: Color.alphaBlend(
              colorScheme.surface.withValues(alpha: 0.18),
              Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.isGenerating ? null : widget.onRefresh,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: widget.isGenerating
                      ? RotationTransition(
                          key: const ValueKey('spinning'),
                          turns: _spinController,
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: colorScheme.onSurface,
                          ),
                        )
                      : Icon(
                          key: const ValueKey('idle'),
                          Icons.refresh_rounded,
                          color: colorScheme.onSurface,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildAvatarGrid() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_currentAvatars.isEmpty) {
      return AnimatedBuilder(
        animation: _breathController,
        builder: (context, child) {
          final t = widget.enableBreathing ? _breathController.value : 0.0;
          final iconColor = Color.lerp(
            colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            colorScheme.primary.withValues(alpha: 0.75),
            t,
          )!;
          return Container(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 56, color: iconColor),
                const SizedBox(height: 14),
                Text(
                  'Tap refresh to generate avatars',
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.9,
                        ),
                        height: 1.2,
                      ) ??
                      TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.9,
                        ),
                        height: 1.2,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: _currentAvatars.length,
      itemBuilder: (context, index) {
        return _buildAnimatedAvatarCard(index);
      },
    );
  }

  Widget _buildAnimatedAvatarCard(int index) {
    final avatarUrl = _currentAvatars[index];
    final isSelected = _selectedAvatar == avatarUrl;

    return AnimatedBuilder(
      animation: _controllers[index],
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimations[index],
          child: SlideTransition(
            position: _slideAnimations[index],
            child: ScaleTransition(
              scale: _scaleAnimations[index],
              child: child,
            ),
          ),
        );
      },
      child: _buildAvatarCard(avatarUrl, isSelected),
    );
  }

  Widget _buildAvatarCard(String avatarUrl, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final t = widget.enableBreathing ? _breathController.value : 0.0;
    final accent = Color.lerp(colorScheme.primary, colorScheme.secondary, 0.35)!;
    final borderColor = Color.alphaBlend(
      accent.withValues(alpha: isSelected ? (0.35 + 0.18 * t) : 0.22),
      colorScheme.outlineVariant,
    );
    final bg = Color.alphaBlend(
      accent.withValues(alpha: isSelected ? (0.10 + 0.08 * t) : 0.0),
      colorScheme.surface,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAvatar = avatarUrl;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
          ],
          color: bg,
        ),
        child: Stack(
          children: [
            // 头像图片
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(isSelected ? 8.0 : 4.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.maxWidth;
                    return AvatarImage(
                      imageUrl: avatarUrl,
                      size: size,
                      borderRadius: BorderRadius.circular(16),
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),

            // 选中标记
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: colorScheme.surface,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canConfirm = _selectedAvatar != null;

    final confirm = AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        final t = (widget.enableBreathing && canConfirm)
            ? _breathController.value
            : 0.0;
        final glow = colorScheme.primary.withValues(alpha: 0.10 + 0.10 * t);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: canConfirm
                ? [
                    BoxShadow(
                      color: glow,
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: d1v.Button(
        text: 'Confirm',
        disabled: !canConfirm,
        onPressed: canConfirm
            ? () {
                HapticFeedback.mediumImpact();
                widget.onSelect(_selectedAvatar!);
              }
            : null,
        height: 48,
        borderRadius: 14,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.35 : 0.55,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: d1v.Button(
              variant: d1v.ButtonVariant.outline,
              text: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
              height: 48,
              borderRadius: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: confirm),
        ],
      ),
    );
  }
}
