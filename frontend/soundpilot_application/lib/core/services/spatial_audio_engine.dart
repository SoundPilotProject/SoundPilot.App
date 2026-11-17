// lib/core/services/spatial_audio_engine.dart
//
// Plays an exercise sound from a direction: turns an angle plus the user's
// calibration into left/right gains and hands them to the native player.

import '../../features/exercise/spatial_audio.dart';
import 'audio_device_service.dart';

/// Plays one mono asset from a direction that may change while it runs.
///
/// An exercise says *what* is played and *from where* (an angle, see
/// [StereoGains.forAngle]); the engine keeps that angle together with the
/// user's [EarCalibration] and sends the resulting gains to
/// [AudioDeviceService]. A new angle glides to its gains instead of restarting
/// the sound ([AudioDeviceService.setPlaybackGain]), so a sound can travel
/// from one ear to the other without a gap.
///
/// NOTE: The assets are mono and stay mono (see `docs/PROJECT_CONTEXT.md` §4):
/// the whole left/right image is made here, at runtime. That is what lets one
/// recording serve every direction — a pre-panned stereo file could only ever
/// be played the one way it was mixed.
///
/// NOTE: The native side plays one sound at a time. A second engine that
/// starts playing therefore stops the first one's sound; the screens own one
/// engine each and only one of them is on screen.
class SpatialAudioEngine {
  double _angle = angleCentre;
  EarCalibration _calibration = EarCalibration.neutral;
  bool _playing = false;

  /// Direction the sound comes from, in degrees. Kept while nothing plays, so
  /// the next [play] starts where the last one left off unless it says
  /// otherwise.
  double get angle => _angle;

  /// The calibration the gains are scaled with.
  EarCalibration get calibration => _calibration;

  /// Whether a sound is running, as far as this engine knows. The native side
  /// stops by itself when the output device it was routed to disconnects; the
  /// owner says so with [markStopped].
  bool get isPlaying => _playing;

  /// The gains the two ears are played with right now.
  StereoGains get gains =>
      StereoGains.forAngle(_angle).withCalibration(_calibration);

  /// Starts [asset] from [angle] with [calibration], looping until [stop].
  ///
  /// With [outputDeviceId] ([HeadphoneDevice.outputDeviceId]) the sound only
  /// plays on that output — the calibrated earbud; without it the native side
  /// uses whatever the phone plays on by default. Throws a `PlatformException`
  /// like [AudioDeviceService.playTestSound], and the engine then stays
  /// stopped.
  ///
  /// [loop] false plays the recording once; the engine does not learn about
  /// that end by itself, so the caller marks it with [markStopped].
  ///
  /// [cues] are the directions of the recording. They are handed to the native
  /// player, which applies them itself at their point in the *samples* — the
  /// only way the panning and the words arrive at the ear together whatever
  /// the output latency is (see [AudioDeviceService.playTestSound]). A caller
  /// that follows them on screen says so with [markAngle]; it must not send
  /// them again with [setAngle].
  Future<void> play({
    required String asset,
    required EarCalibration calibration,
    double angle = angleCentre,
    int? outputDeviceId,
    bool loop = true,
    List<ExerciseCue> cues = const [],
  }) async {
    _angle = angle;
    _calibration = calibration;

    final target = gains;
    await AudioDeviceService.playTestSound(
      asset: asset,
      leftGain: target.left,
      rightGain: target.right,
      outputDeviceId: outputDeviceId,
      loop: loop,
      cues: [
        for (final cue in cues)
          PlaybackCue(
            at: cue.at,
            leftGain: StereoGains.forAngle(cue.angle)
                .withCalibration(calibration)
                .left,
            rightGain: StereoGains.forAngle(cue.angle)
                .withCalibration(calibration)
                .right,
            ramp: cue.ramp,
          ),
      ],
    );

    _playing = true;
  }

  /// Moves the running sound to [angle] over [ramp]. The gains glide, the
  /// sound does not restart; while nothing plays only the angle is remembered.
  ///
  /// A [ramp] of half a second or so is what a travelling sound wants; the
  /// default is the player's shortest glide, for a direction that should
  /// simply be there (see [AudioDeviceService.setPlaybackGain]).
  Future<void> setAngle(double angle, {Duration ramp = Duration.zero}) async {
    _angle = angle;
    if (_playing) await _applyGains(ramp);
  }

  /// Same for a changed calibration, e.g. while the user turns a wheel.
  Future<void> setCalibration(
    EarCalibration calibration, {
    Duration ramp = Duration.zero,
  }) async {
    _calibration = calibration;
    if (_playing) await _applyGains(ramp);
  }

  /// Stops the sound; does nothing to the native side if nothing is playing.
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    await AudioDeviceService.stopPlayback();
  }

  /// Notes that the sound has ended without this engine stopping it (the
  /// earbud it was routed to disconnected, and the native side stopped).
  void markStopped() => _playing = false;

  /// Notes that the sound is at [angle] without sending anything: a cue list
  /// handed to the native player moved it there (see [play]).
  void markAngle(double angle) => _angle = angle;

  Future<void> _applyGains(Duration ramp) async {
    final target = gains;
    await AudioDeviceService.setPlaybackGain(
      leftGain: target.left,
      rightGain: target.right,
      ramp: ramp,
    );
  }
}
