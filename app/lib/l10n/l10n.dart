/// App localization entry point: generated [AppLocalizations] (gen-l10n,
/// ARB files in this folder), the delegates/locales for `MaterialApp` and the
/// language preference rules.
library;

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:material_ui/material_ui.dart';

import '../core/config/settings_store.dart';
import 'generated/app_localizations.dart';

export '../core/config/settings_store.dart' show AppLanguage;
export 'generated/app_localizations.dart';

extension AppLanguageLocale on AppLanguage {
  /// The forced locale, or null to follow the device/browser.
  Locale? get locale => code == null ? null : Locale(code!);
}

/// App strings + Material/Cupertino/Widgets (material_ui's own delegates,
/// not flutter_localizations' ones, which target `package:flutter/material`).
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

const List<Locale> appSupportedLocales = [Locale('en'), Locale('es')];

/// Device locales → app locale: the first `es*` or `en*` in the device's
/// preference list wins; anything else falls back to English.
Locale resolveAppLocale(Iterable<Locale>? deviceLocales) {
  for (final l in deviceLocales ?? const <Locale>[]) {
    if (l.languageCode == 'es') return const Locale('es');
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

/// Strings outside the widget tree (e.g. before `runApp`): the preferred
/// language, else the platform locale.
AppLocalizations appStringsFor(AppLanguage language) =>
    lookupAppLocalizations(language.locale ?? resolveAppLocale(PlatformDispatcher.instance.locales));

extension AppLocalizationsContext on BuildContext {
  /// `context.l10n.settings`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
