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
    final locales = LocaleProvider.supportedLocales;

    final selected = await showModalBottomSheet<Locale>(
      context: context,
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
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: cs.surface.withValues(alpha: isDark ? 0.72 : 0.86),
      side: BorderSide(
        color: cs.outlineVariant.withValues(alpha: isDark ? 0.45 : 0.75),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showThemeSheet(context),
          style: buttonStyle,
          icon: const Icon(Icons.palette_outlined, size: 18),
          label: Text(
            loc?.translate('theme_title') ?? 'Theme',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _showLanguageSheet(context),
          style: buttonStyle,
          icon: const Icon(Icons.language_outlined, size: 18),
          label: Text(
            loc?.translate('language') ?? 'Language',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
