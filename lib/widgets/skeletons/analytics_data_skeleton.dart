import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AnalyticsDataSkeleton extends StatelessWidget {
  const AnalyticsDataSkeleton({super.key});

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: shimmerBaseColor,
        highlightColor: shimmerHighlightColor,
        period: const Duration(milliseconds: 1500),
        child: Column(
          children: [
            // Filters Card
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
            ),
            const SizedBox(height: 16),

            // Period Card
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
            ),
            const SizedBox(height: 16),

            // Key Metrics Row (4 small cards)
            Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 80,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Traffic Chart
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  // Chart Area Placeholder
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      10,
                      (index) => Container(
                        width: 20,
                        height: 50.0 + (index * 10) % 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top Lists Card
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 150,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 40,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
