// lib/features/exercise/marching_exercise.dart
//
// The marching exercise at the chair: its recording, and where the sound comes
// from while the recording speaks.

import 'package:flutter/foundation.dart';

import 'spatial_audio.dart';

/// The recording of the exercise (mono, see `docs/PROJECT_CONTEXT.md` §4).
const String marchingAsset = 'assets/audio/Marschieren.mp3';

/// How long the recording runs.
///
/// Measured from the file itself: 3523 MPEG frames of 1152 samples at
/// 44.1 kHz. The last word ends at 91.8 s, so a timer a little past the end
/// does not cut the closing sentence.
const Duration marchingDuration = Duration(milliseconds: 92030);

/// One step of an exercise: from when the sound comes from [angle].
///
/// A cue holds until the next one; there is no duration of its own, so two
/// cues close together simply glide through each other.
@immutable
class ExerciseCue {
  /// How far into the recording this cue applies.
  final Duration at;

  /// Where the sound comes from (see [StereoGains.forAngle]).
  final double angle;

  /// German name of the direction, for the status line and the screen reader.
  final String label;

  const ExerciseCue({
    required this.at,
    required this.angle,
    required this.label,
  });

  @override
  String toString() => 'ExerciseCue(${at.inMilliseconds}ms, $angle°)';
}

/// What the status line says while no cue has anything to add.
const String cueCentreLabel = 'mittig';

/// The directions of [marchingAsset], from a transcription of the recording.
///
/// **The sound goes to the side the recording names, and nowhere else.** The
/// times are the sentence blocks that speak about one side, so the direction
/// holds for as long as that side is the subject and returns to the centre
/// when the recording moves on:
///
/// | block | said |
/// |---|---|
/// | 21.4–28.6 s | "Gewicht … auf Ihr linkes Bein", "wie sich die linke Körperseite … anspannt" |
/// | 33.5–36.8 s | "heben Sie Ihren rechten Fuß … vom Boden ab" |
/// | 65.8–71.4 s | "Gewicht auf das rechte Bein", "wie sich die rechte Seite anspannt" |
/// | 71.8–73.8 s | "Dann heben Sie das linke Bein an" |
///
/// NOTE: ±45° and never ±90°. At ±90° one ear hears nothing, and whoever hears
/// badly on that side loses the instruction — which is the one thing this app
/// must not do (§1). ±45° is 7.7 dB between the ears: clearly a side, and both
/// ears still get the words.
///
/// NOTE: Every cue sits at the *start* of its sentence block, so the sound is
/// already on its side before the word 'links' or 'rechts' is said in the
/// middle of the sentence ([panRamp] long).
///
/// NOTE: The centre at 71.4 s and the left at 71.8 s are 0.4 s apart, less
/// than [panRamp]. That is on purpose: the glide to the centre is interrupted
/// by the glide to the left, and because the player starts a new ramp from the
/// gains it is currently at, the sound travels through the middle over the
/// pause between the two sentences instead of jumping.
///
/// NOTE: The part from 77.1 s ('Der Rhythmus') stays centred, although it is
/// where a direction would help most. It says "ein Bein" and "das andere" and
/// names no side — panning it would make the app, not the recording, give the
/// instruction, and a user who cannot place the sound would be left with an
/// instruction they never receive. A re-recorded version that says "rechtes
/// Bein" and "linkes Bein" is what that part needs (see §7).
const List<ExerciseCue> marchingCues = [
  ExerciseCue(
    at: Duration(milliseconds: 21400),
    angle: angleHalfLeft,
    label: 'links – das linke Bein',
  ),
  ExerciseCue(
    at: Duration(milliseconds: 28600),
    angle: angleCentre,
    label: cueCentreLabel,
  ),
  ExerciseCue(
    at: Duration(milliseconds: 33500),
    angle: angleHalfRight,
    label: 'rechts – der rechte Fuß',
  ),
  ExerciseCue(
    at: Duration(milliseconds: 36800),
    angle: angleCentre,
    label: cueCentreLabel,
  ),
  ExerciseCue(
    at: Duration(milliseconds: 65800),
    angle: angleHalfRight,
    label: 'rechts – das rechte Bein',
  ),
  ExerciseCue(
    at: Duration(milliseconds: 71400),
    angle: angleCentre,
    label: cueCentreLabel,
  ),
  ExerciseCue(
    at: Duration(milliseconds: 71800),
    angle: angleHalfLeft,
    label: 'links – das linke Bein',
  ),
  ExerciseCue(
    at: Duration(milliseconds: 73800),
    angle: angleCentre,
    label: cueCentreLabel,
  ),
];
