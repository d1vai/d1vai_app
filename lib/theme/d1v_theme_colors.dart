import 'package:flutter/material.dart';

/// D1V 主题色彩系统 v2
/// 优雅的渐变色方案，支持 Light/Dark Mode
/// Light Mode: 温暖橙黄系 + 光晕效果
/// Dark Mode: 神秘紫黑系 + 磨砂渐变
class D1VColors {
  D1VColors._();

  // ==================== Light Mode 橙黄色系 ====================

  /// 主渐变起点 - 活力橙色 (Light)
  static const orangeLight = Color(0xFFFF9500);

  /// 主渐变终点 - 金色黄 (Light)
  static const goldenYellowLight = Color(0xFFFFD60A);

  /// 光晕色 (Light)
  static const glowLight = Color(0xFFFFA726);

  /// 激活文字 (Light) - 使用深色以提供高对比度
  static const activeTextLight = Color(0xFF1A1A1A);

  /// 非激活文字 (Light) - 使用半透明深色
  static const inactiveTextLight = Color(0x99000000); // 60% 黑色

  /// 背景渐变起点 (Light)
  static const backgroundStartLight = Color(0xFFFFFBF0);

  /// 背景渐变终点 (Light)
  static const backgroundEndLight = Color(0xFFFFF4E0);

  // ==================== Dark Mode 紫黑色系 ====================

  /// 主渐变起点 - 深紫黑 (Dark)
  static const deepPurpleBlackDark = Color(0xFF1A0033);

  /// 主渐变终点 - 丰富紫 (Dark)
  static const richPurpleDark = Color(0xFF2D1B4E);

  /// 磨砂玻璃背景 (Dark)
  static const frostedGlassDark = Color(0xFF1F1129);

  /// 激活文字 (Dark)
  static const activeTextDark = Color(0xFFE1BEE7);

  /// 非激活文字 (Dark)
  static const inactiveTextDark = Color(0xFF7E57C2);

  /// 边框微光 (Dark)
  static const shimmerBorderDark = Color(0xFFFFFFFF);

  // ==================== 动态获取方法 ====================

  /// 获取主渐变（根据当前主题）
  static LinearGradient getPrimaryGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const LinearGradient(
            colors: [orangeLight, goldenYellowLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [deepPurpleBlackDark, richPurpleDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
  }

  /// 获取背景渐变（根据当前主题）
  static LinearGradient getBackgroundGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const LinearGradient(
            colors: [backgroundStartLight, backgroundEndLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [deepPurpleBlackDark, Color(0xFF0A0014)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
  }

  /// 获取激活文字颜色（根据当前主题）
  static Color getActiveText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? activeTextLight
        : activeTextDark;
  }

  /// 获取非激活文字颜色（根据当前主题）
  static Color getInactiveText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? inactiveTextLight
        : inactiveTextDark;
  }

  /// 获取光晕颜色（Light Mode）
  static Color getGlowColor(BuildContext context) {
    return glowLight;
  }

  /// 获取磨砂玻璃颜色（Dark Mode）
  static Color getFrostedGlassColor(BuildContext context) {
    return frostedGlassDark;
  }

  /// 获取边框颜色（根据当前主题）
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? orangeLight.withValues(alpha: 0.3 * 255)
        : shimmerBorderDark.withValues(alpha: 0.1 * 255);
  }

  // ==================== 光晕配置 ====================

  /// 获取光晕阴影列表（Light Mode）
  static List<BoxShadow> getGlowShadows(
    BuildContext context, {
    double intensity = 1.0,
  }) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return [];
    }

    return [
      // 外层大光晕
      BoxShadow(
        color: glowLight.withValues(alpha: 0.4 * intensity * 255),
        blurRadius: 30 * intensity,
        spreadRadius: 8 * intensity,
      ),
      // 内层强光晕
      BoxShadow(
        color: orangeLight.withValues(alpha: 0.6 * intensity * 255),
        blurRadius: 15 * intensity,
        spreadRadius: 2 * intensity,
      ),
    ];
  }

  // ==================== 兼容旧版本（待弃用）====================

  @Deprecated('Use getPrimaryGradient instead')
  static Color getFirePurple(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? orangeLight
        : richPurpleDark;
  }

  @Deprecated('Use getActiveText instead')
  static Color getAccentPurple(BuildContext context) {
    return getActiveText(context);
  }

  @Deprecated('Use getInactiveText instead')
  static Color getInactive(BuildContext context) {
    return getInactiveText(context);
  }
}
