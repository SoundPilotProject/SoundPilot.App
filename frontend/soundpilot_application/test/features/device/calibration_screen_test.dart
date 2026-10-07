// test/features/device/calibration_screen_test.dart
//
// Tests that the CalibrationScreen works on one earbud: it starts at that
// earbud's saved volumes and hands the chosen ones back as a copy of it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/features/device/screens/calibration.dart';
import 'package:soundpilot_application/models/user_model.dart';

/// Pumps a [CalibrationScreen] for [calib] on a phone-sized view; every saved
/// calibration is added to [saved].
Future<void> _pumpScreen(
  WidgetTester tester,
  HeadphoneCalib calib,
  List<HeadphoneCalib> saved,
) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: CalibrationScreen(
      calib: calib,
      onSave: (updated) async => saved.add(updated),
    ),
  ));
}

/// The scroll wheel of the left (`0`) or right (`1`) side.
FixedExtentScrollController _wheel(WidgetTester tester, int side) {
  final wheel =
      tester.widget<ListWheelScrollView>(find.byType(ListWheelScrollView).at(side));
  return wheel.controller! as FixedExtentScrollController;
}

void main() {
  group('volume conversion', () {
    test('stored volume maps to the wheel value', () {
      expect(volumeToWheel(0.5), 50);
      expect(volumeToWheel(0.734), 73);
      expect(volumeToWheel(1.0), 100);
    });

    test('values outside the wheel are clamped to 1..100', () {
      expect(volumeToWheel(0.0), 1);
      expect(volumeToWheel(1.7), 100);
    });

    test('every wheel value survives the round trip', () {
      for (var value = 1; value <= 100; value++) {
        expect(volumeToWheel(wheelToVolume(value)), value);
      }
    });
  });

  group('CalibrationScreen', () {
    testWidgets('starts at the volumes of the earbud', (tester) async {
      await _pumpScreen(
        tester,
        HeadphoneCalib(modelId: 'Pods', volumeLeft: 0.3, volumeRight: 0.7),
        [],
      );

      expect(_wheel(tester, 0).selectedItem, 29);
      expect(_wheel(tester, 1).selectedItem, 69);
      // What a screen reader announces for the left wheel.
      final left = tester.widget<Semantics>(find.byWidgetPredicate((w) =>
          w is Semantics && w.properties.label == 'Linke Seite, Lautstärke'));
      expect(left.properties.value, '30 von 100');
    });

    testWidgets('saves the chosen volumes into a copy of the earbud',
        (tester) async {
      final saved = <HeadphoneCalib>[];
      await _pumpScreen(
        tester,
        HeadphoneCalib(
          modelId: 'Pods',
          volumeLeft: 0.3,
          volumeRight: 0.7,
          isConnected: true,
        ),
        saved,
      );

      _wheel(tester, 0).jumpToItem(59); // left: 60
      await tester.pump();

      await tester.ensureVisible(find.text('Test-Übung'));
      await tester.tap(find.text('Test-Übung'));
      await tester.pump();

      expect(saved, hasLength(1));
      expect(saved.single.modelId, 'Pods');
      expect(saved.single.volumeLeft, 0.6);
      expect(saved.single.volumeRight, 0.7);
      expect(saved.single.isConnected, isTrue);
    });
  });
}
