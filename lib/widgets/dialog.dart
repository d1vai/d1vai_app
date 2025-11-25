import 'package:flutter/material.dart';
import 'dart:ui';

/// CustomDialog Widget - A comprehensive dialog system with overlay, animations, and content support
class CustomDialog extends StatefulWidget {
  final Widget? child;
  final Widget? content;
  final bool open;
  final VoidCallback? onOpenChange;
  final bool modal;
  final Color? backgroundColor;
  final Color? overlayColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final String? title;
  final String? description;
  final List<Widget>? footer;
  final bool closable;
  final VoidCallback? onClose;
  final bool fullscreen;
  final bool blurOverlay;
  final double overlayBlur;
  final BorderRadius? borderRadius;

  const CustomDialog({
    super.key,
    this.child,
    this.content,
    this.open = false,
    this.onOpenChange,
    this.modal = true,
    this.backgroundColor,
    this.overlayColor,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.title,
    this.description,
    this.footer,
    this.closable = true,
    this.onClose,
    this.fullscreen = false,
    this.blurOverlay = true,
    this.overlayBlur = 5.0,
    this.borderRadius,
  });

  @override
  State<CustomDialog> createState() => _CustomDialogState();
}

class _CustomDialogState extends State<CustomDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(CustomDialog oldWidget) {
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
    return DialogPortal(
      child: DialogTrigger(
        open: widget.open,
        onOpenChange: widget.onOpenChange,
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// DialogTrigger - Handles opening/closing of dialog
class DialogTrigger extends StatelessWidget {
  final Widget child;
  final bool open;
  final VoidCallback? onOpenChange;

  const DialogTrigger({
    super.key,
    required this.child,
    required this.open,
    this.onOpenChange,
  });

  @override
  Widget build(BuildContext context) {
    if (child is! DialogContent || child is! DialogOverlay) {
      return GestureDetector(
        onTap: onOpenChange,
        child: child,
      );
    }
    return child;
  }
}

/// DialogPortal - Uses Overlay to display dialog
class DialogPortal extends StatelessWidget {
  final Widget child;

  const DialogPortal({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// DialogOverlay - The backdrop overlay with blur
class DialogOverlay extends StatelessWidget {
  final bool open;
  final VoidCallback? onClose;
  final Color? color;
  final bool blur;
  final double blurAmount;

  const DialogOverlay({
    super.key,
    required this.open,
    this.onClose,
    this.color,
    this.blur = true,
    this.blurAmount = 5.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final overlayColor = color ?? theme.colorScheme.scrim.withValues(alpha: 0.5);

    Widget overlay = GestureDetector(
      onTap: onClose,
      child: Container(
        color: overlayColor,
      ),
    );

    if (blur) {
      overlay = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: overlay,
      );
    }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: overlay,
    );
  }
}

/// DialogContent - Main content container
class DialogContent extends StatefulWidget {
  final Widget? child;
  final Widget? header;
  final Widget? title;
  final Widget? description;
  final List<Widget>? footer;
  final bool closable;
  final VoidCallback? onClose;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool fullscreen;
  final bool showOverlay;

  const DialogContent({
    super.key,
    this.child,
    this.header,
    this.title,
    this.description,
    this.footer,
    this.closable = true,
    this.onClose,
    this.backgroundColor,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.fullscreen = false,
    this.showOverlay = true,
  });

  @override
  State<DialogContent> createState() => _DialogContentState();
}

class _DialogContentState extends State<DialogContent> {
  @override
  Widget build(BuildContext context) {
    if (widget.fullscreen) {
      return widget.child ?? const SizedBox.shrink();
    }

    final effectiveWidth = widget.width ?? MediaQuery.of(context).size.width * 0.9;
    final effectiveHeight = widget.height;
    final effectivePadding =
        widget.padding ?? const EdgeInsets.all(24.0);
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(12.0);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: effectiveWidth,
          maxHeight: effectiveHeight ?? MediaQuery.of(context).size.height * 0.8,
        ),
        child: Material(
          color: widget.backgroundColor ??
              Theme.of(context).colorScheme.surface,
          elevation: 8,
          borderRadius: effectiveBorderRadius,
          child: Container(
            margin: widget.margin,
            padding: effectivePadding,
            decoration: BoxDecoration(
              color: widget.backgroundColor ??
                  Theme.of(context).colorScheme.surface,
              borderRadius: effectiveBorderRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null) widget.header!,
                if (widget.title != null) widget.title!,
                if (widget.description != null) widget.description!,
                if (widget.child != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: widget.child!,
                  ),
                if (widget.footer != null && widget.footer!.isNotEmpty)
                  ...widget.footer!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// DialogHeader - Header section
class DialogHeader extends StatelessWidget {
  final Widget? child;
  final bool closable;
  final VoidCallback? onClose;

  const DialogHeader({
    super.key,
    this.child,
    this.closable = true,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (child == null && !closable) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (child != null) Expanded(child: child!),
        if (closable && onClose != null)
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            iconSize: 20,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
      ],
    );
  }
}

/// DialogTitle - Title section
class DialogTitle extends StatelessWidget {
  final Widget? child;
  final String? text;
  final TextStyle? style;

  const DialogTitle({
    super.key,
    this.child,
    this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ??
        theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ) ??
        const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );

    if (child != null) {
      return child!;
    }

    if (text != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text!,
          style: effectiveStyle,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// DialogDescription - Description section
class DialogDescription extends StatelessWidget {
  final Widget? child;
  final String? text;
  final TextStyle? style;
  final int? maxLines;

  const DialogDescription({
    super.key,
    this.child,
    this.text,
    this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ) ??
        TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        );

    if (child != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: child!,
      );
    }

    if (text != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text!,
          style: effectiveStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// DialogFooter - Footer section with actions
class DialogFooter extends StatelessWidget {
  final List<Widget>? children;
  final MainAxisAlignment alignment;
  final EdgeInsetsGeometry? padding;

  const DialogFooter({
    super.key,
    this.children,
    this.alignment = MainAxisAlignment.end,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (children == null || children!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: alignment,
        children: children!
            .expand((child) => [
                  child,
                  const SizedBox(width: 8),
                ])
            .toList()
          ..removeLast(),
      ),
    );
  }
}

/// Simple Dialog Builder - Helper to create common dialogs
class SimpleDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool showCancel;

  const SimpleDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'OK',
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.showCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    final footerWidgets = <Widget>[
      if (cancelText != null && showCancel)
        OutlinedButton(
          onPressed: onCancel,
          child: Text(cancelText!),
        ),
      ElevatedButton(
        onPressed: onConfirm,
        child: Text(confirmText!),
      ),
    ];

    return DialogContent(
      title: DialogTitle(text: title),
      description: DialogDescription(text: message),
      footer: footerWidgets,
    );
  }
}
