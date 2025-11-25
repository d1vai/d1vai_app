import 'package:flutter/material.dart';
import 'dart:ui';

/// Popover Widget - A lightweight overlay component for displaying content
class Popover extends StatefulWidget {
  final Widget? child;
  final bool open;
  final VoidCallback? onOpenChange;
  final bool modal;
  final Offset? position;
  final ArrowDirection arrowDirection;
  final double arrowSize;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double elevation;
  final double blurAmount;
  final bool blurBackground;

  const Popover({
    super.key,
    this.child,
    this.open = false,
    this.onOpenChange,
    this.modal = true,
    this.position,
    this.arrowDirection = ArrowDirection.bottom,
    this.arrowSize = 8.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.margin,
    this.elevation = 8.0,
    this.blurAmount = 5.0,
    this.blurBackground = false,
  });

  @override
  State<Popover> createState() => _PopoverState();
}

class _PopoverState extends State<Popover>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    if (widget.open) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(Popover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      if (widget.open) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopoverContext(
      open: widget.open,
      onOpenChange: widget.onOpenChange,
      animation: _animationController,
      child: widget.child ?? const SizedBox.shrink(),
    );
  }
}

/// PopoverTrigger - The trigger that opens the popover
class PopoverTrigger extends StatelessWidget {
  final Widget child;
  final bool asChild;

  const PopoverTrigger({
    super.key,
    required this.child,
    this.asChild = false,
  });

  @override
  Widget build(BuildContext context) {
    final popover = PopoverContext.of(context);
    if (popover == null) {
      return child;
    }

    if (asChild && child is PopupMenuButton) {
      return child;
    }

    return GestureDetector(
      onTap: () {
        popover.onOpenChange?.call();
      },
      child: child,
    );
  }
}

/// PopoverAnchor - Anchor point for positioning
class PopoverAnchor extends StatelessWidget {
  final Widget child;

  const PopoverAnchor({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// PopoverContent - The content of the popover
class PopoverContent extends StatefulWidget {
  final Widget? child;
  final Widget? header;
  final Widget? title;
  final List<Widget>? footer;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double elevation;
  final ArrowDirection arrowDirection;
  final double arrowSize;
  final double arrowAlignment;
  final double blurAmount;
  final bool blurBackground;

  const PopoverContent({
    super.key,
    this.child,
    this.header,
    this.title,
    this.footer,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.elevation = 8.0,
    this.arrowDirection = ArrowDirection.bottom,
    this.arrowSize = 8.0,
    this.arrowAlignment = 0.0,
    this.blurAmount = 5.0,
    this.blurBackground = false,
  });

  @override
  State<PopoverContent> createState() => _PopoverContentState();
}

class _PopoverContentState extends State<PopoverContent> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _contentKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateOverlay();
  }

  @override
  void didUpdateWidget(PopoverContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateOverlay();
  }

  void _updateOverlay() {
    final popover = PopoverContext.of(context);
    if (popover == null) return;

    if (popover.open) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: GestureDetector(
              onTap: () {
                final popover = PopoverContext.of(context);
                popover?.onOpenChange?.call();
              },
              child: Container(
                color: widget.blurBackground
                    ? theme.colorScheme.scrim.withValues(alpha: 0.1)
                    : Colors.transparent,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blurAmount,
                    sigmaY: widget.blurAmount,
                  ),
                  child: CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    child: _buildContent(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    final popover = PopoverContext.of(context);
    final effectiveBackgroundColor = widget.backgroundColor ??
        theme.colorScheme.surface;
    final effectiveBorderColor = widget.borderColor ??
        theme.dividerColor.withValues(alpha: 0.2);
    final effectiveBorderWidth = widget.borderWidth ?? 1.0;
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(8.0);
    final effectivePadding =
        widget.padding ?? const EdgeInsets.all(16.0);

    final animationController = popover?.animation;

    if (animationController == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        final animationValue = animationController.value;
        return Opacity(
          opacity: animationValue,
          child: Transform.scale(
            scale: 0.9 + (animationValue * 0.1),
            child: Container(
              key: _contentKey,
              width: widget.width,
              height: widget.height,
              margin: widget.margin,
              decoration: BoxDecoration(
                color: effectiveBackgroundColor,
                border: Border.all(
                  color: effectiveBorderColor,
                  width: effectiveBorderWidth,
                ),
                borderRadius: effectiveBorderRadius,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: effectivePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.header != null) widget.header!,
                  if (widget.title != null) widget.title!,
                  if (widget.child != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: widget.child!,
                    ),
                  if (widget.footer != null && widget.footer!.isNotEmpty)
                    ...widget.footer!,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popover = PopoverContext.of(context);
    if (popover == null || !popover.open) {
      return const SizedBox.shrink();
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: const SizedBox.shrink(),
    );
  }
}

/// PopoverContext - Context for managing popover state
class PopoverContext extends InheritedWidget {
  final bool open;
  final VoidCallback? onOpenChange;
  final AnimationController? animation;

  const PopoverContext({
    super.key,
    required this.open,
    this.onOpenChange,
    this.animation,
    required super.child,
  });

  static PopoverContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PopoverContext>();
  }

  @override
  bool updateShouldNotify(PopoverContext oldWidget) {
    return open != oldWidget.open;
  }
}

/// ArrowDirection - Direction of the popover arrow
enum ArrowDirection {
  top,
  bottom,
  left,
  right,
}

/// SimplePopover - Helper to create simple popovers
class SimplePopover extends StatelessWidget {
  final Widget trigger;
  final Widget content;
  final ArrowDirection direction;
  final double arrowSize;
  final Color? backgroundColor;
  final double? width;
  final EdgeInsetsGeometry? padding;

  const SimplePopover({
    super.key,
    required this.trigger,
    required this.content,
    this.direction = ArrowDirection.bottom,
    this.arrowSize = 8.0,
    this.backgroundColor,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Popover(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          trigger,
          PopoverContent(
            arrowDirection: direction,
            arrowSize: arrowSize,
            backgroundColor: backgroundColor,
            width: width,
            padding: padding,
            child: content,
          ),
        ],
      ),
    );
  }
}

/// TooltipPopover - Popover for displaying tooltips
class TooltipPopover extends StatelessWidget {
  final Widget child;
  final String message;
  final ArrowDirection direction;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final double? width;

  const TooltipPopover({
    super.key,
    required this.message,
    required this.child,
    this.direction = ArrowDirection.bottom,
    this.textStyle,
    this.backgroundColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextStyle = textStyle ??
        theme.textTheme.bodySmall ??
        const TextStyle(fontSize: 12);

    return Popover(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopoverTrigger(child: child),
          PopoverContent(
            width: width ?? 200,
            backgroundColor: backgroundColor ??
                theme.colorScheme.surface,
            child: Text(
              message,
              style: effectiveTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}
