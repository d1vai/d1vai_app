import 'package:flutter/material.dart';

const double _adaptiveModalMobileBreakpoint = 720;

bool useMobileModalLayout(BuildContext context) {
  return MediaQuery.of(context).size.width < _adaptiveModalMobileBreakpoint;
}

Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  if (useMobileModalLayout(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}

class AdaptiveModalContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double desktopMaxHeightFactor;
  final double mobileMaxHeightFactor;
  final bool showMobileHandle;
  final EdgeInsetsGeometry? margin;

  const AdaptiveModalContainer({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.desktopMaxHeightFactor = 0.9,
    this.mobileMaxHeightFactor = 0.94,
    this.showMobileHandle = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final mobile = useMobileModalLayout(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = media.viewInsets.bottom;
    final resolvedMargin =
        margin ??
        EdgeInsets.fromLTRB(
          mobile ? 0 : 20,
          mobile ? 0 : 24,
          mobile ? 0 : 20,
          mobile ? 0 : 24,
        );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(28),
        bottom: Radius.circular(mobile ? 0 : 28),
      ),
    );

    final surface = AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: mobile ? Alignment.bottomCenter : Alignment.center,
        child: Container(
          margin: resolvedMargin,
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight:
                media.size.height *
                (mobile ? mobileMaxHeightFactor : desktopMaxHeightFactor),
            minWidth: mobile ? media.size.width : 0,
          ),
          child: Material(
            color: theme.colorScheme.surface,
            elevation: mobile ? 0 : 18,
            shadowColor: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.42 : 0.18,
            ),
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: isDark ? 0.42 : 0.85,
                  ),
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(28),
                  bottom: Radius.circular(mobile ? 0 : 28),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(
                      theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.08 : 0.04,
                      ),
                      theme.colorScheme.surface,
                    ),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mobile && showMobileHandle)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.32,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final translateY = mobile ? (1 - value) * 18 : (1 - value) * 8;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: mobile ? 1.0 : (0.985 + (0.015 * value)),
              child: child,
            ),
          ),
        );
      },
      child: surface,
    );
  }
}

class AdaptiveModalHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AdaptiveModalHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ] else if (onClose != null) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ],
        ],
      ),
    );
  }
}
