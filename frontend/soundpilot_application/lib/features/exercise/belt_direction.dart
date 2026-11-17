// lib/features/exercise/belt_direction.dart
//
// Direction on the belt: which of its vibration motors run how strongly, for
// one direction and for everything standing around the user.

import 'package:flutter/foundation.dart';

/// Something the belt warns about: a person or an obstacle, with the direction
/// it is in and how far away it is.
@immutable
class BeltObstacle {
  /// Direction in degrees, clockwise from straight ahead: 0 in front, 90 to
  /// the right, 180 behind, 270 to the left.
  final double angle;

  /// Distance in centimetres.
  final double distanceCm;

  const BeltObstacle({required this.angle, required this.distanceCm});

  @override
  String toString() => 'BeltObstacle($angle°, ${distanceCm}cm)';
}

/// The vibration motors of a belt, evenly spaced around the body.
///
/// This is the belt's half of the direction engine: it says which motors would
/// run and how strongly. Who sends that to the hardware is open — there is no
/// belt to send it to yet (see `docs/PROJECT_CONTEXT.md` §7), and the belt
/// screens use `HapticEngine` on the phone meanwhile.
@immutable
class BeltSectors {
  /// Number of motors. Motor 0 sits in front, the others follow clockwise.
  final int motorCount;

  const BeltSectors({this.motorCount = 8});

  /// The angle one motor covers.
  double get motorAngle => 360 / motorCount;

  /// Intensity per motor (0.0–1.0, one entry per motor) for a single
  /// direction [angle], scaled by [intensity] — the strength from the belt
  /// setup.
  ///
  /// A direction between two motors is shared by both of them, linearly:
  /// exactly in between, each runs at half. That is the "neighbouring motors"
  /// output the direction test is about.
  ///
  /// NOTE: Linear, not the equal-power law the audio side uses
  /// (`StereoGains` in `spatial_audio.dart`). That one exists because the two
  /// ears hear one sound together; two motors are two places on the skin, and
  /// the point here is which of them is the stronger one.
  List<double> forDirection(double angle, {double intensity = 1}) {
    final motors = List<double>.filled(motorCount, 0);
    final level = intensity.clamp(0.0, 1.0).toDouble();
    if (level == 0) return motors;

    // Position of the direction in motors, e.g. 1.5 = between motor 1 and 2.
    final position = ((angle % 360) + 360) % 360 / motorAngle;
    final lower = position.floor();
    final fraction = position - lower;

    // += and not =: with a single motor both indices are the same one.
    motors[lower % motorCount] += (1 - fraction) * level;
    motors[(lower + 1) % motorCount] += fraction * level;
    return motors;
  }

  /// Intensity per motor for everything around the user at once: one
  /// [BeltObstacle] per person or obstacle, each with its own direction and
  /// distance.
  ///
  /// The closer an obstacle, the stronger the motors in its direction
  /// ([closeness]); nothing beyond [warningDistanceCm] is felt at all.
  /// [intensity] is the strength from the belt setup and scales everything.
  ///
  /// NOTE: Per motor the *nearest* obstacle wins instead of the sum of all of
  /// them. Adding them up let two far ones feel like a single close one, which
  /// is the opposite of what the belt is for.
  ///
  /// NOTE: This aggregation sits above the direction engine, not inside it:
  /// what the sensors report is a list of (direction, distance) pairs, and the
  /// single-direction case ([forDirection]) is what the direction test uses.
  List<double> forObstacles(
    List<BeltObstacle> obstacles, {
    required double warningDistanceCm,
    double intensity = 1,
  }) {
    final motors = List<double>.filled(motorCount, 0);
    final level = intensity.clamp(0.0, 1.0).toDouble();
    if (level == 0) return motors;

    for (final obstacle in obstacles) {
      final near = closeness(obstacle.distanceCm, warningDistanceCm);
      if (near == 0) continue;

      final single = forDirection(obstacle.angle, intensity: near * level);
      for (var i = 0; i < motorCount; i++) {
        if (single[i] > motors[i]) motors[i] = single[i];
      }
    }
    return motors;
  }

  /// How close [distanceCm] is within [warningDistanceCm], as 0.0–1.0: 1 right
  /// at the user, 0 at the warning distance and beyond.
  ///
  /// NOTE: "the closer, the stronger" as a linear falloff, not as 1/distance.
  /// The reciprocal runs to infinity exactly where it matters most and would
  /// need a cap anyway, and it leaves nothing for the warning distance to mean.
  static double closeness(double distanceCm, double warningDistanceCm) {
    if (warningDistanceCm <= 0) return 0;
    return (1 - (distanceCm / warningDistanceCm)).clamp(0.0, 1.0).toDouble();
  }
}
