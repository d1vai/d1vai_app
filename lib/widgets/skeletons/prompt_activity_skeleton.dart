import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PromptActivitySkeleton extends StatelessWidget {
  const PromptActivitySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use subtle card colors to mimic the "glass" look of the real dashboard
    final cardColor = theme.colorScheme.surfaceContainerHighest.withOpacity(
      isDark ? 0.3 : 0.5,
    );
    final borderColor = theme.colorScheme.outlineVariant.withOpacity(
      isDark ? 0.3 : 0.5,
    );

    // Shimmer colors
    final shimmerBaseColor = isDark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final shimmerHighlightColor = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade100;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: shimmerBaseColor,
        highlightColor: shimmerHighlightColor,
        period: const Duration(milliseconds: 1500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title + Dropdown placeholder
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 140,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 100,
                  height: 28, // Mimic CompactSelector
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Date range text
            Container(
              width: 180,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // Heatmap Grid Area
            // We'll simulate a grid with some rows and columns
            SizedBox(
              height: 110, // Approx height of the real heatmap grid
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Weekday labels column
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 24,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Grid simulation
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        // Calculate approx number of columns that fit
                        // Each col is roughly 12px + 4px gap = 16px
                        final colCount = (width / 16).floor().clamp(1, 30);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(colCount, (c) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (r) {
                                return Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Footer: Total + Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // "Total: ..."
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // Legend
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ), // "Less"
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 30,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ), // "More"
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
