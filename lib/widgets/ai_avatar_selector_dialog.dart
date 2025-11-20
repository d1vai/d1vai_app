import 'package:flutter/material.dart';
import 'avatar_image.dart';

/// AI Avatar 选择对话框 - 带有优雅的动画效果
class AiAvatarSelectorDialog extends StatefulWidget {
  final List<String> avatars;
  final String? selectedAvatar;
  final Function(String) onSelect;
  final VoidCallback onRefresh;
  final bool isGenerating;

  const AiAvatarSelectorDialog({
    super.key,
    required this.avatars,
    this.selectedAvatar,
    required this.onSelect,
    required this.onRefresh,
    this.isGenerating = false,
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

  String? _selectedAvatar;
  List<String> _currentAvatars = [];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.selectedAvatar;
    _currentAvatars = List.from(widget.avatars);
    _initializeAnimations();
    _startStaggeredAnimation();
  }

  @override
  void didUpdateWidget(AiAvatarSelectorDialog oldWidget) {
    super.didUpdateWidget(oldWidget);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(),

            // 头像网格
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildAvatarGrid(),
              ),
            ),

            // 底部按钮
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade400,
            Colors.purple.shade400,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Avatar Cards',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose your favorite avatar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // 刷新按钮
          Material(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.isGenerating ? null : widget.onRefresh,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: widget.isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarGrid() {
    if (_currentAvatars.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: Colors.deepPurple.shade200,
            ),
            const SizedBox(height: 16),
            Text(
              'Click refresh to generate avatars',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAvatar = avatarUrl;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.deepPurple.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
          ],
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade100,
                    Colors.purple.shade100,
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
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
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _selectedAvatar == null
                  ? null
                  : () {
                      // 调用回调，由外部负责关闭对话框
                      widget.onSelect(_selectedAvatar!);
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: _selectedAvatar == null ? 0 : 4,
                shadowColor: Colors.deepPurple.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
