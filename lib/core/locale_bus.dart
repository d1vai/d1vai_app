import 'package:flutter/widgets.dart';

/// Minimal global locale holder to support localization in layers that don't
/// have a BuildContext (e.g. providers/utils).
///
/// This is intentionally tiny: LocaleProvider is the source of truth and should
/// update this whenever the user changes language.
class LocaleBus {
  static Locale _locale = const Locale('en');

  static Locale get locale => _locale;

  static void set(Locale locale) {
    _locale = locale;
  }
}
