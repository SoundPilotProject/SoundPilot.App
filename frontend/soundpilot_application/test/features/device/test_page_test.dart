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

/// Whether the 'Start' button can be tapped.
bool _startEnabled(WidgetTester tester) {
  final button = tester.widget<ButtonStyleButton>(find.ancestor(
    of: find.text('Start'),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  ));
  return button.onPressed != null;
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

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(methods().last, 'stopPlayback');
  });

  testWidgets('cannot start while the earbud is not connected',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const []));

    expect(find.textContaining('Verbinde zuerst deine Kopfhörer'),
        findsOneWidget);
    expect(_startEnabled(tester), isFalse);
  });

  testWidgets('says that the sound is only in the Android app',
      (tester) async {
    await _pumpPage(tester,
        headphones: Stream.value(const []), soundSupported: false);

    expect(find.text('Die Aufnahme gibt es nur in der Android-App.'),
        findsOneWidget);
    expect(_startEnabled(tester), isFalse);
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
    expect(_startEnabled(tester), isFalse);
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
