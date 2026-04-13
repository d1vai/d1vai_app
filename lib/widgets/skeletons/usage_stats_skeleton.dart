import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class UsageStatsSkeleton extends StatelessWidget {
  const UsageStatsSkeleton({super.key});

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Database Usage Header
        _buildHeaderPlaceholder(shimmerBaseColor, shimmerHighlightColor),
        const SizedBox(height: 12),
        // Database Stats Card
        _buildStatsCardPlaceholder(
          cardColor,
          borderColor,
          shimmerBaseColor,
          shimmerHighlightColor,
        ),

        const SizedBox(height: 24),

        // LLM Usage Header
        _buildHeaderPlaceholder(shimmerBaseColor, shimmerHighlightColor),
        const SizedBox(height: 12),

        // Month Selector
        Shimmer.fromColors(
          baseColor: shimmerBaseColor,
          highlightColor: shimmerHighlightColor,
          period: const Duration(milliseconds: 1500),
          child: Row(
            children: List.generate(
              3,
              (index) => Container(
                width: 100,
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // LLM Stats Card
        _buildStatsCardPlaceholder(
          cardColor,
          borderColor,
          shimmerBaseColor,
          shimmerHighlightColor,
        ),

        const SizedBox(height: 24),

        // Project Breakdown Header
        _buildHeaderPlaceholder(shimmerBaseColor, shimmerHighlightColor),
        const SizedBox(height: 12),

        // Project Breakdown List
        Container(
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
            child: Column(
              children: List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 150,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 100,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 60,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 12,
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderPlaceholder(Color baseColor, Color highlightColor) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1500),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCardPlaceholder(
    Color cardColor,
    Color borderColor,
    Color baseColor,
    Color highlightColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        child: Column(
          children: [
            _buildStatRow(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white),
            ),
            _buildStatRow(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white),
            ),
            _buildStatRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
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
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 60,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
