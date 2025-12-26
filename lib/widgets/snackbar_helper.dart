import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'dart:async';

/// 通用的 SnackBar 显示助手
/// 用于显示成功、失败、警告和信息提示
enum SnackBarPosition { bottom, top }

class SnackBarHelper {
  static OverlayEntry? _topToastEntry;
  static Timer? _topToastTimer;

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

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final theme = Theme.of(context);
    final bg = _getContentColor(theme, contentType);
    final onBg = Colors.white;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final topInset = MediaQuery.of(overlayContext).padding.top;
        return Positioned(
          top: topInset + 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: onBg),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: onBg,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(fontSize: 13, color: onBg),
                            ),
                            if (actionLabel != null &&
                                onActionPressed != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    _clearTopToast();
                                    onActionPressed();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: onBg,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(actionLabel),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _clearTopToast,
                        icon: Icon(Icons.close, color: onBg),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
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
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: _getContentColor(theme, contentType),
      duration: duration ?? const Duration(seconds: 4),
      content: Row(
        key: UniqueKey(),
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      action: actionLabel != null && onActionPressed != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onActionPressed,
              textColor: Colors.white,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// 获取内容类型的颜色
  static Color _getContentColor(ThemeData theme, ContentType contentType) {
    switch (contentType) {
      case ContentType.success:
        return Colors.green.shade600;
      case ContentType.failure:
        return Colors.red.shade600;
      case ContentType.warning:
        return Colors.orange.shade600;
      case ContentType.help:
        return Colors.blue.shade600;
      default:
        return theme.colorScheme.surface;
    }
  }
}
