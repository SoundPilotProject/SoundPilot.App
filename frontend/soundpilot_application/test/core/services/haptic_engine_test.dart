// test/core/services/haptic_engine_test.dart
//
// HapticEngine against the mocked platform channel: which of Flutter's three
// strengths an intensity picks, and the motors a belt direction would run.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/services/haptic_engine.dart';
import 'package:soundpilot_application/features/exercise/belt_direction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call);
      return null;
    });
  });

  tearDown(() {
    calls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// The strength of the pulse that was played, e.g. 'light'.
  String played() {
    final type = calls.single.arguments as String;
    return type.replaceFirst('HapticFeedbackType.', '').replaceFirst('Impact', '');
  }

  group('pulse', () {
    test('a low strength is a light pulse', () async {
      await HapticEngine.pulse(intensity: 0.2);

      expect(played(), 'light');
    });

    test('a middling strength is a medium pulse', () async {
      await HapticEngine.pulse(intensity: 0.5);

      expect(played(), 'medium');
    });

    test('a high strength is a heavy pulse', () async {
      await HapticEngine.pulse(intensity: 1);

      expect(played(), 'heavy');
    });

    test('nothing vibrates at 0', () async {
      await HapticEngine.pulse(intensity: 0);

      expect(calls, isEmpty);
    });

    test('an intensity outside 0–1 is clamped, not refused', () async {
      await HapticEngine.pulse(intensity: 4);
      expect(played(), 'heavy');

      calls.clear();
      await HapticEngine.pulse(intensity: -1);
      expect(calls, isEmpty);
    });
  });

  group('beltDirection', () {
    test('returns the motors of the direction and pulses the strongest',
        () async {
      final motors = await HapticEngine.beltDirection(angle: 90, intensity: 1);

      expect(motors, [0, 0, 1, 0, 0, 0, 0, 0]);
      expect(played(), 'heavy');
    });

    test('a direction between two motors shares the strength', () async {
      final motors =
          await HapticEngine.beltDirection(angle: 22.5, intensity: 1);

      expect(motors[0], closeTo(0.5, 1e-12));
      expect(motors[1], closeTo(0.5, 1e-12));
      // Half of full is the medium pulse on the phone.
      expect(played(), 'medium');
    });

    test('follows the belt it is given', () async {
      final motors = await HapticEngine.beltDirection(
        angle: 30,
        intensity: 1,
        sectors: const BeltSectors(motorCount: 12),
      );

      expect(motors.length, 12);
      expect(motors[1], 1);
    });

    test('nothing vibrates at intensity 0', () async {
      final motors = await HapticEngine.beltDirection(angle: 90, intensity: 0);

      expect(motors, everyElement(0));
      expect(calls, isEmpty);
    });
  });
}
