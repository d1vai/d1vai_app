import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'dart:async';

/// 通用的 SnackBar 显示助手
/// 用于显示成功、失败、警告和信息提示
enum SnackBarPosition { bottom, top }

class SnackBarHelper {
  static OverlayEntry? _topToastEntry;
  static Timer? _topToastTimer;

  static void _triggerHaptic(ContentType type) {
    try {
      switch (type) {
        case ContentType.success:
          HapticFeedback.lightImpact();
          break;
        case ContentType.failure:
          HapticFeedback.mediumImpact();
          break;
        case ContentType.warning:
          HapticFeedback.selectionClick();
          break;
        case ContentType.help:
        default:
          HapticFeedback.selectionClick();
          break;
      }
    } catch (_) {
      // Best-effort UX; ignore platform failures.
    }
  }

  /// 显示成功 SnackBar
  static void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.success,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
      position: position,
    );
  }

  /// 显示失败 SnackBar
  static void showError(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.failure,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
      position: position,
    );
  }

  /// 显示警告 SnackBar
  static void showWarning(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.warning,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
      position: position,
    );
  }

  /// 显示信息 SnackBar
  static void showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.help,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
      position: position,
    );
  }

  static void _clearTopToast() {
    _topToastTimer?.cancel();
    _topToastTimer = null;
    _topToastEntry?.remove();
    _topToastEntry = null;
  }

  static void _showTopToast(
    BuildContext context, {
    required String title,
    required String message,
    required ContentType contentType,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
  }) {
    _clearTopToast();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final theme = Theme.of(context);
    final visual = _snackVisual(theme, contentType);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final topInset = MediaQuery.of(overlayContext).padding.top;
        final animKey =
            '${contentType.toString()}:$title:$message:${DateTime.now().millisecondsSinceEpoch}';
        return Positioned(
          top: topInset + 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(animKey),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  return Opacity(
                    opacity: t.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * -10),
                      child: child,
                    ),
                  );
                },
                child: _ToastCard(
                  key: ValueKey(animKey),
                  title: title,
                  message: message,
                  visual: visual,
                  actionLabel: actionLabel,
                  onActionPressed: onActionPressed,
                  onClose: _clearTopToast,
                ),
              ),
            ),
          ),
        );
      },
    );

    _topToastEntry = entry;
    overlay.insert(entry);

    _topToastTimer = Timer(duration ?? const Duration(seconds: 3), () {
      _clearTopToast();
    });
  }

  /// 内部方法：显示 SnackBar
  static void _showSnackBar(
    BuildContext context, {
    required String title,
    required String message,
    required ContentType contentType,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _triggerHaptic(contentType);
    if (position == SnackBarPosition.top) {
      _showTopToast(
        context,
        title: title,
        message: message,
        contentType: contentType,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
        duration: duration ?? const Duration(seconds: 3),
      );
      return;
    }

    // 先清除已有的 SnackBar，避免 Hero tag 冲突
    ScaffoldMessenger.of(context).clearSnackBars();

    final theme = Theme.of(context);
    final visual = _snackVisual(theme, contentType);
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: duration ?? const Duration(seconds: 4),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.zero,
      content: _SnackBarCard(
        key: UniqueKey(),
        title: title,
        message: message,
        visual: visual,
        actionLabel: actionLabel,
        onActionPressed: actionLabel != null && onActionPressed != null
            ? () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onActionPressed();
              }
            : null,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static _SnackVisual _snackVisual(ThemeData theme, ContentType contentType) {
    switch (contentType) {
      case ContentType.success:
        return _SnackVisual(
          accent: Colors.green.shade600,
          icon: Icons.check_circle_outline,
        );
      case ContentType.failure:
        return _SnackVisual(
          accent: theme.colorScheme.error,
          icon: Icons.error_outline,
        );
      case ContentType.warning:
        return _SnackVisual(
          accent: Colors.orange.shade700,
          icon: Icons.warning_amber_rounded,
        );
      case ContentType.help:
        return _SnackVisual(
          accent: theme.colorScheme.primary,
          icon: Icons.info_outline,
        );
      default:
        return _SnackVisual(
          accent: theme.colorScheme.primary,
          icon: Icons.info_outline,
        );
    }
  }
}

class _SnackVisual {
  final Color accent;
  final IconData icon;

  const _SnackVisual({required this.accent, required this.icon});
}

class _SnackBarCard extends StatelessWidget {
  final String title;
  final String message;
  final _SnackVisual visual;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const _SnackBarCard({
    super.key,
    required this.title,
    required this.message,
    required this.visual,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surfaceContainerHigh;
    final bg = Color.alphaBlend(
      visual.accent.withValues(alpha: isDark ? 0.18 : 0.10),
      surface,
    );
    final border = Color.alphaBlend(
      visual.accent.withValues(alpha: isDark ? 0.28 : 0.20),
      theme.colorScheme.outlineVariant,
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: visual.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Icon(visual.icon, size: 18, color: visual.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ) ??
                      const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ) ??
                      TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor: visual.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final String title;
  final String message;
  final _SnackVisual visual;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final VoidCallback onClose;

  const _ToastCard({
    super.key,
    required this.title,
    required this.message,
    required this.visual,
    required this.onClose,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surfaceContainerHigh;
    final bg = Color.alphaBlend(
      visual.accent.withValues(alpha: isDark ? 0.22 : 0.12),
      surface,
    );
    final border = Color.alphaBlend(
      visual.accent.withValues(alpha: isDark ? 0.30 : 0.22),
      theme.colorScheme.outlineVariant,
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: visual.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Icon(visual.icon, size: 18, color: visual.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ) ??
                      const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ) ??
                      TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                ),
                if (actionLabel != null && onActionPressed != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        onClose();
                        onActionPressed!();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: visual.accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
