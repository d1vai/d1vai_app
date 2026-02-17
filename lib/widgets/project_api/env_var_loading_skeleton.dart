import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class EnvVarLoadingSkeleton extends StatelessWidget {
  final int itemCount;

  const EnvVarLoadingSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < itemCount; i++) ...[
          const _EnvVarSkeletonCard(),
          if (i != itemCount - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _EnvVarSkeletonCard extends StatelessWidget {
  const _EnvVarSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Static Card Background
    // Matching the real item's decoration for consistency
    final cardColor = theme.colorScheme.surfaceContainerHighest.withOpacity(
      isDark ? 0.3 : 0.5,
    );
    final borderColor = theme.colorScheme.outlineVariant.withOpacity(
      isDark ? 0.3 : 0.5,
    );

    // Shimmer Colors
    // Distinct from background to ensure visibility
    final shimmerBaseColor = isDark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final shimmerHighlightColor = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade100;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Shimmer.fromColors(
        baseColor: shimmerBaseColor,
        highlightColor: shimmerHighlightColor,
        period: const Duration(milliseconds: 1500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon + Key + Spacer + Menu
            Row(
              children: [
                // Icon placeholder
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Key Value placeholder
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                // More menu placeholder
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description lines
            Container(
              width: double.infinity,
              height: 12,
              margin: const EdgeInsets.only(right: 60),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 180,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            const SizedBox(height: 12),

            // Footer Row: Status Icon + Text + Copy Button
            Row(
              children: [
                // Sensitive Icon
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                // Status Text
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                // Copy Button
                Container(
                  width: 60,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
