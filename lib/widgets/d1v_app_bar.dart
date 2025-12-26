import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/d1v_theme_colors.dart';
import 'd1v_tab_bar_view.dart';

/// D1V 优雅的 AppBar 组件
///
/// 特性：
/// - Light Mode: 温暖橙黄渐变 + 光晕效果
/// - Dark Mode: 神秘紫黑渐变 + 磨砂玻璃效果
/// - 呼吸动画
/// - 与 TabBar 无缝集成
class D1VAppBar extends StatefulWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<D1VTab>? tabs;
  final Widget? title;
  final List<Widget>? actions;
  final bool enableGlassmorphism;
  final bool enableBreathing;
  final double elevation;

  const D1VAppBar({
    super.key,
    this.controller,
    this.tabs,
    this.title,
    this.actions,
    this.enableGlassmorphism = true,
    this.enableBreathing = true,
    this.elevation = 0,
  });

  @override
  Size get preferredSize {
    final tabBarHeight = tabs != null ? kToolbarHeight : 0;
    return Size.fromHeight(kToolbarHeight + tabBarHeight);
  }

  @override
  State<D1VAppBar> createState() => _D1VAppBarState();
}

class _D1VAppBarState extends State<D1VAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _glowIntensityAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _glowIntensityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _blurAnimation = Tween<double>(begin: 18.0, end: 22.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    if (widget.enableBreathing) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: isDark
                ? null
                : D1VColors.getGlowShadows(
                    context,
                    _glowIntensityAnimation.value,
                  ),
          ),
          child: ClipRRect(
            child: Stack(
              children: [
                // 背景层
                _buildBackground(context, isDark),

                // 磨砂玻璃层 (Dark Mode)
                if (isDark && widget.enableGlassmorphism)
                  _buildGlassmorphicLayer(context, _blurAnimation.value),

                // AppBar 内容
                _buildAppBarContent(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: D1VColors.getPrimaryGradient(context),
      ),
    );
  }

  Widget _buildGlassmorphicLayer(BuildContext context, double blurValue) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tint = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08),
      colorScheme.surface,
    );
    final overlayColor = tint.withValues(alpha: isDark ? 0.72 : 0.88);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
      child: Container(
        decoration: BoxDecoration(
          color: overlayColor,
        ),
      ),
    );
  }

  Widget _buildAppBarContent(BuildContext context) {
    return AppBar(
      title: widget.title,
      actions: widget.actions,
      elevation: widget.elevation,
      backgroundColor: Colors.transparent,
      foregroundColor: D1VColors.getActiveText(context),
      bottom: widget.tabs != null
          ? D1VTabBar(
              controller: widget.controller,
              tabs: widget.tabs!,
              enableBreathing: widget.enableBreathing,
            )
          : null,
    );
  }
}

/// D1V 优雅的 AppBar (简化版，仅用于无 Tab 场景)
class D1VSimpleAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool enableGlassmorphism;
  final bool enableBreathing;

  const D1VSimpleAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.enableGlassmorphism = true,
    this.enableBreathing = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<D1VSimpleAppBar> createState() => _D1VSimpleAppBarState();
}

class _D1VSimpleAppBarState extends State<D1VSimpleAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _glowIntensityAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _glowIntensityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _blurAnimation = Tween<double>(begin: 18.0, end: 22.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    if (widget.enableBreathing) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: isDark
                ? null
                : D1VColors.getGlowShadows(
                    context,
                    _glowIntensityAnimation.value,
                  ),
          ),
          child: ClipRRect(
            child: Stack(
              children: [
                // 背景渐变
                Container(
                  decoration: BoxDecoration(
                    gradient: D1VColors.getPrimaryGradient(context),
                  ),
                ),

                // 磨砂玻璃层 (Dark Mode)
                if (isDark && widget.enableGlassmorphism)
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _blurAnimation.value,
                      sigmaY: _blurAnimation.value,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.14),
                          Theme.of(context).colorScheme.surface,
                        ).withValues(alpha: 0.72),
                      ),
                    ),
                  ),

                // AppBar 内容
                AppBar(
                  title: widget.title,
                  actions: widget.actions,
                  leading: widget.leading,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  foregroundColor: D1VColors.getActiveText(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
