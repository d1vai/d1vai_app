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
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.success,
    );
  }

  /// 显示失败 SnackBar
  static void showError(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.failure,
    );
  }

  /// 显示警告 SnackBar
  static void showWarning(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.warning,
    );
  }

  /// 显示信息 SnackBar
  static void showInfo(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.help,
    );
  }

  /// 内部方法：显示 SnackBar
  static void _showSnackBar(
    BuildContext context, {
    required String title,
    required String message,
    required ContentType contentType,
  }) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: title,
        message: message,
        contentType: contentType,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
