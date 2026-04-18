import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../theme/d1v_theme_colors.dart';

/// D1V 高级 TabBarView 组件
///
/// 特性：
/// - 呼吸感动效（脉动、发光）
/// - 火紫色主题（Light/Dark Mode 自适应）
/// - 仪式感交互（触觉反馈、流畅转场）
/// - 完全兼容系统 TabBarView API
class D1VTabBarView extends StatelessWidget {
  final TabController? controller;
  final List<Widget> children;
  final ScrollPhysics? physics;
  final DragStartBehavior dragStartBehavior;

  const D1VTabBarView({
    super.key,
    this.controller,
    required this.children,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  @override
  Widget build(BuildContext context) {
    return _HapticTabBarView(
      controller: controller,
      physics: physics,
      dragStartBehavior: dragStartBehavior,
      children: children,
    );
  }
}

/// 带触觉反馈的 TabBarView
class _HapticTabBarView extends StatefulWidget {
  final TabController? controller;
  final List<Widget> children;
  final ScrollPhysics? physics;
  final DragStartBehavior dragStartBehavior;

  const _HapticTabBarView({
    this.controller,
    required this.children,
    this.physics,
    required this.dragStartBehavior,
  });

  @override
  State<_HapticTabBarView> createState() => _HapticTabBarViewState();
}

class _HapticTabBarViewState extends State<_HapticTabBarView> {
  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_handleTabChange);
    _previousIndex = widget.controller?.index;
  }

  @override
  void didUpdateWidget(_HapticTabBarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleTabChange);
      widget.controller?.addListener(_handleTabChange);
      _previousIndex = widget.controller?.index;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    final currentIndex = widget.controller?.index;
    if (currentIndex != null && currentIndex != _previousIndex) {
      // 触觉反馈
      HapticFeedback.selectionClick();
      _previousIndex = currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: widget.controller,
      physics: widget.physics,
      dragStartBehavior: widget.dragStartBehavior,
      children: widget.children,
    );
  }
}

/// D1V 高级 TabBar 组件
///
/// 特性：
/// - 呼吸动画指示器
/// - 发光效果
/// - 火紫色主题
/// - 微妙的缩放交互
class D1VTabBar extends StatefulWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget> tabs;
  final bool isScrollable;
  final EdgeInsetsGeometry? padding;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final void Function(int)? onTap;

  /// 是否启用呼吸动画（默认 true）
  final bool enableBreathing;

  /// 呼吸周期（毫秒，默认 3000）
  final int breathingDuration;

  const D1VTabBar({
    super.key,
    this.controller,
    required this.tabs,
    this.isScrollable = false,
    this.padding,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.labelPadding,
    this.onTap,
    this.enableBreathing = true,
    this.breathingDuration = 3000,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<D1VTabBar> createState() => _D1VTabBarState();
}

class _D1VTabBarState extends State<D1VTabBar> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late AnimationController _tapPulseController;
  late Animation<double> _tapPulseAnimation;

  @override
  void initState() {
    super.initState();

    // 呼吸动画控制器 - 优化时长
    _breathingController = AnimationController(
      duration: Duration(milliseconds: widget.breathingDuration),
      vsync: this,
    );

    // 缩放动画幅度增大 (0.98-1.02 → 0.95-1.05)
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutCubic, // 更自然的曲线
      ),
    );

    // 发光强度动画增强 (8-16 → 8-24)
    _glowAnimation = Tween<double>(begin: 8.0, end: 24.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _tapPulseController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _tapPulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tapPulseController, curve: Curves.easeOutCubic),
    );

    if (widget.enableBreathing) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _tapPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeText = D1VColors.getActiveText(context);
    final inactiveText = D1VColors.getInactiveText(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_breathingController, _tapPulseController]),
      builder: (context, child) {
        final indicatorScale =
            _scaleAnimation.value + 0.025 * _tapPulseAnimation.value;
        final glowRadius =
            _glowAnimation.value + 8.0 * _tapPulseAnimation.value;
        return TabBar(
          controller: widget.controller,
          tabs: widget.tabs,
          isScrollable: widget.isScrollable,
          padding: widget.padding,
          labelColor: widget.labelColor ?? activeText,
          unselectedLabelColor: widget.unselectedLabelColor ?? inactiveText,
          labelStyle: widget.labelStyle,
          unselectedLabelStyle: widget.unselectedLabelStyle,
          labelPadding: widget.labelPadding,
          onTap: (index) {
            if (widget.controller?.index == index) {
              HapticFeedback.lightImpact();
            }
            _tapPulseController.forward(from: 0);
            widget.onTap?.call(index);
          },
          dividerColor: Colors.transparent, // 隐藏底部分隔线
          indicator: _GradientPillIndicator(
            gradient: D1VColors.getIndicatorGradient(context),
            scale: indicatorScale,
            glowRadius: glowRadius,
            context: context,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
        );
      },
    );
  }
}

