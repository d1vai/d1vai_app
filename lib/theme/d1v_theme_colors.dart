import 'package:flutter/material.dart';

/// D1V 主题色彩系统 v3 - 顶级优雅设计
///
/// Light Mode: 温柔玫瑰金系（优雅浪漫）
/// Dark Mode: 深邃灰蓝系（专业高级）
class D1VColors {
  D1VColors._();

  // ==================== Light Mode 玫瑰金系 ====================

  /// AppBar 渐变起点 - 浅玫瑰粉
  static const rosePinkLight = Color(0xFFFFDEE9);

  /// AppBar 渐变终点 - 柔和粉
  static const softPinkLight = Color(0xFFFFB7C3);

  /// 激活文字 - 深玫瑰红（高对比）
  static const activeTextLight = Color(0xFFC2185B);

  /// 非激活文字 - 中性灰（清晰可辨）
  static const inactiveTextLight = Color(0xFF757575);

  /// 指示器渐变起点 - 玫瑰粉
  static const indicatorStartLight = Color(0xFFE91E63);

  /// 指示器渐变终点 - 亮玫瑰
  static const indicatorEndLight = Color(0xFFEC407A);

  /// 背景渐变起点 - 纯白
  static const backgroundStartLight = Color(0xFFFFFFFF);

  /// 背景渐变终点 - 极淡粉
  static const backgroundEndLight = Color(0xFFFFF5F7);

  // ==================== Dark Mode 深灰蓝系 ====================

  /// AppBar 渐变起点 - 深灰蓝
  static const deepBlueDark = Color(0xFF2C2C3E);

  /// AppBar 渐变终点 - 暗紫蓝
  static const darkPurpleBlueDark = Color(0xFF1F1F2E);

  /// 激活文字 - 亮紫粉（醒目）
  static const activeTextDark = Color(0xFFF48FB1);

  /// 非激活文字 - 中灰（清晰可辨）
  static const inactiveTextDark = Color(0xFF9E9E9E);

  /// 指示器渐变起点 - 亮粉紫
  static const indicatorStartDark = Color(0xFFF48FB1);

  /// 指示器渐变终点 - 柔紫
  static const indicatorEndDark = Color(0xFFCE93D8);

  /// 背景渐变起点 - 深灰
  static const backgroundStartDark = Color(0xFF1E1E1E);

  /// 背景渐变终点 - 极深灰
  static const backgroundEndDark = Color(0xFF121212);

  // ==================== 动态获取方法 ====================

  /// 获取主渐变（AppBar 背景）
  static LinearGradient getPrimaryGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const LinearGradient(
            colors: [rosePinkLight, softPinkLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [deepBlueDark, darkPurpleBlueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
  }

  /// 获取背景渐变
  static LinearGradient getBackgroundGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const LinearGradient(
            colors: [backgroundStartLight, backgroundEndLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [backgroundStartDark, backgroundEndDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
  }

  /// 获取指示器渐变
  static LinearGradient getIndicatorGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const LinearGradient(
            colors: [indicatorStartLight, indicatorEndLight],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : const LinearGradient(
            colors: [indicatorStartDark, indicatorEndDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );
  }

  /// 获取激活文字颜色
  static Color getActiveText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? activeTextLight
        : activeTextDark;
  }

  /// 获取非激活文字颜色
  static Color getInactiveText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? inactiveTextLight
        : inactiveTextDark;
  }

  /// 获取指示器发光颜色（Dark Mode）
  static Color getIndicatorGlowColor(BuildContext context) {
    return indicatorStartDark.withValues(alpha: 0.4 * 255);
  }

  /// 获取边框颜色
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.06 * 255)
        : Colors.white.withValues(alpha: 0.1 * 255);
  }

  /// 获取阴影颜色
  static Color getShadowColor(BuildContext context) {
    return Colors.black.withValues(
      alpha: Theme.of(context).brightness == Brightness.light
          ? 0.04 *
                255 // 0.08 → 0.04 更淡
          : 0.08 * 255, // 0.12 → 0.08 更淡
    );
  }

  /// 获取发光阴影效果（AppBar 呼吸动画）
  static List<BoxShadow> getGlowShadows(
    BuildContext context,
    double glowIntensity,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return [
        BoxShadow(
          color: indicatorStartDark.withValues(
            alpha: glowIntensity * 0.08 * 255, // 0.15 → 0.08 更淡
          ),
          blurRadius: 12 * glowIntensity, // 15 → 12 更柔和
          spreadRadius: 0,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: indicatorStartLight.withValues(
            alpha: glowIntensity * 0.05 * 255, // 0.1 → 0.05 更淡
          ),
          blurRadius: 8 * glowIntensity, // 10 → 8 更柔和
          spreadRadius: 0,
        ),
      ];
    }
  }

  // ==================== 兼容旧版本（已弃用）====================

  @Deprecated('Use getPrimaryGradient instead')
  static Color getFirePurple(BuildContext context) {
    return getActiveText(context);
  }

  @Deprecated('Use getActiveText instead')
  static Color getAccentPurple(BuildContext context) {
    return getActiveText(context);
  }

  @Deprecated('Use getInactiveText instead')
  static Color getInactive(BuildContext context) {
    return getInactiveText(context);
  }

  @Deprecated('Use getIndicatorGlowColor instead')
  static Color getGlowColor(BuildContext context) {
    return getIndicatorGlowColor(context);
  }

  @Deprecated('Use backgroundStartDark/backgroundEndDark instead')
  static Color getFrostedGlassColor(BuildContext context) {
    return backgroundStartDark;
  }

  static const shimmerBorderDark = Color(0xFFFFFFFF);

  @Deprecated('Use getIndicatorGradient instead')
  static Color glowLight = indicatorStartLight;

  @Deprecated('Use deepBlueDark instead')
  static Color frostedGlassDark = deepBlueDark;

  @Deprecated('Use darkPurpleBlueDark instead')
  static Color richPurpleDark = darkPurpleBlueDark;
}
