// test/core/app_locale_test.dart
//
// Checks that the app's locale settings make Flutter's built-in labels German.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';

void main() {
  testWidgets('built-in labels are German, even on an English device',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: Builder(builder: (context) {
        captured = context;
        return const SizedBox();
      }),
    ));

    expect(Localizations.localeOf(captured), const Locale('de'));
    final material = MaterialLocalizations.of(captured);
    expect(material.backButtonTooltip, 'Zurück');
    expect(material.okButtonLabel, 'OK');
    expect(material.cancelButtonLabel, 'Abbrechen');
  });

  testWidgets('a back button reads its tooltip in German', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(body: BackButton()),
    ));

    expect(find.byTooltip('Zurück'), findsOneWidget);
  });
}
