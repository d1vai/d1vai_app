import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../snackbar_helper.dart';

class AuthDisplayControls extends StatelessWidget {
  const AuthDisplayControls({super.key});

  Future<void> _showThemeSheet(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final options = <({AppThemeMode mode, IconData icon, String label})>[
      (
        mode: AppThemeMode.light,
        icon: Icons.light_mode_outlined,
        label: loc?.translate('light_mode') ?? 'Light Mode',
      ),
      (
        mode: AppThemeMode.dark,
        icon: Icons.dark_mode_outlined,
        label: loc?.translate('dark_mode') ?? 'Dark Mode',
      ),
      (
        mode: AppThemeMode.system,
        icon: Icons.brightness_auto_outlined,
        label: loc?.translate('system_mode') ?? 'System',
      ),
    ];

    final selected = await showModalBottomSheet<AppThemeMode>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final currentMode = context.watch<ThemeProvider>().themeMode;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(loc?.translate('choose_theme') ?? 'Choose Theme'),
              ),
              ...options.map(
                (item) => ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  trailing: currentMode == item.mode
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(item.mode),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await themeProvider.setThemeMode(selected);
    if (!context.mounted) return;
    final label = options.firstWhere((item) => item.mode == selected).label;
    SnackBarHelper.showSuccess(
      context,
      title: loc?.translate('theme_updated') ?? 'Theme Updated',
      message: '${loc?.translate('theme_switched') ?? 'Switched to'} $label',
    );
  }

  Future<void> _showLanguageSheet(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final locales = LocaleProvider.settingsSupportedLocales;

    final selected = await showModalBottomSheet<Locale>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final current = context.watch<LocaleProvider>().locale;
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(loc?.translate('language') ?? 'Language')),
              ...locales.map((locale) {
                final key = LocaleProvider.languageKeyFromLocale(locale);
                final name = LocaleProvider.languageNames[key] ?? key;
                final isSelected =
                    locale.languageCode == current.languageCode &&
                    (locale.scriptCode ?? '') == (current.scriptCode ?? '') &&
                    (locale.countryCode ?? '') == (current.countryCode ?? '');
                return ListTile(
                  title: Text(name),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(locale),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await localeProvider.setLocale(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final loc = AppLocalizations.of(context);
    final themeLabel = loc?.translate('theme_title') ?? 'Theme';
    final languageLabel = loc?.translate('language') ?? 'Language';

    ButtonStyle buttonStyle() => IconButton.styleFrom(
      minimumSize: const Size.square(40),
      maximumSize: const Size.square(40),
      backgroundColor: cs.surfaceContainerLowest,
      foregroundColor: cs.onSurfaceVariant,
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.72)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _showThemeSheet(context),
          style: buttonStyle(),
          tooltip: themeLabel,
          icon: const Icon(Icons.contrast_rounded, size: 19),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showLanguageSheet(context),
          style: buttonStyle(),
          tooltip: languageLabel,
          icon: const Icon(Icons.language_rounded, size: 19),
        ),
      ],
    );
  }
}
