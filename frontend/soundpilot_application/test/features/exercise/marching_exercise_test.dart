// test/features/exercise/marching_exercise_test.dart
//
// The cue list of the marching exercise: that it matches the transcription of
// the recording, and that it keeps the rules the exercise is built on.

import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/features/exercise/marching_exercise.dart';
import 'package:soundpilot_application/features/exercise/spatial_audio.dart';

/// Where 'Der Rhythmus' begins in the recording. Nothing is panned from here
/// on: that part says "ein Bein" and "das andere" and names no side.
const Duration _rhythmStart = Duration(milliseconds: 77100);

void main() {
  group('marchingCues', () {
    test('are the blocks of the transcription', () {
      // Pinned on purpose: these times come from a transcription of the
      // recording, not from the code, and a careless edit has to fail here.
      expect(
        marchingCues
            .map((cue) => [cue.at.inMilliseconds, cue.angle])
            .toList(),
        [
          [21400, angleHalfLeft],
          [28600, angleCentre],
          [33500, angleHalfRight],
          [36800, angleCentre],
          [65800, angleHalfRight],
          [71400, angleCentre],
          [71800, angleHalfLeft],
          [73800, angleCentre],
        ],
      );
    });

    test('are in order and end before the recording does', () {
      var previous = Duration.zero;
      for (final cue in marchingCues) {
        expect(cue.at, greaterThan(previous), reason: '$cue');
        expect(cue.at, lessThan(marchingDuration), reason: '$cue');
        previous = cue.at;
      }
    });

    test('never put the sound fully on one ear', () {
      // ±90° would leave a weak ear with nothing, and with it the
      // instruction; ±45° is a side that both ears still hear.
      for (final cue in marchingCues) {
        expect(cue.angle.abs(), lessThanOrEqualTo(45), reason: '$cue');
      }
    });

    test('each side is given up again', () {
      for (var i = 0; i < marchingCues.length; i++) {
        if (marchingCues[i].angle == angleCentre) continue;

        expect(i + 1, lessThan(marchingCues.length),
            reason: '${marchingCues[i]} is never ended');
        expect(marchingCues[i + 1].angle, angleCentre,
            reason: 'after ${marchingCues[i]}');
      }
      expect(marchingCues.last.angle, angleCentre);
    });

    test('the sides follow the recording: left, right, right, left', () {
      final sides = marchingCues
          .where((cue) => cue.angle != angleCentre)
          .map((cue) => cue.angle)
          .toList();

      expect(sides,
          [angleHalfLeft, angleHalfRight, angleHalfRight, angleHalfLeft]);
    });

    test('every cue says in words where the sound is', () {
      for (final cue in marchingCues) {
        if (cue.angle == angleCentre) {
          expect(cue.label, cueCentreLabel, reason: '$cue');
        } else if (cue.angle < angleCentre) {
          expect(cue.label, startsWith('links'), reason: '$cue');
        } else {
          expect(cue.label, startsWith('rechts'), reason: '$cue');
        }
      }
    });

    test('the Rhythmus part stays centred', () {
      // Panning it would make the app give an instruction that the recording
      // does not give (see the NOTE on marchingCues).
      for (final cue in marchingCues) {
        if (cue.at >= _rhythmStart) {
          expect(cue.angle, angleCentre, reason: '$cue');
        }
      }
      expect(marchingCues.last.at, lessThan(_rhythmStart));
    });

    test('the change from right to left glides through the centre', () {
      // The two cues are closer together than the ramp is long, so the glide
      // to the centre is interrupted by the glide to the left and the sound
      // travels across instead of jumping.
      final centre = marchingCues[5];
      final left = marchingCues[6];

      expect(centre.angle, angleCentre);
      expect(left.angle, angleHalfLeft);
      expect(left.at - centre.at, lessThan(panRamp));
    });
  });

  group('the recording', () {
    test('is the mono asset the engine pans at runtime', () {
      expect(marchingAsset, 'assets/audio/Marschieren.mp3');
    });

    test('is as long as the file was measured to be', () {
      // 3523 MPEG frames of 1152 samples at 44.1 kHz.
      expect(marchingDuration.inMilliseconds,
          closeTo(3523 * 1152 / 44.1, 1));
    });
  });
}
