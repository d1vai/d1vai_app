import 'package:flutter/material.dart';

/// OTP风格的邀请码展示组件
///
/// 将6位邀请码以独立的方格形式展示，类似验证码输入框
/// 每个字符显示在一个独立的方格中，更醒目、更专业
class InviteCodeDisplay extends StatelessWidget {
  /// 6位邀请码
  final String inviteCode;

  /// 每个格子的大小
  final double boxSize;

  /// 字体大小
  final double fontSize;

  /// 格子之间的间距
  final double spacing;

  const InviteCodeDisplay({
    super.key,
    required this.inviteCode,
    this.boxSize = 48.0,
    this.fontSize = 24.0,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    // 确保邀请码长度为6位，不足的用空格填充
    final code = inviteCode.padRight(6, ' ');
    final codeChars = code.split('').take(6).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index < 5 ? spacing : 0),
          child: _buildCodeBox(context, codeChars[index]),
        );
      }),
    );
  }

  /// 构建单个字符方格
  Widget _buildCodeBox(BuildContext context, String char) {
    final theme = Theme.of(context);

    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        // 内部阴影效果
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0,
          color: theme.colorScheme.onSurface,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// 响应式的邀请码展示组件 - 根据屏幕宽度调整大小
class ResponsiveInviteCodeDisplay extends StatelessWidget {
  final String inviteCode;

  const ResponsiveInviteCodeDisplay({super.key, required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度计算合适的格子大小
        final availableWidth = constraints.maxWidth;
        final maxBoxSize = 56.0;
        final minBoxSize = 40.0;
        final spacing = 8.0;

        // 计算格子大小：(总宽度 - 5个间距) / 6
        final calculatedBoxSize = (availableWidth - (5 * spacing)) / 6;
        final boxSize = calculatedBoxSize.clamp(minBoxSize, maxBoxSize);
        final fontSize = boxSize * 0.45; // 字体大小约为格子大小的45%

        return InviteCodeDisplay(
          inviteCode: inviteCode,
          boxSize: boxSize,
          fontSize: fontSize,
          spacing: spacing,
        );
      },
    );
  }
}
