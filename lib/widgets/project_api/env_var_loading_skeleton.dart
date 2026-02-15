import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class EnvVarLoadingSkeleton extends StatelessWidget {
  const EnvVarLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.86);
    final highlightColor = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.72)
        : theme.colorScheme.surface.withValues(alpha: 0.98);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonBlock(width: 156, height: 13, radius: 999),
          SizedBox(height: 14),
          _EnvVarSkeletonCard(variant: 0),
          SizedBox(height: 12),
          _EnvVarSkeletonCard(variant: 1),
          SizedBox(height: 12),
          _EnvVarSkeletonCard(variant: 2),
        ],
      ),
    );
  }
}

class _EnvVarSkeletonCard extends StatelessWidget {
  final int variant;

  const _EnvVarSkeletonCard({required this.variant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.36)
        : theme.colorScheme.surface.withValues(alpha: 0.94);
    final border = theme.colorScheme.outlineVariant.withValues(alpha: 0.72);

    final keyWidth = switch (variant) {
      0 => 192.0,
      1 => 236.0,
      _ => 168.0,
    };
    final descPrimaryWidth = switch (variant) {
      0 => 244.0,
      1 => 268.0,
      _ => 218.0,
    };
    final descSecondaryWidth = switch (variant) {
      0 => 188.0,
      1 => 176.0,
      _ => 160.0,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBlock(width: 26, height: 26, radius: 8),
              const SizedBox(width: 10),
              _SkeletonBlock(width: keyWidth, height: 14, radius: 999),
              const Spacer(),
              const _SkeletonBlock(width: 18, height: 18, radius: 999),
            ],
          ),
          const SizedBox(height: 10),
          _SkeletonBlock(width: descPrimaryWidth, height: 11, radius: 999),
          const SizedBox(height: 6),
          _SkeletonBlock(width: descSecondaryWidth, height: 11, radius: 999),
          const SizedBox(height: 12),
          Row(
            children: const [
              _SkeletonBlock(width: 12, height: 12, radius: 999),
              SizedBox(width: 8),
              _SkeletonBlock(width: 84, height: 11, radius: 999),
              Spacer(),
              _SkeletonBlock(width: 74, height: 24, radius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
