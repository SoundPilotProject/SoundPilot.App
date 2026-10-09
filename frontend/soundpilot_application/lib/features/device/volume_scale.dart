// lib/features/device/volume_scale.dart
//
// The calibration volume scale: stored value, wheel value and the gain that
// is actually played.

import 'dart:math' as math;

/// Converts a stored volume (0.0–1.0, see `HeadphoneCalib`) to the wheel
/// value 1–100.
int volumeToWheel(double volume) => (volume * 100).round().clamp(1, 100);

/// Converts a wheel value 1–100 to the stored volume (0.01–1.0).
double wheelToVolume(int value) => value / 100;

/// Quietest gain, at wheel value 1, in decibels.
const double minGainDb = -40;

/// Converts a wheel value 1–100 to the gain that is played (0.01–1.0).
///
/// NOTE: The ear hears loudness logarithmically, so the wheel runs evenly in
/// decibels, from [minGainDb] at 1 to 0 dB at 100: every step sounds about
/// equally large. A linear gain (value / 100) made the upper half of the
/// wheel sound almost the same.
double wheelToGain(int value) {
  final db = minGainDb * (100 - value.clamp(1, 100)) / 99;
  return math.pow(10, db / 20).toDouble();
}
