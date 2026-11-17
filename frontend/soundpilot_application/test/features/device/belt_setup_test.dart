// test/features/device/belt_setup_test.dart
//
// Tests that the two belt setup steps start with the stored values, reject
// values outside BeltCalib's ranges with a message, and return the edited
// belt only when the setup is finished.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/features/device/screens/belt_vibration_screen.dart';
import 'package:soundpilot_application/features/device/screens/belt_warning_distance_screen.dart';
import 'package:soundpilot_application/features/device/widgets/belt_setup_fields.dart';
import 'package:soundpilot_application/models/user_model.dart';

final _stored = BeltCalib(
  modelId: 'Gürtel 1',
  warningDistanceCm: 300,
  vibrationStrength: 70,
  vibrationSide: BeltSide.right,
);

const _distanceError = 'Bitte einen Wert von 50 bis 500 cm eingeben.';
const _strengthError = 'Bitte einen Wert von 50 bis 100 % eingeben.';

/// Opens the setup for [belt] from a start page and returns a function that
/// reads what the setup popped with (`null` until it pops, or if it pops
/// without a result).
Future<BeltCalib? Function()> _openSetup(
  WidgetTester tester,
  BeltCalib belt,
) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  BeltCalib? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.push<BeltCalib>(
              context,
              MaterialPageRoute(
                builder: (_) => BeltWarningDistanceScreen(belt: belt),
              ),
            );
          },
          child: const Text('Öffnen'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Öffnen'));
  await tester.pumpAndSettle();
  return () => result;
}

/// Taps the button with [label], scrolling it into view first.
Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('both steps start with the stored values', (tester) async {
    await _openSetup(tester, _stored);

    expect(_fieldText(tester), '300');

    await _tapButton(tester, 'Weiter');

    expect(find.byType(BeltVibrationScreen), findsOneWidget);
    expect(_fieldText(tester), '70');
    expect(
      tester.getSemantics(find.text('Rechts')),
      isSemantics(label: 'Rechts', isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Mitte')),
      isSemantics(label: 'Mitte', isSelected: false),
    );
  });

  testWidgets('finishing returns the belt with the entered values', (
    tester,
  ) async {
    final result = await _openSetup(tester, _stored);

    await tester.enterText(find.byType(TextField), '450');
    await _tapButton(tester, 'Weiter');
    await tester.enterText(find.byType(TextField), '55');
    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();
    await _tapButton(tester, 'Abschließen');

    expect(find.byType(BeltWarningDistanceScreen), findsNothing);
    final belt = result()!;
    expect(belt.modelId, 'Gürtel 1');
    expect(belt.warningDistanceCm, 450);
    expect(belt.vibrationStrength, 55);
    expect(belt.vibrationSide, BeltSide.left);
  });

  testWidgets('going back from either step returns nothing', (tester) async {
    final result = await _openSetup(tester, _stored);

    await tester.enterText(find.byType(TextField), '450');
    await _tapButton(tester, 'Weiter');
    await tester.tap(find.byTooltip('Zurück').last);
    await tester.pumpAndSettle();

    // Back on the first step, which still holds what was typed.
    expect(find.byType(BeltWarningDistanceScreen), findsOneWidget);
    expect(_fieldText(tester), '450');

    await tester.tap(find.byTooltip('Zurück').last);
    await tester.pumpAndSettle();

    expect(find.byType(BeltWarningDistanceScreen), findsNothing);
    expect(result(), isNull);
  });

  group('a distance outside 50–500 cm', () {
    for (final text in ['', '49', '501']) {
      testWidgets('"$text" is rejected with a message', (tester) async {
        await _openSetup(tester, _stored);

        await tester.enterText(find.byType(TextField), text);
        await _tapButton(tester, 'Weiter');

        expect(find.byType(BeltVibrationScreen), findsNothing);
        expect(find.text(_distanceError), findsOneWidget);
      });
    }

    testWidgets('the limits themselves are allowed', (tester) async {
      await _openSetup(tester, _stored);

      await tester.enterText(find.byType(TextField), '500');
      await _tapButton(tester, 'Weiter');

      expect(find.byType(BeltVibrationScreen), findsOneWidget);
    });

    testWidgets('the message goes away once the field is changed', (
      tester,
    ) async {
      await _openSetup(tester, _stored);

      await tester.enterText(find.byType(TextField), '20');
      await _tapButton(tester, 'Weiter');
      expect(find.text(_distanceError), findsOneWidget);

      await tester.enterText(find.byType(TextField), '200');
      await tester.pump();

      expect(find.text(_distanceError), findsNothing);
    });
  });

  group('a strength outside 50–100 %', () {
    for (final text in ['', '49', '101']) {
      testWidgets('"$text" is rejected with a message', (tester) async {
        final result = await _openSetup(tester, _stored);
        await _tapButton(tester, 'Weiter');

        await tester.enterText(find.byType(TextField), text);
        await _tapButton(tester, 'Abschließen');

        expect(find.byType(BeltVibrationScreen), findsOneWidget);
        expect(find.text(_strengthError), findsOneWidget);
        expect(result(), isNull);
      });
    }
  });

  testWidgets('the message is a live region with an icon, not colour alone', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openSetup(tester, _stored);

    await tester.enterText(find.byType(TextField), '20');
    await _tapButton(tester, 'Weiter');

    expect(
      tester.getSemantics(find.byType(BeltFieldError)),
      isSemantics(label: _distanceError, isLiveRegion: true),
    );
    expect(
      find.descendant(
        of: find.byType(BeltFieldError),
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  group('parseBeltValue', () {
    test('accepts whole numbers within the range', () {
      expect(parseBeltValue('50', min: 50, max: 100), 50);
      expect(parseBeltValue(' 100 ', min: 50, max: 100), 100);
    });

    test('rejects empty, out-of-range and non-numeric text', () {
      expect(parseBeltValue('', min: 50, max: 100), isNull);
      expect(parseBeltValue('49', min: 50, max: 100), isNull);
      expect(parseBeltValue('101', min: 50, max: 100), isNull);
      expect(parseBeltValue('abc', min: 50, max: 100), isNull);
    });
  });
}
