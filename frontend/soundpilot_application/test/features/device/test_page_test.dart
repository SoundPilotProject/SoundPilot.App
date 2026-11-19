// test/features/device/test_page_test.dart
//
// The test exercise (the marching exercise at the chair): that it plays its
// recording once with the calibrated gains and the whole cue list — on the
// calibrated earbud while that is connected, on the phone itself otherwise —
// follows the cues on screen without touching a gain, ends on the native event
// (and on its own timer if that never comes), which of its buttons can be used
// in each state, and that it says when a system setting makes the direction
// inaudible.
//
// NOTE: Two lines carry the state. The first one says whether the exercise
// runs and is announced by a screen reader; the second one says where the
// sound is and is not (see _details in the page).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/core/services/audio_device_service.dart';
import 'package:soundpilot_application/features/device/screens/test_page.dart';
import 'package:soundpilot_application/features/device/volume_scale.dart';
import 'package:soundpilot_application/features/exercise/marching_exercise.dart';
import 'package:soundpilot_application/features/exercise/spatial_audio.dart';

const _pods = HeadphoneDevice(
  name: 'Pods',
  address: 'aa',
  isConnected: true,
  outputDeviceId: 7,
);

/// Gain of the quieter ear at ±45°: the equal-power ratio over the
/// calibration.
double _quiet(int volume) => math.tan(math.pi / 8) * wheelToGain(volume);

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
      // Asked for when the page opens and of no interest to most tests.
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

  /// Stops the exercise.
  Future<void> stop(WidgetTester tester) async {
    await tester.tap(find.text('Stop'));
    await tester.pump();
  }

  // ── Playback ───────────────────────────────────────────────────────────────

  testWidgets('plays the recording once, centred, with its whole cue list',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));

    await start(tester);

    expect(calls.single.method, 'playTestSound');
    final arguments = calls.single.arguments as Map;
    expect(arguments['asset'], marchingAsset);
    expect(arguments['leftGain'], wheelToGain(30));
    expect(arguments['rightGain'], wheelToGain(90));
    expect(arguments['deviceId'], 7);
    // Once: the recording ends with a closing sentence.
    expect(arguments['loop'], isFalse);
    expect(find.text('Übung läuft über die Kopfhörer'), findsOneWidget);
    expect(find.text('Ton mittig'), findsOneWidget);

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

    // 'Start' keeps its colour and starts over; 'Stop' is only alive while
    // something plays.
    expect(_controls(tester), ['Start', 'Stop']);
    expect(_controls(tester, onlyUsable: true), ['Start', 'Stop']);

    await stop(tester);
    expect(methods().last, 'stopPlayback');
    expect(_controls(tester, onlyUsable: true), ['Start']);
  });

  testWidgets('the status line follows the cues without touching a gain',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);
    calls.clear();

    // 21.4 s: "Verlagern Sie Ihr Gewicht … auf Ihr linkes Bein".
    await advance(tester, marchingCues.first.at);
    expect(find.text('Ton links – das linke Bein'), findsOneWidget);

    // 28.6 s: the recording moves on and so does the sound.
    await advance(tester, marchingCues[1].at - marchingCues[0].at);
    expect(find.text('Ton mittig'), findsOneWidget);

    // The sound itself is the native player's business: nothing is sent.
    expect(calls, isEmpty);

    await stop(tester);
  });

  testWidgets('every cue reaches the status line', (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    var elapsed = Duration.zero;
    for (final cue in marchingCues) {
      await advance(tester, cue.at - elapsed);
      elapsed = cue.at;

      expect(find.text('Ton ${cue.label}'), findsOneWidget, reason: '$cue');
      // The line that is announced does not move with the cues.
      expect(find.text('Übung läuft über die Kopfhörer'), findsOneWidget);
    }

    await stop(tester);
  });

  // ── The end ────────────────────────────────────────────────────────────────

  testWidgets('the native end event ends the exercise', (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
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

    // 'beendet', not 'gestoppt': the recording ran to its end, and that is
    // what a screen reader is told.
    expect(find.text('Übung beendet'), findsOneWidget);
    // It stopped by itself; nothing has to be stopped here.
    expect(methods(), isNot(contains('stopPlayback')));
  });

  testWidgets('ends on its own timer if the event never comes',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await advance(tester, marchingDuration);
    // Still running: the closing sentence may well still be on its way
    // through Bluetooth at this point.
    expect(find.textContaining('Übung läuft'), findsOneWidget);

    await advance(tester, TestPage.endMargin);

    expect(find.text('Übung beendet'), findsOneWidget);
    expect(methods(), isNot(contains('stopPlayback')));
  });

  testWidgets('the end is taken once, whichever of the two arrives first',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await tester.runAsync(() async {
      endEvents!.success('ended');
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(find.text('Übung beendet'), findsOneWidget);

    // The fallback timer comes later and finds nothing to end.
    await advance(tester, marchingDuration + TestPage.endMargin);
    expect(find.text('Übung beendet'), findsOneWidget);
    expect(methods(), isNot(contains('stopPlayback')));
  });

  testWidgets('an end that arrives after Stop changes nothing', (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);
    await stop(tester);

    await tester.runAsync(() async {
      endEvents!.success('ended');
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    // Stopped by the user stays stopped, not 'beendet'.
    expect(find.text('Übung gestoppt'), findsOneWidget);
  });

  testWidgets('Stop ends the exercise and its cues', (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await stop(tester);
    expect(methods().last, 'stopPlayback');

    // No cue and no end timer are left behind.
    await advance(tester, marchingDuration * 2);
    expect(find.text('Übung gestoppt'), findsOneWidget);
  });

  testWidgets('Start begins the exercise again from its beginning',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);
    await advance(tester, marchingCues.first.at);
    calls.clear();

    await start(tester);

    expect(calls.single.method, 'playTestSound');
    expect(find.text('Ton mittig'), findsOneWidget);

    // The first cue comes again, so the old schedule is gone.
    await advance(tester, marchingCues.first.at);
    expect(find.textContaining('Ton links'), findsOneWidget);

    await stop(tester);
  });

  // ── Without an earbud ──────────────────────────────────────────────────────

  testWidgets('without an earbud it plays on the phone itself',
      (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const []));

    // 'Start' works here too, otherwise the exercise could not be tried at
    // all before pairing anything.
    await start(tester);

    expect(calls.single.method, 'playTestSound');
    // No device: the native side plays on the default output.
    expect((calls.single.arguments as Map)['deviceId'], isNull);
    expect(find.textContaining('über den Lautsprecher'), findsWidgets);
    expect(_controls(tester, onlyUsable: true),
        ['Start', 'Stop', 'Bluetooth-Einstellungen öffnen']);

    await stop(tester);
  });

  testWidgets('sound on the phone survives a headphone change',
      (tester) async {
    final headphones = StreamController<List<HeadphoneDevice>>(sync: true);
    addTearDown(headphones.close);
    await _pumpPage(tester, headphones: headphones.stream);
    headphones.add(const []);
    await tester.pump();
    await start(tester);

    // Another device comes and goes; only a playback on the earbud is
    // stopped by that, this one is not.
    headphones.add(const []);
    await tester.pump();

    expect(find.text('Übung läuft über den Lautsprecher'), findsOneWidget);

    await stop(tester);
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

  testWidgets('says that the exercise is only in the Android app',
      (tester) async {
    await _pumpPage(tester,
        headphones: Stream.value(const []), soundSupported: false);

    expect(find.text('Die Übung gibt es nur in der Android-App.'),
        findsOneWidget);
    // The buttons are shown, but there is no sound at all here, and no
    // Bluetooth settings to send anyone to.
    expect(_controls(tester), ['Start', 'Stop']);
    expect(_controls(tester, onlyUsable: true), isEmpty);
  });

  // ── Stopping from outside ──────────────────────────────────────────────────

  testWidgets('a disconnecting earbud ends the exercise', (tester) async {
    final headphones = StreamController<List<HeadphoneDevice>>(sync: true);
    addTearDown(headphones.close);
    await _pumpPage(tester, headphones: headphones.stream);
    headphones.add(const [_pods]);
    await tester.pump();
    await start(tester);

    headphones.add(const []);
    await tester.pump();

    // The native side stops the sound itself; the page follows.
    expect(find.text('Übung gestoppt'), findsOneWidget);
    expect(_controls(tester, onlyUsable: true),
        ['Start', 'Bluetooth-Einstellungen öffnen']);
    // No cue moves the status line on after that.
    await advance(tester, marchingDuration);
    expect(find.text('Übung gestoppt'), findsOneWidget);
  });

  testWidgets('stops when the app goes to the background', (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(methods().last, 'stopPlayback');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('stops when the page is left', (tester) async {
    await _pumpPage(tester, headphones: Stream.value(const [_pods]));
    await start(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(methods().last, 'stopPlayback');
  });

  // ── The system settings ────────────────────────────────────────────────────

  group('the system settings that defeat a direction', () {
    testWidgets('mono audio is named, with the way to the setting',
        (tester) async {
      answers['getAudioAccessibility'] = {'mono': true};

      await _pumpPage(tester, headphones: Stream.value(const [_pods]));
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

      await _pumpPage(tester, headphones: Stream.value(const [_pods]));
      await tester.pump();

      expect(find.textContaining('Audio-Balance'), findsOneWidget);
    });

    testWidgets('nothing is claimed when the settings cannot be read',
        (tester) async {
      // The native side answers nothing: unknown, not "everything fine".
      await _pumpPage(tester, headphones: Stream.value(const [_pods]));
      await tester.pump();

      expect(find.textContaining('Mono-Audio'), findsNothing);
      expect(find.text('Bedienungshilfen öffnen'), findsNothing);
    });

    testWidgets('once started, the hint comes whatever is known',
        (tester) async {
      await _pumpPage(tester, headphones: Stream.value(const [_pods]));

      expect(
          find.textContaining('prüfe in den Bedienungshilfen'), findsNothing);

      await start(tester);

      // Nothing could be read here, so this hint is the only thing that can
      // explain a sound that never moves to a side.
      expect(find.textContaining('prüfe in den Bedienungshilfen'),
          findsOneWidget);

      await stop(tester);
    });
  });
}