/// 渐变胶囊指示器
class _GradientPillIndicator extends Decoration {
  final LinearGradient gradient;
  final double scale;
  final double glowRadius;
  final BuildContext context;

  const _GradientPillIndicator({
    required this.gradient,
    required this.context,
    this.scale = 1.0,
    this.glowRadius = 12.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientPillIndicatorPainter(
      gradient: gradient,
      context: context,
      scale: scale,
      glowRadius: glowRadius,
      onChanged: onChanged,
    );
  }
}

/// 渐变胶囊指示器绘制器
class _GradientPillIndicatorPainter extends BoxPainter {
  final LinearGradient gradient;
  final BuildContext context;
  final double scale;
  final double glowRadius;

  _GradientPillIndicatorPainter({
    required this.gradient,
    required this.context,
    required this.scale,
    required this.glowRadius,
    VoidCallback? onChanged,
  }) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 优化后的尺寸：4px 高度，距底部 4px，左右内缩 12px
    final indicatorHeight = 4.0;
    final indicatorY = size.height - indicatorHeight - 4;

    final rect = Rect.fromLTWH(
      offset.dx + 12,
      offset.dy + indicatorY,
      size.width - 24,
      indicatorHeight,
    );

    // 计算缩放后的矩形
    final center = rect.center;
    final scaledRect = Rect.fromCenter(
      center: center,
      width: rect.width * scale,
      height: rect.height * scale,
    );

    final cornerRadius = Radius.circular(2.0);

    // Light Mode: 柔和发光 + 渐变 + 白色高光条
    if (!isDark) {
      // 1. 底部柔和发光
      final glowPaint = Paint()
        ..color = D1VColors.indicatorStartLight.withValues(alpha: 0.3 * 255)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.5);

      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledRect, cornerRadius),
        glowPaint,
      );

      // 2. 基础渐变
      final gradientPaint = Paint()
        ..shader = gradient.createShader(scaledRect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledRect, cornerRadius),
        gradientPaint,
      );

      // 3. 顶部白色高光条 (1px)
      final highlightRect = Rect.fromLTWH(
        scaledRect.left,
        scaledRect.top,
        scaledRect.width,
        1.0,
      );

      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6 * 255)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(highlightRect, Radius.circular(1.0)),
        highlightPaint,
      );
    } else {
      // Dark Mode: 外发光 + 渐变
      final glowPaint = Paint()
        ..color = D1VColors.getIndicatorGlowColor(context)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0);

      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledRect, cornerRadius),
        glowPaint,
      );

      // 2. 基础渐变
      final gradientPaint = Paint()
        ..shader = gradient.createShader(scaledRect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledRect, cornerRadius),
        gradientPaint,
      );
    }
  }
}

/// D1V Tab 项（带微妙缩放效果）
class D1VTab extends StatefulWidget {
  final String text;
  final IconData? icon;
  final Widget? child;

  const D1VTab({super.key, this.text = '', this.icon, this.child});

  @override
  State<D1VTab> createState() => _D1VTabState();
}

class _D1VTabState extends State<D1VTab> {
  @override
  Widget build(BuildContext context) {
    Widget content;

    if (widget.child != null) {
      content = widget.child!;
    } else {
      content = widget.icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 20),
                if (widget.text.isNotEmpty) const SizedBox(width: 8),
                if (widget.text.isNotEmpty) Text(widget.text),
              ],
            )
          : Text(widget.text);
    }

    // 直接使用 Tab，不包装 GestureDetector
    // TabBar 自己会处理点击事件
    return Tab(child: content);
  }
}
