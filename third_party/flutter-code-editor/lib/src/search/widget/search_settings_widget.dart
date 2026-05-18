import 'package:flutter/material.dart';

import '../settings_controller.dart';

const _hintText = 'Search…';

class SearchSettingsWidget extends StatelessWidget {
  final FocusNode patternFocusNode;
  final SearchSettingsController settingsController;

  const SearchSettingsWidget({
    super.key,
    required this.patternFocusNode,
    required this.settingsController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, child) {
        return Row(
          children: [
            Expanded(
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: _hintText,
                          isCollapsed: true,
                          border: InputBorder.none,
                        ),
                        style: theme.textTheme.bodySmall,
                        focusNode: patternFocusNode,
                        controller: settingsController.patternController,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SearchToggle(
              label: 'Aa',
              selected: settingsController.value.isCaseSensitive,
              onTap: () {
                patternFocusNode.requestFocus();
                settingsController.toggleCaseSensitivity();
              },
            ),
            const SizedBox(width: 6),
            _SearchToggle(
              label: '.*',
              selected: settingsController.value.isRegExp,
              onTap: () {
                patternFocusNode.requestFocus();
                settingsController.toggleIsRegExp();
              },
            ),
          ],
        );
      },
    );
  }
}

class _SearchToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SearchToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.65)
                : colorScheme.outlineVariant,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
