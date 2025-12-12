import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

/// 通用的 SnackBar 显示助手
/// 用于显示成功、失败、警告和信息提示
class SnackBarHelper {
  /// 显示成功 SnackBar
  static void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.success,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
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
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.failure,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
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
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.warning,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
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
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.help,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
    );
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
  }) {
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
