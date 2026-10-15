// test/features/device/test_page_test.dart
//
// Tests that the TestPage plays its sound on the calibrated earbud with the
// calibrated gains, and only while the earbud is connected.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/core/services/audio_device_service.dart';
import 'package:soundpilot_application/features/device/screens/test_page.dart';
import 'package:soundpilot_application/features/device/volume_scale.dart';

const _pods = HeadphoneDevice(
  name: 'Pods',
  address: 'aa',
  isConnected: true,
  outputDeviceId: 7,
);

/// Pumps a [TestPage] (left 30, right 90, key `AA`) on a phone-sized view.
Future<void> _pumpPage(
  WidgetTester tester, {
  required Stream<List<HeadphoneDevice>> headphones,
  bool soundSupported = true,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: TestPage(
      leftVolume: 30,
      rightVolume: 90,
      address: 'AA',
      headphoneChanges: () => headphones,
      soundSupported: soundSupported,
    ),
  ));
  await tester.pump();
}

/// The label of the one playback control the page offers, or null if it
/// offers none.
///
/// NOTE: The page shows the button that applies ('Start', 'Stop' or the way
/// to the Bluetooth settings) instead of greying out the ones that do not, so
/// there is never a button that cannot be used.
String? _controlLabel(WidgetTester tester) {
  final buttons = find.byType(ElevatedButton);
  for (var i = 0; i < buttons.evaluate().length; i++) {
    final label = find.descendant(of: buttons.at(i), matching: find.byType(Text));
    final text = tester.widget<Text>(label.first).data;
    // 'Abschließen' is the button that leaves the page, not a control.
    if (text != null && text != 'Abschließen') return text;
  }
  return null;
}

void main() {
  const channel = MethodChannel('com.soundpilot/audio_devices');
  final calls = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Iterable<String> methods() => calls.map((c) => c.method);

  testWidgets('plays the sound on the earbud with the calibrated gains',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(calls.single.method, 'playTestSound');
    expect(calls.single.arguments, {
      'asset': testSoundAsset,
      'leftGain': wheelToGain(30),
      'rightGain': wheelToGain(90),
      'deviceId': 7,
    });
    expect(find.textContaining('Wiedergabe läuft'), findsOneWidget);
    // While it plays, 'Stop' is the control, not a second grey button.
    expect(_controlLabel(tester), 'Stop');

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(methods().last, 'stopPlayback');
    expect(_controlLabel(tester), 'Start');
  });

  testWidgets('offers the Bluetooth settings while the earbud is not connected',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const []));

    expect(find.textContaining('Verbinde zuerst deine Kopfhörer'),
        findsOneWidget);
    // Not a greyed-out 'Start' but the way forward, and it works.
    expect(_controlLabel(tester), 'Bluetooth-Einstellungen öffnen');

    await tester.tap(find.text('Bluetooth-Einstellungen öffnen'));
    await tester.pump();
    expect(methods().last, 'openBluetoothSettings');
  });

  testWidgets('says that the sound is only in the Android app',
      (tester) async {
    await _pumpPage(tester,
        headphones: Stream.value(const []), soundSupported: false);

    expect(find.text('Die Aufnahme gibt es nur in der Android-App.'),
        findsOneWidget);
    // Nothing to offer here, so no control at all.
    expect(_controlLabel(tester), isNull);
  });

  testWidgets('follows when the earbud disconnects', (tester) async {
    final headphones = StreamController<List<HeadphoneDevice>>(sync: true);
    addTearDown(headphones.close);
    await _pumpPage(tester, headphones: headphones.stream);
    headphones.add(const [_pods]);
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();

    headphones.add(const []);
    await tester.pump();

    // The native side stops the sound itself; the page follows.
    expect(find.textContaining('Wiedergabe gestoppt'), findsOneWidget);
    expect(_controlLabel(tester), 'Bluetooth-Einstellungen öffnen');
  });

  testWidgets('stops when the app goes to the background', (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await tester.tap(find.text('Start'));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(methods().last, 'stopPlayback');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('stops when the page is left', (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await tester.tap(find.text('Start'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(methods().last, 'stopPlayback');
  });
}
