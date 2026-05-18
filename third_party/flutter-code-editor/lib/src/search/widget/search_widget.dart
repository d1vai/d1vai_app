import 'package:flutter/material.dart';

import '../controller.dart';
import 'focus_rediretor.dart';
import 'search_navigation_widget.dart';
import 'search_settings_widget.dart';

const _iconSize = 24.0;

class SearchWidget extends StatelessWidget {
  final CodeSearchController searchController;

  const SearchWidget({
    super.key,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: searchController,
      builder: (context, child) => FocusRedirector(
        redirectTo: searchController.patternFocusNode,
        child: SizedBox(
          height: 42,
          child: IntrinsicWidth(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 7,
                  child: SearchSettingsWidget(
                    patternFocusNode: searchController.patternFocusNode,
                    settingsController: searchController.settingsController,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: SearchNavigationWidget(
                    searchNavigationController:
                        searchController.navigationController,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  splashRadius: 16,
                  tooltip: 'Close (Esc)',
                  onPressed: () => searchController.hideSearch(
                    returnFocusToCodeField: true,
                  ),
                  icon: const Icon(Icons.close, size: _iconSize),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
