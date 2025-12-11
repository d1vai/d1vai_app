import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final locales = LocaleProvider.supportedLocales;

    return Scaffold(
      appBar: AppBar(title: Text(loc?.translate('language') ?? 'Language')),
      body: ListView.separated(
        itemCount: locales.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final locale = locales[index];
          final key = LocaleProvider.languageKeyFromLocale(locale);
          final name = LocaleProvider.languageNames[key] ?? key;

          final current = localeProvider.locale;
          final isSelected =
              locale.languageCode == current.languageCode &&
              (locale.scriptCode ?? '') == (current.scriptCode ?? '') &&
              (locale.countryCode ?? '') == (current.countryCode ?? '');

          return ListTile(
            title: Text(name),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : null,
            onTap: () async {
              await localeProvider.setLocale(locale);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          );
        },
      ),
    );
  }
}
