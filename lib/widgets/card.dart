import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// CustomCard Widget - A flexible container for grouping related content
class CustomCard extends StatelessWidget {
  final Widget? child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? elevation;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadow;
  final Clip? clipBehavior;
  final bool glass; // New: Glassmorphism support
  final bool borderless; // New: no border/shadow framing
  final bool embedded; // New: transparent background for embedding

  const CustomCard({
    super.key,
    this.child,
    this.backgroundColor,
    this.borderColor,
    this.elevation,
    this.borderRadius,
    this.padding,
    this.margin,
    this.shadow,
    this.clipBehavior,
    this.glass = false,
    this.borderless = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBorderRadius = borderRadius ?? 14.0;
    final effectiveElevation =
        elevation ?? ((glass || embedded || borderless) ? 0.0 : 1.0);

    final defaultSurface = glass
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.07),
            colorScheme.surface,
          ).withValues(alpha: isDark ? 0.74 : 0.92)
        : colorScheme.surface;

    final effectiveBackgroundColor =
        backgroundColor ?? (embedded ? Colors.transparent : defaultSurface);

    final defaultBorder = glass
        ? colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5)
        : colorScheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.42);
    final effectiveBorderColor = borderColor ?? defaultBorder;
    final effectiveBorderWidth = (embedded || borderless) ? 0.0 : 1.0;
    final effectiveResolvedBorderColor =
        (embedded || borderless) ? Colors.transparent : effectiveBorderColor;

    final defaultShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.25)
        : theme.shadowColor.withValues(alpha: 0.08);
    final defaultShadows = effectiveElevation <= 0
        ? const <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: defaultShadowColor,
              blurRadius: 10 + (effectiveElevation * 6),
              offset: Offset(0, 2 + effectiveElevation),
            ),
          ];

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        border: Border.all(
          color: effectiveResolvedBorderColor,
          width: effectiveBorderWidth,
        ),
        boxShadow: shadow ??
            ((glass || embedded || borderless)
                ? const <BoxShadow>[]
                : defaultShadows),
      ),
      child: child != null
          ? Padding(padding: padding ?? EdgeInsets.zero, child: child)
          : null,
    );

    if (glass) {
      final effectiveClip = clipBehavior ?? Clip.antiAlias;
      return Container(
        margin: margin,
        clipBehavior: effectiveClip,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: cardContent,
        ),
      );
    }

    return Container(
      margin: margin,
      clipBehavior: clipBehavior ?? Clip.none,
      decoration: (clipBehavior ?? Clip.none) == Clip.none
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
            ),
      child: cardContent,
    );
  }
}

/// CardHeader - Header section of the card
class CardHeader extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const CardHeader({
    super.key,
    this.child,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(16.0),
      child: child != null
          ? Row(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              children: [child!],
            )
          : const SizedBox.shrink(),
    );
  }
}

/// CardTitle - Title of the card
class CardTitle extends StatelessWidget {
  final Widget? child;
  final String? text;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const CardTitle({super.key, this.child, this.text, this.style, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle =
        style ??
        theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    final content =
        child ??
        (text != null
            ? Text(text!, style: effectiveStyle)
            : const SizedBox.shrink());

    return Padding(
      padding: padding ?? const EdgeInsets.all(16.0),
      child: content,
    );
  }
}

/// CardDescription - Description of the card
class CardDescription extends StatelessWidget {
  final Widget? child;
  final String? text;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const CardDescription({
    super.key,
    this.child,
    this.text,
    this.style,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle =
        style ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ) ??
        TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        );

    final content =
        child ??
        (text != null
            ? Text(text!, style: effectiveStyle)
            : const SizedBox.shrink());

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0),
      child: content,
    );
  }
}

/// CardContent - Main content of the card
class CardContent extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;

  const CardContent({super.key, this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(16.0),
      child: child ?? const SizedBox.shrink(),
    );
  }
}

/// CardFooter - Footer section of the card
class CardFooter extends StatelessWidget {
  final Widget? child;
  final List<Widget>? children;
  final EdgeInsetsGeometry? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const CardFooter({
    super.key,
    this.child,
    this.children,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        (children != null && children!.isNotEmpty
            ? Row(
                mainAxisAlignment: mainAxisAlignment,
                crossAxisAlignment: crossAxisAlignment,
                children:
                    children!
                        .expand((child) => [child, const SizedBox(width: 8)])
                        .toList()
                      ..removeLast(),
              )
            : const SizedBox.shrink());

    return Padding(
      padding: padding ?? const EdgeInsets.all(16.0),
      child: content,
    );
  }
}

/// SimpleCard - Helper to create cards with common structure
class SimpleCard extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget? content;
  final Widget? footer;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool clickable;

  const SimpleCard({
    super.key,
    this.title,
    this.description,
    this.content,
    this.footer,
    this.backgroundColor,
    this.onTap,
    this.clickable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surface;

    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) CardTitle(text: title),
        if (description != null) CardDescription(text: description),
        if (content != null) CardContent(child: content),
        if (footer != null && footer!.toString().isNotEmpty)
          CardFooter(child: footer),
      ],
    );

    if (clickable && onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: CustomCard(
          backgroundColor: effectiveBackgroundColor,
          child: cardContent,
        ),
      );
    }

    return CustomCard(
      backgroundColor: effectiveBackgroundColor,
      child: cardContent,
    );
  }
}

/// InfoCard - Card for displaying information
class InfoCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? iconColor;

  const InfoCard({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return CustomCard(
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(icon, color: effectiveIconColor, size: 24),
            ),
          CardTitle(text: title),
          CardDescription(text: message),
        ],
      ),
    );
  }
}

/// StatCard - Card for displaying statistics
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool glass;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveValueColor = valueColor ?? theme.colorScheme.primary;

    return CustomCard(
      glass: glass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(icon, color: theme.colorScheme.primary, size: 28),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: effectiveValueColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
