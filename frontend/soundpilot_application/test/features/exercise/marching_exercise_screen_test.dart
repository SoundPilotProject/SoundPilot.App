// test/features/exercise/marching_exercise_screen_test.dart
//
// The guided marching exercise: that it plays its recording once with the
// whole cue list, follows the cues on screen without touching a gain, ends on
// the native event (and on its own timer if that never comes), and says when a
// system setting makes the direction inaudible.

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

/// Gain of the quieter ear at ±45°: the equal-power ratio over the
/// calibration.
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
  // The mocked channels are reached before the first test runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.soundpilot/audio_devices');
  const playbackEvents = EventChannel('com.soundpilot/playback_events');

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  /// What the mocked native side answers, per method.
  final answers = <String, Object?>{};

  /// The native side's end-of-playback event sink.
  MockStreamHandlerEventSink? endEvents;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      // Asked for when the screen opens and of no interest to most tests.
      if (call.method != 'getAudioAccessibility') calls.add(call);
      return answers[call.method];
    });
    messenger.setMockStreamHandler(
      playbackEvents,
      MockStreamHandler.inline(
        // Block bodies: what these return is sent over the channel.
        onListen: (_, sink) {
          endEvents = sink;
        },
        onCancel: (_) {
          endEvents = null;
        },
      ),
    );
  });

  tearDown(() {
    calls.clear();
    answers.clear();
    endEvents = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockStreamHandler(playbackEvents, null);
  });

  Iterable<String> methods() => calls.map((call) => call.method);

  /// Lets [duration] of the recording pass and the channel calls arrive.
  Future<void> advance(WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
    await tester.pump();
  }

  /// Starts the exercise.
  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('Start'));
    await tester.pump();
  }

  testWidgets('plays the recording once, centred, with its whole cue list',
      (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));

    await start(tester);

    expect(calls.single.method, 'playTestSound');
    final arguments = calls.single.arguments as Map;
    expect(arguments['asset'], marchingAsset);
    expect(arguments['leftGain'], wheelToGain(30));
    expect(arguments['rightGain'], wheelToGain(90));
    expect(arguments['deviceId'], 7);
    // Once: the recording ends with a closing sentence.
    expect(arguments['loop'], isFalse);
    expect(find.textContaining('Übung läuft über die Kopfhörer – Ton mittig'),
        findsOneWidget);

    // The directions go along with the start, so the native player can apply
    // them at their point in the samples instead of a timer here guessing.
    final cues = (arguments['cues'] as List).cast<Map<dynamic, dynamic>>();
    expect(cues.length, marchingCues.length);
    expect(
      cues.map((cue) => cue['atMs']).toList(),
      marchingCues.map((cue) => cue.at.inMilliseconds).toList(),
    );
    expect(cues.first['leftGain'], wheelToGain(30));
    expect(cues.first['rightGain'], closeTo(_quiet(90), 1e-12));
    expect(cues.first['rampMs'], panRamp.inMilliseconds);
    // The centre cue after it: both ears at their calibrated volume again.
    expect(cues[1]['leftGain'], wheelToGain(30));
    expect(cues[1]['rightGain'], wheelToGain(90));

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });

  testWidgets('the status line follows the cues without touching a gain',
      (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);
    calls.clear();

    // 21.4 s: "Verlagern Sie Ihr Gewicht … auf Ihr linkes Bein".
    await advance(tester, marchingCues.first.at);
    expect(find.textContaining('Ton links – das linke Bein'), findsOneWidget);

    // 28.6 s: the recording moves on and so does the sound.
    await advance(tester, marchingCues[1].at - marchingCues[0].at);
    expect(find.textContaining('Ton mittig'), findsOneWidget);

    // The sound itself is the native player's business: nothing is sent.
    expect(calls, isEmpty);

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });

  testWidgets('every cue reaches the status line', (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    final seen = <String>[];
    var elapsed = Duration.zero;
    for (final cue in marchingCues) {
      await advance(tester, cue.at - elapsed);
      elapsed = cue.at;
      seen.add(tester
          .widgetList<Text>(find.textContaining('Übung läuft'))
          .first
          .data!);
    }

    for (var index = 0; index < marchingCues.length; index++) {
      expect(seen[index], contains(marchingCues[index].label));
    }

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });

  testWidgets('the native end event ends the exercise', (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    // The native side reports the end once it has really been heard.
    //
    // NOTE: runAsync, because the event travels over the platform channel,
    // and that is real asynchronous work which the fake clock of a widget
    // test does not drive.
    await tester.runAsync(() async {
      endEvents!.success('ended');
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    expect(find.textContaining('Übung gestoppt'), findsOneWidget);
    // It stopped by itself; nothing has to be stopped here.
    expect(methods(), isNot(contains('stopPlayback')));
  });

  testWidgets('ends on its own timer if the event never comes',
      (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await advance(tester, marchingDuration);
    // Still running: the closing sentence may well still be on its way
    // through Bluetooth at this point.
    expect(find.textContaining('Übung läuft'), findsOneWidget);

    await advance(tester, MarchingExerciseScreen.endMargin);

    expect(find.textContaining('Übung gestoppt'), findsOneWidget);
    expect(methods(), isNot(contains('stopPlayback')));
  });

  testWidgets('Stop ends the exercise and its cues', (tester) async {
    await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(methods().last, 'stopPlayback');

    // No cue and no end timer are left behind.
    await advance(tester, marchingDuration * 2);
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
    await advance(tester, marchingCues.first.at);
    expect(find.textContaining('Ton links'), findsOneWidget);

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

    expect(find.textContaining('Übung gestoppt'), findsOneWidget);
    // No cue moves the status line on after that.
    await advance(tester, marchingDuration);
    expect(find.textContaining('Übung gestoppt'), findsOneWidget);
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

    final startButton = tester.widget<ElevatedButton>(find.ancestor(
      of: find.text('Start'),
      matching: find.byType(ElevatedButton),
    ));
    expect(startButton.onPressed, isNull);
  });

  group('the system settings that defeat a direction', () {
    testWidgets('mono audio is named, with the way to the setting',
        (tester) async {
      answers['getAudioAccessibility'] = {'mono': true};

      await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
      await tester.pump();

      expect(find.textContaining('Mono-Audio'), findsOneWidget);

      final button = find.text('Bedienungshilfen öffnen');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(methods().last, 'openAccessibilitySettings');
    });

    testWidgets('a shifted balance is named as well', (tester) async {
      answers['getAudioAccessibility'] = {'mono': false, 'balance': -0.8};

      await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
      await tester.pump();

      expect(find.textContaining('Audio-Balance'), findsOneWidget);
    });

    testWidgets('nothing is claimed when the settings cannot be read',
        (tester) async {
      // The native side answers nothing: unknown, not "everything fine".
      await _pumpScreen(tester, headphones: Stream.value(const [_pods]));
      await tester.pump();

      expect(find.textContaining('Mono-Audio'), findsNothing);
      expect(find.text('Bedienungshilfen öffnen'), findsNothing);
    });
  });
}
