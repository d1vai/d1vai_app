import 'package:flutter/material.dart';

import '../search_navigation_controller.dart';

const _iconSize = 20.0;

class SearchNavigationWidget extends StatelessWidget {
  final SearchNavigationController searchNavigationController;

  const SearchNavigationWidget({
    super.key,
    required this.searchNavigationController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedBuilder(
      animation: searchNavigationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (searchNavigationController.value.totalMatchCount > 0) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                tooltip: 'Previous match',
                onPressed: searchNavigationController.movePrevious,
                icon: const Icon(
                  Icons.keyboard_arrow_up,
                  size: _iconSize,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                tooltip: 'Next match',
                onPressed: searchNavigationController.moveNext,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: _iconSize,
                ),
              ),
            ],
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  _getText(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getText() {
    final currentMatchIndex =
        (searchNavigationController.value.currentMatchIndex ?? -1) + 1;
    final totalMatchCount = searchNavigationController.value.totalMatchCount;

    return '$currentMatchIndex / $totalMatchCount';
  }
}
