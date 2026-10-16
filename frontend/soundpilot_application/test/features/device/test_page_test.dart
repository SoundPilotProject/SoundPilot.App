// test/features/device/test_page_test.dart
//
// Tests that the TestPage plays its sound with the calibrated gains — on the
// calibrated earbud while that is connected, on the phone itself otherwise —
// and which of its buttons can be used in each state.

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

/// The playback controls on the page: every button but 'Abschließen', which
/// leaves the page. [onlyUsable] drops the ones that are disabled.
///
/// NOTE: 'Start' and 'Stop' are always on the screen; which of them can be
/// used is the state. The Bluetooth button only appears while the earbud is
/// missing, so the screen is never a dead end.
List<String> _controls(WidgetTester tester, {bool onlyUsable = false}) {
  final labels = <String>[];
  final buttons = find.byType(ElevatedButton);
  for (var i = 0; i < buttons.evaluate().length; i++) {
    final button = tester.widget<ElevatedButton>(buttons.at(i));
    final label = find.descendant(of: buttons.at(i), matching: find.byType(Text));
    final text = tester.widget<Text>(label.first).data;
    if (text == null || text == 'Abschließen') continue;
    if (onlyUsable && button.onPressed == null) continue;
    labels.add(text);
  }
  return labels;
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
    // 'Start' keeps its colour and restarts the recording; 'Stop' is only
    // alive while something plays.
    expect(_controls(tester), ['Start', 'Stop']);
    expect(_controls(tester, onlyUsable: true), ['Start', 'Stop']);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(methods().last, 'stopPlayback');
    expect(_controls(tester, onlyUsable: true), ['Start']);
  });

  testWidgets('without an earbud it plays on the phone itself',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const []));

    // 'Start' works here too, otherwise the exercise could not be tried at
    // all before pairing anything.
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(calls.single.method, 'playTestSound');
    // No device: the native side plays on the default output.
    expect((calls.single.arguments as Map)['deviceId'], isNull);
    expect(find.textContaining('über den Lautsprecher'), findsWidgets);
    expect(_controls(tester, onlyUsable: true),
        ['Start', 'Stop', 'Bluetooth-Einstellungen öffnen']);
  });

  testWidgets('sound on the phone survives a headphone change',
      (tester) async {
    final headphones = StreamController<List<HeadphoneDevice>>(sync: true);
    addTearDown(headphones.close);
    await _pumpPage(tester, headphones: headphones.stream);
    headphones.add(const []);
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();

    // Another device comes and goes; only a playback on the earbud is
    // stopped by that, this one is not.
    headphones.add(const []);
    await tester.pump();

    expect(find.textContaining('Wiedergabe läuft'), findsOneWidget);
  });

  testWidgets('offers the Bluetooth settings while the earbud is not connected',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const []));

    expect(find.textContaining('Kopfhörer sind nicht verbunden'),
        findsOneWidget);
    // 'Start' plays on the phone itself, and the way to the earbud is right
    // there for whoever wants to hear the calibration.
    expect(_controls(tester),
        ['Start', 'Stop', 'Bluetooth-Einstellungen öffnen']);
    expect(_controls(tester, onlyUsable: true),
        ['Start', 'Bluetooth-Einstellungen öffnen']);

    // Below the fold on a small phone once the note is there.
    final bluetooth = find.text('Bluetooth-Einstellungen öffnen');
    await tester.ensureVisible(bluetooth);
    await tester.pump();
    await tester.tap(bluetooth);
    await tester.pump();
    expect(methods().last, 'openBluetoothSettings');
  });

  testWidgets('says that the sound is only in the Android app',
      (tester) async {
    await _pumpPage(tester,
        headphones: Stream.value(const []), soundSupported: false);

    expect(find.text('Die Aufnahme gibt es nur in der Android-App.'),
        findsOneWidget);
    // The buttons are shown, but there is no sound at all here, and no
    // Bluetooth settings to send anyone to.
    expect(_controls(tester), ['Start', 'Stop']);
    expect(_controls(tester, onlyUsable: true), isEmpty);
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
    expect(_controls(tester, onlyUsable: true),
        ['Start', 'Bluetooth-Einstellungen öffnen']);
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
