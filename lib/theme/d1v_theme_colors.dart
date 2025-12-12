import 'package:flutter/material.dart';

/// D1V 主题色彩系统
/// 火紫色配色方案，支持 Light/Dark Mode
class D1VColors {
  D1VColors._();

  // ==================== Light Mode 火紫色系 ====================

  /// 主题火紫色 (Light)
  static const firePurpleLight = Color(0xFFE91E63);

  /// 强调紫色 (Light)
  static const accentPurpleLight = Color(0xFF9C27B0);

  /// 非激活状态 (Light)
  static const inactiveLight = Color(0xFFBDBDBD);

  /// 背景色 (Light)
  static const backgroundLight = Color(0xFFFFFFFF);

  // ==================== Dark Mode 火紫色系 ====================

  /// 主题火紫色 (Dark)
  static const firePurpleDark = Color(0xFFFF4081);

  /// 强调紫色 (Dark)
  static const accentPurpleDark = Color(0xFFCE93D8);

  /// 非激活状态 (Dark)
  static const inactiveDark = Color(0xFF616161);

  /// 背景色 (Dark)
  static const backgroundDark = Color(0xFF121212);

  // ==================== 动态获取方法 ====================

  /// 获取火紫色（根据当前主题）
  static Color getFirePurple(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? firePurpleLight
        : firePurpleDark;
  }

  /// 获取强调紫色（根据当前主题）
  static Color getAccentPurple(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? accentPurpleLight
        : accentPurpleDark;
  }

  /// 获取非激活颜色（根据当前主题）
  static Color getInactive(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? inactiveLight
        : inactiveDark;
  }

  /// 获取背景色（根据当前主题）
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? backgroundLight
        : backgroundDark;
  }

  // ==================== 渐变色 ====================

  /// 火紫色渐变 (Light)
  static const firePurpleGradientLight = LinearGradient(
    colors: [firePurpleLight, accentPurpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 火紫色渐变 (Dark)
  static const firePurpleGradientDark = LinearGradient(
    colors: [firePurpleDark, accentPurpleDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 获取火紫色渐变（根据当前主题）
  static LinearGradient getFirePurpleGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? firePurpleGradientLight
        : firePurpleGradientDark;
  }
}
