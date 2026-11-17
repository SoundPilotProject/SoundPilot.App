// test/features/exercise/spatial_audio_test.dart
//
// The pan law of the direction engine: what each ear gets at an angle, and how
// the calibration is multiplied over it.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/features/device/volume_scale.dart';
import 'package:soundpilot_application/features/exercise/spatial_audio.dart';

/// Difference between the two ears in decibels — the direction cue.
double _differenceDb(StereoGains gains) =>
    20 * math.log(gains.left / gains.right) / math.ln10;

void main() {
  group('StereoGains.forAngle', () {
    test('the centre is exactly both ears at full gain', () {
      // Exactly, not nearly: the centred exercise has to come out at the
      // calibrated gains and at nothing else.
      expect(
        StereoGains.forAngle(angleCentre),
        const StereoGains(left: 1, right: 1),
      );
    });

    test('full left and full right reach one ear only', () {
      expect(
        StereoGains.forAngle(angleFullLeft),
        const StereoGains(left: 1, right: 0),
      );
      expect(
        StereoGains.forAngle(angleFullRight),
        const StereoGains(left: 0, right: 1),
      );
    });

    test('half left keeps the equal-power ratio', () {
      final gains = StereoGains.forAngle(angleHalfLeft);

      expect(gains.left, 1);
      expect(gains.right, closeTo(math.tan(math.pi / 8), 1e-12));
      // 7.7 dB between the ears: a direction, not a wobble.
      expect(_differenceDb(gains), closeTo(7.66, 0.01));
    });

    test('is symmetric around the centre', () {
      for (final angle in [5.0, 20.0, 45.0, 75.0, 90.0]) {
        final left = StereoGains.forAngle(-angle);
        final right = StereoGains.forAngle(angle);

        expect(left.left, closeTo(right.right, 1e-12), reason: 'at $angle');
        expect(left.right, closeTo(right.left, 1e-12), reason: 'at $angle');
      }
    });

    test('the louder ear is at full gain at every angle', () {
      // This is what keeps the engine from making the exercise quieter than
      // the volume the user calibrated.
      for (var angle = angleFullLeft; angle <= angleFullRight; angle += 5) {
        final gains = StereoGains.forAngle(angle);

        expect(math.max(gains.left, gains.right), closeTo(1, 1e-12),
            reason: 'at $angle');
        expect(gains.left, inInclusiveRange(0, 1), reason: 'at $angle');
        expect(gains.right, inInclusiveRange(0, 1), reason: 'at $angle');
      }
    });

    test('the quieter ear only grows while the sound comes closer to it', () {
      var previous = -1.0;
      for (var angle = angleFullLeft; angle <= angleCentre; angle += 5) {
        final right = StereoGains.forAngle(angle).right;

        expect(right, greaterThan(previous), reason: 'at $angle');
        previous = right;
      }
    });

    test('angles beyond the two sides are clamped', () {
      expect(StereoGains.forAngle(-180), StereoGains.forAngle(angleFullLeft));
      expect(StereoGains.forAngle(270), StereoGains.forAngle(angleFullRight));
    });
  });

  group('withCalibration', () {
    test('multiplies the calibration over the direction', () {
      const gains = StereoGains(left: 1, right: 0.5);
      const calibration = EarCalibration(leftGain: 0.4, rightGain: 0.8);

      expect(
        gains.withCalibration(calibration),
        const StereoGains(left: 0.4, right: 0.4),
      );
    });

    test('a centred sound comes out at exactly the calibrated gains', () {
      final gains = StereoGains.forAngle(angleCentre).withCalibration(
        EarCalibration.fromWheel(leftVolume: 30, rightVolume: 90),
      );

      expect(gains.left, wheelToGain(30));
      expect(gains.right, wheelToGain(90));
    });

    test('keeps the direction while the calibration lowers one ear', () {
      // A quiet right ear must not turn into a direction of its own: the
      // difference the pan law asks for stays on top of it.
      final calibration =
          EarCalibration.fromWheel(leftVolume: 100, rightVolume: 50);
      final centred =
          StereoGains.forAngle(angleCentre).withCalibration(calibration);
      final halfLeft =
          StereoGains.forAngle(angleHalfLeft).withCalibration(calibration);

      expect(
        _differenceDb(halfLeft) - _differenceDb(centred),
        closeTo(7.66, 0.01),
      );
    });

    test('never asks for a gain the native side would clamp', () {
      for (var angle = angleFullLeft; angle <= angleFullRight; angle += 5) {
        final gains =
            StereoGains.forAngle(angle).withCalibration(EarCalibration.neutral);

        expect(gains.left, inInclusiveRange(0, 1), reason: 'at $angle');
        expect(gains.right, inInclusiveRange(0, 1), reason: 'at $angle');
      }
    });
  });

  group('EarCalibration', () {
    test('fromWheel converts both wheel values to gains', () {
      expect(
        EarCalibration.fromWheel(leftVolume: 1, rightVolume: 100),
        EarCalibration(leftGain: wheelToGain(1), rightGain: wheelToGain(100)),
      );
    });

    test('neutral changes nothing', () {
      const gains = StereoGains(left: 0.3, right: 0.7);

      expect(gains.withCalibration(EarCalibration.neutral), gains);
    });
  });

  group('earbudDirectionSteps', () {
    test('walk from the left ear to the right one', () {
      expect(earbudDirectionSteps.map((step) => step.angle).toList(), [
        angleFullLeft,
        angleHalfLeft,
        angleCentre,
        angleHalfRight,
        angleFullRight,
      ]);
    });

    test('are all named, because the status line reads them out', () {
      for (final step in earbudDirectionSteps) {
        expect(step.label, isNotEmpty);
      }
    });
  });
}
