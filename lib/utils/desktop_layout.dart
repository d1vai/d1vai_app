import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isDesktopLayout(BuildContext context) {
  if (kIsWeb) return MediaQuery.sizeOf(context).width >= 880;
  return (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 880;
}

bool isWideDesktopLayout(BuildContext context) {
  if (kIsWeb) return MediaQuery.sizeOf(context).width >= 1280;
  return (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 1280;
}

class DesktopContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const DesktopContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 1320,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return child;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
