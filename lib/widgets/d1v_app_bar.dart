import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/d1v_theme_colors.dart';
import 'app_glass_surface.dart';
import 'app_liquid_glass.dart';
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
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return _D1VGlassHeaderShell(
          enableGlassmorphism: widget.enableGlassmorphism,
          glowIntensity: _glowIntensityAnimation.value,
          blurValue: _blurAnimation.value,
          child: _buildAppBarContent(context),
        );
      },
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
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return _D1VGlassHeaderShell(
          enableGlassmorphism: widget.enableGlassmorphism,
          glowIntensity: _glowIntensityAnimation.value,
          blurValue: _blurAnimation.value,
          child: AppBar(
            title: widget.title,
            actions: widget.actions,
            leading: widget.leading,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: D1VColors.getActiveText(context),
          ),
        );
      },
    );
  }
}

class _D1VGlassHeaderShell extends StatelessWidget {
  final Widget child;
  final bool enableGlassmorphism;
  final double glowIntensity;
  final double blurValue;

  const _D1VGlassHeaderShell({
    required this.child,
    required this.enableGlassmorphism,
    required this.glowIntensity,
    required this.blurValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lightGlassShadow = <BoxShadow>[
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.22),
        blurRadius: 10,
        offset: const Offset(0, 1),
      ),
    ];

    if (!enableGlassmorphism) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: D1VColors.getPrimaryGradient(context),
          boxShadow: isDark ? null : lightGlassShadow,
        ),
        child: child,
      );
    }

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : colorScheme.outlineVariant.withValues(alpha: 0.78);
    final glassSettings = LiquidGlassSettings(
      blur: blurValue,
      thickness: isDark ? 30 : 24,
      glassColor: Color.lerp(
        colorScheme.surface.withValues(alpha: isDark ? 0.22 : 0.34),
        colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
        0.24,
      )!,
      lightIntensity: isDark ? 0.24 : 0.34,
      saturation: isDark ? 1.16 : 1.08,
      glowIntensity: isDark ? 0.22 : 0.12,
      standardOpacityMultiplier: isDark ? 1.0 : 0.72,
    );

    return Material(
      color: Colors.transparent,
      child: AppGlassSurface(
        variant: AppLiquidGlassVariant.navigation,
        borderRadius: BorderRadius.zero,
        glassBorderRadius: 0,
        glowIntensity: isDark
            ? 0.10 + glowIntensity * 0.04
            : 0.04 + glowIntensity * 0.03,
        useOwnLayer: isDark,
        quality: GlassQuality.premium,
        settings: glassSettings,
        boxShadow: isDark ? null : lightGlassShadow,
        overlayDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    D1VColors.deepBlueDark.withValues(alpha: 0.28),
                    colorScheme.primary.withValues(alpha: 0.08),
                    colorScheme.surface.withValues(alpha: 0.10),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.66),
                    colorScheme.surface.withValues(alpha: 0.54),
                    colorScheme.surfaceContainerLowest.withValues(alpha: 0.32),
                  ],
          ),
        ),
        child: child,
      ),
    );
  }
}
