import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/adaptive_modal.dart';
import '../../widgets/editor_preferences_dialog.dart';
import '../../widgets/settings/settings_entry_hero.dart';
import 'developer_tab.dart';

class DeveloperSettingsScreen extends StatelessWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationUtils.popOrGo(context, '/settings'),
        ),
        title: Row(
          children: [
            const SettingsEntryHero(
              tag: SettingsEntryHero.developerTag,
              icon: Icons.code_rounded,
              color: AppColors.info,
            ),
            const SizedBox(width: 10),
            Text(loc?.translate('developer') ?? 'Developer'),
          ],
        ),
      ),
      body: DeveloperSettingsTab(
        onShowEditorPreferences: () => showAdaptiveModal<void>(
          context: context,
          builder: (_) => const EditorPreferencesDialogBody(),
        ),
      ),
    );
  }
}
