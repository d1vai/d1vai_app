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

  /// 呼吸周期（毫秒，默认 2500）
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
    this.breathingDuration = 2500,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<D1VTabBar> createState() => _D1VTabBarState();
}

class _D1VTabBarState extends State<D1VTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // 呼吸动画控制器
    _breathingController = AnimationController(
      duration: Duration(milliseconds: widget.breathingDuration),
      vsync: this,
    );

    // 缩放动画 (0.98 ↔ 1.02)
    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // 发光强度动画 (8 ↔ 16)
    _glowAnimation = Tween<double>(begin: 8.0, end: 16.0).animate(
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
    final firePurple = D1VColors.getFirePurple(context);
    final inactive = D1VColors.getInactive(context);

    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return TabBar(
          controller: widget.controller,
          tabs: widget.tabs,
          isScrollable: widget.isScrollable,
          padding: widget.padding,
          labelColor: widget.labelColor ?? firePurple,
          unselectedLabelColor: widget.unselectedLabelColor ?? inactive,
          labelStyle: widget.labelStyle,
          unselectedLabelStyle: widget.unselectedLabelStyle,
          labelPadding: widget.labelPadding,
          onTap: widget.onTap,
          indicator: _BreathingTabIndicator(
            color: firePurple,
            scale: _scaleAnimation.value,
            glowRadius: _glowAnimation.value,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
        );
      },
    );
  }
}

/// 呼吸指示器
class _BreathingTabIndicator extends Decoration {
  final Color color;
  final double scale;
  final double glowRadius;

  const _BreathingTabIndicator({
    required this.color,
    this.scale = 1.0,
    this.glowRadius = 12.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _BreathingTabIndicatorPainter(
      color: color,
      scale: scale,
      glowRadius: glowRadius,
      onChanged: onChanged,
    );
  }
}

/// 呼吸指示器绘制器
class _BreathingTabIndicatorPainter extends BoxPainter {
  final Color color;
  final double scale;
  final double glowRadius;

  @override
  final VoidCallback? onChanged;

  _BreathingTabIndicatorPainter({
    required this.color,
    required this.scale,
    required this.glowRadius,
    this.onChanged,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;

    final rect = Rect.fromLTWH(
      offset.dx,
      offset.dy + size.height - 3,
      size.width,
      3,
    );

    // 计算缩放后的矩形
    final center = rect.center;
    final scaledRect = Rect.fromCenter(
      center: center,
      width: rect.width * scale,
      height: rect.height * scale,
    );

    // 发光效果（外层阴影）
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * 255)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);

    // 主体颜色
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 绘制发光层
    final radius = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, Radius.circular(radius)),
      glowPaint,
    );

    // 绘制主体
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, Radius.circular(radius)),
      mainPaint,
    );
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

class _D1VTabState extends State<D1VTab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

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

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Tab(child: content),
      ),
    );
  }
}
