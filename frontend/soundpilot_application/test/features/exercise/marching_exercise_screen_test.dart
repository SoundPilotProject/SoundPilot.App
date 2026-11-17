// test/features/exercise/marching_exercise_screen_test.dart
//
// The guided marching exercise: that it plays its recording once, moves the
// sound to the side of each cue with a glide, and ends by itself.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/core/services/audio_device_service.dart';
import 'package:soundpilot_application/features/device/volume_scale.dart';
import 'package:soundpilot_application/features/exercise/marching_exercise.dart';
import 'package:soundpilot_application/features/exercise/screens/marching_exercise_screen.dart';
import 'package:soundpilot_application/features/exercise/spatial_audio.dart';

const _pods = HeadphoneDevice(
  name: 'Pods',
  address: 'AA',
  isConnected: true,
  outputDeviceId: 7,
);

/// Gain of the quieter ear at ±45°: the equal-power ratio over the calibration.
double _quiet(int volume) => math.tan(math.pi / 8) * wheelToGain(volume);

/// Pumps the screen (left 30, right 90, key `AA`) on a phone-sized view.
Future<void> _pumpScreen(
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
    home: MarchingExerciseScreen(
      leftVolume: 30,
      rightVolume: 90,
      address: 'AA',
      headphoneChanges: () => headphones,
      soundSupported: soundSupported,
    ),
  ));
  await tester.pump();
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

  Iterable<String> methods() => calls.map((call) => call.method);

  /// Lets [duration] of the recording pass and the channel calls arrive.
  Future<void> advance(WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
    await tester.pump();
  }

  /// Starts the exercise on the connected earbud.
  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('Start'));
    await tester.pump();
  }

  testWidgets('plays the recording once, centred, with the calibrated gains',
      (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));

    await start(tester);

    expect(calls.single.method, 'playTestSound');
    expect(calls.single.arguments, {
      'asset': marchingAsset,
      'leftGain': wheelToGain(30),
      'rightGain': wheelToGain(90),
      'deviceId': 7,
      // Once: the recording ends with a closing sentence.
      'loop': false,
    });
    expect(find.textContaining('Übung läuft über die Kopfhörer – Ton mittig'),
        findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });

  testWidgets('moves the sound to the side the recording names',
      (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);
    calls.clear();

    // 21.4 s: "Verlagern Sie Ihr Gewicht … auf Ihr linkes Bein".
    await advance(tester, marchingCues.first.at);

    expect(calls.single.method, 'setPlaybackGain');
    final left = calls.single.arguments as Map;
    expect(left['leftGain'], wheelToGain(30));
    expect(left['rightGain'], closeTo(_quiet(90), 1e-12));
    // Glided, not switched: a jump is heard as a second sound.
    expect(left['rampMs'], panRamp.inMilliseconds);
    expect(find.textContaining('Ton links – das linke Bein'), findsOneWidget);

    // 28.6 s: the recording moves on and so does the sound.
    calls.clear();
    await advance(tester, marchingCues[1].at - marchingCues[0].at);

    final centre = calls.single.arguments as Map;
    expect(centre['leftGain'], wheelToGain(30));
    expect(centre['rightGain'], wheelToGain(90));
    expect(find.textContaining('Ton mittig'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });

  testWidgets('plays every cue of the recording in order', (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);
    calls.clear();

    var elapsed = Duration.zero;
    for (final cue in marchingCues) {
      await advance(tester, cue.at - elapsed);
      elapsed = cue.at;
    }

    expect(methods().where((method) => method == 'setPlaybackGain').length,
        marchingCues.length);

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });

  testWidgets('ends by itself without stopping the native side',
      (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await advance(tester, marchingDuration);
    // Still running a moment before the end, so the closing sentence is not
    // cut off.
    expect(find.textContaining('Übung läuft'), findsOneWidget);

    await advance(tester, const Duration(seconds: 1));

    // The native side stopped at the end of the file on its own; the screen
    // only follows.
    expect(methods(), isNot(contains('stopPlayback')));
    expect(find.textContaining('Übung gestoppt'), findsOneWidget);
  });

  testWidgets('Stop ends the exercise and its cues', (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(methods().last, 'stopPlayback');
    calls.clear();

    // No cue and no end timer are left behind.
    await advance(tester, marchingDuration * 2);
    expect(calls, isEmpty);
    expect(find.textContaining('Übung gestoppt'), findsOneWidget);
  });

  testWidgets('Start begins the exercise again from its beginning',
      (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);
    await advance(tester, marchingCues.first.at);
    calls.clear();

    await start(tester);

    expect(calls.single.method, 'playTestSound');
    expect(find.textContaining('Ton mittig'), findsOneWidget);

    // The first cue comes again, so the old schedule is gone.
    calls.clear();
    await advance(tester, marchingCues.first.at);
    expect(calls.single.method, 'setPlaybackGain');

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });

  testWidgets('without an earbud it plays on the phone itself',
      (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const []));

    expect(find.textContaining('Kopfhörer sind nicht verbunden'),
        findsOneWidget);

    await start(tester);

    expect((calls.single.arguments as Map)['deviceId'], isNull);
    expect(find.textContaining('über den Lautsprecher'), findsWidgets);

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });

  testWidgets('a disconnecting earbud ends the exercise', (tester) async {
    final headphones = StreamController<List<HeadphoneDevice>>(sync: true);
    addTearDown(headphones.close);
    await _pumpScreen(tester, headphones: headphones.stream);
    headphones.add(const [_pods]);
    await tester.pump();
    await start(tester);

    headphones.add(const []);
    await tester.pump();
    calls.clear();

    expect(find.textContaining('Übung gestoppt'), findsOneWidget);
    // No cue moves on after that.
    await advance(tester, marchingDuration);
    expect(calls, isEmpty);
  });

  testWidgets('stops when the app goes to the background', (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(methods().last, 'stopPlayback');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('stops when the screen is left', (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(methods().last, 'stopPlayback');
  });

  testWidgets('says that the exercise is only in the Android app',
      (tester) async {
    await _pumpScreen(tester,
        headphones: Stream.value(const []), soundSupported: false);

    expect(find.text('Die Übung gibt es nur in der Android-App.'),
        findsOneWidget);

    final start = tester.widget<ElevatedButton>(
      find.ancestor(of: find.text('Start'), matching: find.byType(ElevatedButton)),
    );
    expect(start.onPressed, isNull);
  });
}
