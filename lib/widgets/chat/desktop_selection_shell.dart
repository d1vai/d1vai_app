import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DesktopSelectionShell extends StatelessWidget {
  final Widget child;

  const DesktopSelectionShell({super.key, required this.child});

  static bool isDesktop() {
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop()) return child;

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.05 : 0.04,
            ),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SelectionArea(child: child),
    );
  }
}
