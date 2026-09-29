// lib/core/app_locale.dart
//
// The app's language settings, shared by SoundPilotApp and the widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The only language of the app. All UI texts are German.
///
/// NOTE: Without it, Flutter's built-in labels (back button tooltip, text
/// selection menu, date picker, ...) are English, and screen readers may read
/// the German texts with the voice of the device language.
const Locale appLocale = Locale('de');

/// The languages the app supports. Add a locale here (and to
/// `CFBundleLocalizations` in `ios/Runner/Info.plist`) when the UI texts are
/// translated.
const List<Locale> appSupportedLocales = [appLocale];

/// Translations of Flutter's built-in Material, Cupertino and widget labels.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];
