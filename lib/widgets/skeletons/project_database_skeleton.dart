import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProjectDatabaseSkeleton extends StatelessWidget {
  const ProjectDatabaseSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.3 : 0.5,
    );
    final borderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.3 : 0.5,
    );
    final shimmerBaseColor = isDark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final shimmerHighlightColor = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade100;

    return Column(
      children: [
        // Top Bar Skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Shimmer.fromColors(
            baseColor: shimmerBaseColor,
            highlightColor: shimmerHighlightColor,
            period: const Duration(milliseconds: 1500),
            child: Column(
              children: [
                // Tabs
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 10),
                // Branch Selector
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Content Skeleton
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(16),
                child: Shimmer.fromColors(
                  baseColor: shimmerBaseColor,
                  highlightColor: shimmerHighlightColor,
                  period: const Duration(milliseconds: 1500),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 120,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 180,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
