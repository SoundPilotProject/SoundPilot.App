// test/features/device/calibration_screen_test.dart
//
// Tests that the CalibrationScreen works on one earbud: it starts at that
// earbud's saved volumes, hands the chosen ones back as a copy of it, and
// plays the test tone only on the connected earbud.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/core/services/audio_device_service.dart';
import 'package:soundpilot_application/features/device/screens/calibration_screen.dart';
import 'package:soundpilot_application/features/device/volume_scale.dart';
import 'package:soundpilot_application/models/user_model.dart';

/// Pumps a [CalibrationScreen] for [calib] (key `AA`) on a phone-sized view;
/// every saved calibration is added to [saved]. [headphones] are the connected
/// headphones (none by default).
Future<void> _pumpScreen(
  WidgetTester tester,
  HeadphoneCalib calib,
  List<HeadphoneCalib> saved, {
  Stream<List<HeadphoneDevice>>? headphones,
  bool toneSupported = true,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: CalibrationScreen(
      calib: calib,
      address: 'AA',
      onSave: (updated) async => saved.add(updated),
      headphoneChanges: () => headphones ?? Stream.value(const []),
      toneSupported: toneSupported,
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

  group('wheelToGain', () {
    test('runs from -40 dB at 1 to 0 dB at 100', () {
      expect(wheelToGain(100), 1.0);
      expect(wheelToGain(1), closeTo(0.01, 1e-9));
    });

    test('every step changes the gain by the same factor', () {
      final ratio = wheelToGain(2) / wheelToGain(1);
      for (var value = 2; value <= 100; value++) {
        expect(wheelToGain(value) / wheelToGain(value - 1),
            closeTo(ratio, 1e-9));
      }
    });

    test('clamps values outside 1-100', () {
      expect(wheelToGain(0), wheelToGain(1));
      expect(wheelToGain(140), 1.0);
    });
  });

  group('test tone', () {
    const channel = MethodChannel('com.soundpilot/audio_devices');
    final calls = <MethodCall>[];
    PlatformException? playError;

    const pods = HeadphoneDevice(
      name: 'Pods',
      address: 'aa',
      isConnected: true,
      outputDeviceId: 7,
    );

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'playTestTone' && playError != null) {
          throw playError!;
        }
        return null;
      });
    });

    tearDown(() {
      calls.clear();
      playError = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Iterable<String> methods() => calls.map((c) => c.method);

    testWidgets('is not offered while the earbud is not connected',
        (tester) async {
      await _pumpScreen(tester, HeadphoneCalib(modelId: 'Pods'), []);
      await tester.pump();

      expect(find.textContaining('Verbinde zuerst deine Kopfhörer'),
          findsOneWidget);
      expect(find.text('Testton abspielen'), findsNothing);
      expect(find.text('Bluetooth-Einstellungen öffnen'), findsOneWidget);
    });

    testWidgets('is only in the Android app', (tester) async {
      await _pumpScreen(tester, HeadphoneCalib(modelId: 'Pods'), [],
          toneSupported: false);
      await tester.pump();

      expect(find.text('Den Testton gibt es nur in der Android-App.'),
          findsOneWidget);
      expect(find.text('Testton abspielen'), findsNothing);
    });

    testWidgets('plays on the earbud with the gains of the wheels',
        (tester) async {
      await _pumpScreen(
        tester,
        HeadphoneCalib(modelId: 'Pods', volumeLeft: 0.3, volumeRight: 1.0),
        [],
        headphones: Stream.value(const [pods]),
      );
      await tester.pump();

      await tester.tap(find.text('Testton abspielen'));
      await tester.pump();

      expect(calls.single.method, 'playTestTone');
      expect(calls.single.arguments, {
        'leftGain': wheelToGain(30),
        'rightGain': 1.0,
        'deviceId': 7,
      });
      expect(find.text('Testton stoppen'), findsOneWidget);

      await tester.tap(find.text('Testton stoppen'));
      await tester.pump();
      expect(methods().last, 'stopTestTone');
      expect(find.text('Testton abspielen'), findsOneWidget);
    });

    testWidgets('a wheel change reaches the playing tone at once',
        (tester) async {
      await _pumpScreen(tester, HeadphoneCalib(modelId: 'Pods'), [],
          headphones: Stream.value(const [pods]));
      await tester.pump();
      await tester.tap(find.text('Testton abspielen'));
      await tester.pump();

      _wheel(tester, 1).jumpToItem(79); // right: 80
      await tester.pump();

      expect(calls.last.method, 'setTestToneGain');
      expect(calls.last.arguments,
          {'leftGain': wheelToGain(50), 'rightGain': wheelToGain(80)});
    });

    testWidgets('stops when the earbud disconnects', (tester) async {
      final headphones = StreamController<List<HeadphoneDevice>>(sync: true);
      addTearDown(headphones.close);
      await _pumpScreen(tester, HeadphoneCalib(modelId: 'Pods'), [],
          headphones: headphones.stream);
      headphones.add(const [pods]);
      await tester.pump();
      await tester.tap(find.text('Testton abspielen'));
      await tester.pump();

      headphones.add(const []);
      await tester.pump();

      // The native side stops the tone itself; the screen follows.
      expect(find.text('Testton stoppen'), findsNothing);
      expect(find.textContaining('Verbinde zuerst deine Kopfhörer'),
          findsOneWidget);
    });

    testWidgets('stops when the app goes to the background', (tester) async {
      await _pumpScreen(tester, HeadphoneCalib(modelId: 'Pods'), [],
          headphones: Stream.value(const [pods]));
      await tester.pump();
      await tester.tap(find.text('Testton abspielen'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(methods().last, 'stopTestTone');
      expect(find.text('Testton abspielen'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('stops when the screen is left', (tester) async {
      await _pumpScreen(tester, HeadphoneCalib(modelId: 'Pods'), [],
          headphones: Stream.value(const [pods]));
      await tester.pump();
      await tester.tap(find.text('Testton abspielen'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(methods().last, 'stopTestTone');
    });

    testWidgets('says so if the earbud was gone when the tone started',
        (tester) async {
      playError = PlatformException(code: 'DEVICE_NOT_CONNECTED');
      await _pumpScreen(tester, HeadphoneCalib(modelId: 'Pods'), [],
          headphones: Stream.value(const [pods]));
      await tester.pump();

      await tester.tap(find.text('Testton abspielen'));
      await tester.pump();

      expect(find.text('Die Kopfhörer sind nicht mehr verbunden.'),
          findsOneWidget);
      expect(find.text('Testton abspielen'), findsOneWidget);
    });
  });
}
