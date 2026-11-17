// lib/features/exercise/spatial_audio.dart
//
// Direction of an exercise sound as an angle, and the left/right gains that
// direction is played with: equal-power panning scaled by the calibration.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../device/volume_scale.dart';

/// Full left: only the left ear hears the sound.
const double angleFullLeft = -90;

/// Half left.
const double angleHalfLeft = -45;

/// Centred — in front of the user, both ears equally loud.
const double angleCentre = 0;

/// Half right.
const double angleHalfRight = 45;

/// Full right: only the right ear hears the sound.
const double angleFullRight = 90;

// ── Calibration ──────────────────────────────────────────────────────────────

/// The two calibrated ear volumes, as the gains they are played with.
///
/// The calibration is a *correction factor* for the user's own hearing, not a
/// direction: it is multiplied over the gains a direction asks for (see
/// [StereoGains.withCalibration]), so the direction survives and only the
/// level follows the ear.
@immutable
class EarCalibration {
  /// Gain of the left ear, 0.0–1.0.
  final double leftGain;

  /// Gain of the right ear, 0.0–1.0.
  final double rightGain;

  const EarCalibration({required this.leftGain, required this.rightGain});

  /// Both ears at full gain, for the cases where nothing is calibrated.
  static const EarCalibration neutral =
      EarCalibration(leftGain: 1, rightGain: 1);

  /// From the two wheel values of the calibration screen (1–100, converted
  /// with [wheelToGain]).
  factory EarCalibration.fromWheel({
    required int leftVolume,
    required int rightVolume,
  }) =>
      EarCalibration(
        leftGain: wheelToGain(leftVolume),
        rightGain: wheelToGain(rightVolume),
      );

  @override
  bool operator ==(Object other) =>
      other is EarCalibration &&
      other.leftGain == leftGain &&
      other.rightGain == rightGain;

  @override
  int get hashCode => Object.hash(leftGain, rightGain);

  @override
  String toString() => 'EarCalibration(L $leftGain, R $rightGain)';
}

// ── Panning ──────────────────────────────────────────────────────────────────

/// The gain of the left and the right ear, each 0.0–1.0.
@immutable
class StereoGains {
  final double left;
  final double right;

  const StereoGains({required this.left, required this.right});

  /// The gains that place a *mono* sound at [angleDegrees]
  /// ([angleFullLeft] … [angleCentre] … [angleFullRight]; anything outside is
  /// clamped).
  ///
  /// Equal-power panning: the ratio of the two ears is `tan` over the angle,
  /// which is what keeps a sound at one apparent loudness while it travels
  /// from one ear to the other. The louder ear always stays at 1.0, so the
  /// pair is only ever scaled down by the calibration.
  ///
  /// NOTE: Textbook equal-power puts *both* ears at cos 45° = 0.71 in the
  /// centre, i.e. 3 dB below the level the user calibrated — the centred
  /// exercise would be quieter than it was before this engine existed. The
  /// ratio between the ears is the direction cue, so normalising the pair to
  /// the louder ear keeps the cue exactly and leaves the level alone. It also
  /// never asks for a gain above 1.0, which the native side would clamp.
  ///
  /// NOTE: No real 3D audio (HRTF) on purpose: for "which side does this come
  /// from" a level difference is what the ear uses, and an HRTF would cost
  /// latency and a filter per angle for nothing.
  factory StereoGains.forAngle(double angleDegrees) {
    final angle = angleDegrees.clamp(angleFullLeft, angleFullRight).toDouble();

    // The centre is returned, not computed: cos and sin of 45° differ in the
    // last bit, and a centred sound has to come out at exactly the calibrated
    // gains.
    if (angle == angleCentre) return const StereoGains(left: 1, right: 1);

    // −90…+90 mapped to 0…π/2, so the left ear starts at cos 0 = 1 and the
    // right one at sin 0 = 0.
    final theta = (angle - angleFullLeft) / 180 * (math.pi / 2);

    return angle < angleCentre
        // Left of the centre the left ear is the louder one and stays at 1.
        ? StereoGains(left: 1, right: math.tan(theta))
        : StereoGains(left: math.tan((math.pi / 2) - theta), right: 1);
  }

  /// These gains with [calibration] multiplied over them — what is actually
  /// played (see `docs/PROJECT_CONTEXT.md` §4).
  StereoGains withCalibration(EarCalibration calibration) => StereoGains(
        left: (left * calibration.leftGain).clamp(0.0, 1.0).toDouble(),
        right: (right * calibration.rightGain).clamp(0.0, 1.0).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is StereoGains && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => 'StereoGains(L $left, R $right)';
}

// ── The direction exercise ───────────────────────────────────────────────────

/// One step of the direction exercise: the recording comes from [angle] and is
/// named [label] while it does.
@immutable
class DirectionStep {
  /// Direction of this step, in degrees (see [StereoGains.forAngle]).
  final double angle;

  /// German name of the direction, for the status line and the screen reader.
  final String label;

  const DirectionStep({required this.angle, required this.label});
}

/// How long one [DirectionStep] is played before the next one.
const Duration directionStepDuration = Duration(seconds: 4);

/// The directions of the earbud direction test, in order.
///
/// The same mono recording is moved across the five directions, so the user
/// can tell whether they hear *where* it comes from at all — which is what the
/// exercises later build on.
const List<DirectionStep> earbudDirectionSteps = [
  DirectionStep(angle: angleFullLeft, label: 'ganz links'),
  DirectionStep(angle: angleHalfLeft, label: 'halb links'),
  DirectionStep(angle: angleCentre, label: 'Mitte'),
  DirectionStep(angle: angleHalfRight, label: 'halb rechts'),
  DirectionStep(angle: angleFullRight, label: 'ganz rechts'),
];
