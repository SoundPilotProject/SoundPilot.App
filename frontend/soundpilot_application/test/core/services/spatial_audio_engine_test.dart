// test/core/services/spatial_audio_engine_test.dart
//
// SpatialAudioEngine against a mocked native channel: which gains reach the
// player for a direction, and that a new direction glides instead of starting
// the recording over.

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/services/spatial_audio_engine.dart';
import 'package:soundpilot_application/features/device/volume_scale.dart';
import 'package:soundpilot_application/features/exercise/spatial_audio.dart';

const String _asset = 'assets/audio/Marschieren.mp3';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.soundpilot/audio_devices');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  /// The calibration of the two ears used throughout: a quiet left, a loud
  /// right, so a mixed-up side shows up.
  final calibration =
      EarCalibration.fromWheel(leftVolume: 30, rightVolume: 90);

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  /// The gain the call at [index] sent for one side.
  double gain(int index, String side) =>
      (calls[index].arguments as Map)['${side}Gain'] as double;

  group('play', () {
    test('a centred sound is played with the calibrated gains', () async {
      await SpatialAudioEngine().play(
        asset: _asset,
        calibration: calibration,
        outputDeviceId: 7,
      );

      expect(calls.single.method, 'playTestSound');
      expect(calls.single.arguments, {
        'asset': _asset,
        'leftGain': wheelToGain(30),
        'rightGain': wheelToGain(90),
        'deviceId': 7,
      });
    });

    test('full left reaches the left ear only', () async {
      await SpatialAudioEngine().play(
        asset: _asset,
        calibration: calibration,
        angle: angleFullLeft,
      );

      expect(gain(0, 'left'), wheelToGain(30));
      expect(gain(0, 'right'), 0);
      // No device: the native side plays on the default output.
      expect((calls.single.arguments as Map)['deviceId'], isNull);
    });

    test('a failed start leaves the engine stopped', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'DEVICE_NOT_CONNECTED');
      });
      final engine = SpatialAudioEngine();

      await expectLater(
        engine.play(asset: _asset, calibration: calibration),
        throwsA(isA<PlatformException>()),
      );
      expect(engine.isPlaying, isFalse);
    });
  });

  group('setAngle', () {
    test('glides to the new gains instead of starting over', () async {
      final engine = SpatialAudioEngine();
      await engine.play(
        asset: _asset,
        calibration: calibration,
        angle: angleFullLeft,
      );

      await engine.setAngle(angleHalfLeft);

      expect(calls.map((call) => call.method),
          ['playTestSound', 'setPlaybackGain']);
      expect(gain(1, 'left'), wheelToGain(30));
      expect(gain(1, 'right'),
          closeTo(math.tan(math.pi / 8) * wheelToGain(90), 1e-12));
      expect(engine.angle, angleHalfLeft);
    });

    test('a direction while nothing plays is only remembered', () async {
      final engine = SpatialAudioEngine();

      await engine.setAngle(angleFullRight);

      expect(calls, isEmpty);
      expect(engine.angle, angleFullRight);

      // The next start begins there.
      await engine.play(asset: _asset, calibration: calibration);
      expect(gain(0, 'left'), wheelToGain(30));
    });

    test('the angle survives a stop, so the next start keeps it', () async {
      final engine = SpatialAudioEngine();
      await engine.play(
        asset: _asset,
        calibration: calibration,
        angle: angleHalfRight,
      );
      await engine.stop();

      expect(engine.angle, angleHalfRight);
    });
  });

  test('a changed calibration glides as well', () async {
    final engine = SpatialAudioEngine();
    await engine.play(asset: _asset, calibration: EarCalibration.neutral);

    await engine.setCalibration(calibration);

    expect(calls.last.method, 'setPlaybackGain');
    expect(gain(1, 'left'), wheelToGain(30));
    expect(gain(1, 'right'), wheelToGain(90));
  });

  group('stop', () {
    test('stops the native side once', () async {
      final engine = SpatialAudioEngine();
      await engine.play(asset: _asset, calibration: calibration);

      await engine.stop();
      await engine.stop();

      expect(calls.map((call) => call.method), ['playTestSound', 'stopPlayback']);
      expect(engine.isPlaying, isFalse);
    });

    test('does nothing while nothing plays', () async {
      await SpatialAudioEngine().stop();

      expect(calls, isEmpty);
    });

    test('markStopped leaves the native side alone', () async {
      // The earbud disconnected: the native side has stopped by itself.
      final engine = SpatialAudioEngine();
      await engine.play(asset: _asset, calibration: calibration);

      engine.markStopped();
      await engine.setAngle(angleFullRight);

      expect(engine.isPlaying, isFalse);
      expect(calls.map((call) => call.method), ['playTestSound']);
    });
  });

  test('gains report what the two ears get right now', () async {
    final engine = SpatialAudioEngine();
    await engine.play(
      asset: _asset,
      calibration: calibration,
      angle: angleFullRight,
    );

    expect(engine.gains.left, 0);
    expect(engine.gains.right, wheelToGain(90));
  });
}
