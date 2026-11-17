// lib/core/services/haptic_engine.dart
//
// Vibration output: a reference pulse at a given strength, and the belt's
// motors for one direction.

import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../features/exercise/belt_direction.dart';

/// Plays vibration, the second channel the exercises need besides sound (see
/// `docs/PROJECT_CONTEXT.md` §1).
///
/// NOTE: There is no belt to vibrate yet (§7): nothing in the app connects to
/// one, so a pulse goes to the *phone's* own motor. That is enough to try a
/// strength and to give an exercise its haptic channel. [beltDirection]
/// computes the per-motor intensities anyway and returns them, so the belt
/// only has to be handed a list once it exists.
class HapticEngine {
  const HapticEngine._();

  /// One reference pulse at [intensity] (0.0–1.0, the strength from the belt
  /// setup). Does nothing at 0.
  ///
  /// NOTE: Flutter offers three fixed strengths and no amplitude, so the
  /// intensity picks the nearest of them. Android's own amplitude control
  /// (`VibrationEffect`) would need a method channel of its own; the belt's
  /// motors are the ones that matter, and those are not reached from here at
  /// all.
  static Future<void> pulse({required double intensity}) async {
    final level = intensity.clamp(0.0, 1.0).toDouble();
    if (level == 0) return;
    if (level < 1 / 3) return HapticFeedback.lightImpact();
    if (level < 2 / 3) return HapticFeedback.mediumImpact();
    return HapticFeedback.heavyImpact();
  }

  /// The belt's motors for the direction [angle] at [intensity], as
  /// [BeltSectors.forDirection] computes them.
  ///
  /// Pulses the phone with the strongest of them, so the direction test can be
  /// tried without a belt, and returns the whole list for whoever shows it or
  /// later sends it to the hardware.
  static Future<List<double>> beltDirection({
    required double angle,
    required double intensity,
    BeltSectors sectors = const BeltSectors(),
  }) async {
    final motors = sectors.forDirection(angle, intensity: intensity);
    await pulse(intensity: motors.reduce(math.max));
    return motors;
  }
}
