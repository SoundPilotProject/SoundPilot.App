// lib/features/exercise/screens/marching_exercise_screen.dart
//
// The guided marching exercise: plays its recording once and moves the sound
// to the side the recording is talking about.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_logger.dart';
import '../../../core/services/audio_device_service.dart';
import '../../../core/services/spatial_audio_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/playback_button.dart';
import '../../device/headphone_connection.dart';
import '../direction_hint.dart';
import '../marching_exercise.dart';
import '../spatial_audio.dart';

/// The marching exercise at the chair (see `docs/PROJECT_CONTEXT.md` §4):
/// plays [marchingAsset] once, each ear with its calibrated volume, and moves
/// the sound to the side the recording names ([marchingCues]).
///
/// One exercise, one screen, one pair of controls — 'Start' and 'Stop', like
/// the test exercise. It plays on the calibrated earbud while that is
/// connected and on the phone's own output otherwise, where left and right are
/// of course no longer two ears.
///
/// NOTE: The recording is played **once** (`loop: false`): it ends with a
/// closing sentence, and starting over would talk through it. The native side
/// reports that end once it has really been heard
/// ([AudioDeviceService.playbackEnded]); the timer of [endMargin] is only the
/// fallback for where that event cannot arrive.
///
/// NOTE: The directions are handed to the native player as a cue list, which
/// applies them itself at their point in the samples — that is what keeps the
/// panning and the words together whatever the Bluetooth latency is. The
/// timers here only move the status line and are allowed to be a little early.
class MarchingExerciseScreen extends StatefulWidget {
  /// Calibrated volume of the left side (1–100).
  final int leftVolume;

  /// Calibrated volume of the right side (1–100).
  final int rightVolume;

  /// Map key of the earbud (its BD_ADDR), to play on it.
  final String address;

  /// The connected headphones, again on every change; tests pass a fake.
  final Stream<List<HeadphoneDevice>> Function() headphoneChanges;

  /// Whether the sound can play here (only the Android app can). Defaults to
  /// [AudioDeviceService.isSupported].
  final bool? soundSupported;

  /// How long after the end of the recording the screen stops waiting for the
  /// native end event and says it is over by itself.
  ///
  /// NOTE: Generous on purpose. Saying 'läuft' a second too long costs
  /// nothing; claiming 'gestoppt' while the closing sentence is still playing
  /// is what must not happen. A short margin would do exactly that, because
  /// the sound is still in the buffer (80–180 ms) and on its way through
  /// Bluetooth (another 150–300 ms) when the last sample has been written.
  static const Duration endMargin = Duration(seconds: 2);

  const MarchingExerciseScreen({
    super.key,
    required this.leftVolume,
    required this.rightVolume,
    required this.address,
    this.headphoneChanges = AudioDeviceService.headphoneChanges,
    this.soundSupported,
  });

  @override
  State<MarchingExerciseScreen> createState() =>
      _MarchingExerciseScreenState();
}

class _MarchingExerciseScreenState extends State<MarchingExerciseScreen>
    with WidgetsBindingObserver {
  late final bool _soundSupported =
      widget.soundSupported ?? AudioDeviceService.isSupported;

  /// Plays the recording from a direction; the only thing on this screen that
  /// reaches the native player.
  final SpatialAudioEngine _engine = SpatialAudioEngine();

  /// Whether the earbud is connected; null without sound support.
  HeadphoneConnection? _connection;

  bool _isPlaying = false;

  /// Whether the running playback was sent to the earbud. Only that one is
  /// stopped by the native side when the earbud disconnects.
  bool _playingOnEarbud = false;

  /// Whether the recording ran to its end, as opposed to being stopped.
  bool _finished = false;

  /// Index of the cue that applies, or null while the recording is still
  /// before the first one (and therefore centred).
  int? _cueIndex;

  /// One timer per cue, for the status line only (see the class doc).
  final List<Timer> _cueTimers = [];

  /// The native side reporting that the recording has been heard to its end.
  StreamSubscription<void>? _endEvents;

  /// Android's mono audio and balance settings, as far as they can be read.
  AudioAccessibility _audioSettings = AudioAccessibility.unknown;

  /// Puts the screen back to stopped once the recording has run out.
  Timer? _endTimer;

  /// Shown if the recording could not be started.
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_soundSupported) {
      unawaited(_loadAudioSettings());
      _endEvents = AudioDeviceService.playbackEnded().listen(
        (_) {
          if (_isPlaying) _handleEnd();
        },
        // Without a native side the channel cannot open; the timer carries it.
        onError: (Object _) {},
      );
      _connection = HeadphoneConnection(
        address: widget.address,
        changes: widget.headphoneChanges,
        onChanged: () => setState(() {
          // The native side stops the sound itself when the earbud goes; the
          // exercise ends with it, cues and all.
          if (_playingOnEarbud && _connection?.connected == null) {
            _engine.markStopped();
            _cancelTimers();
            _isPlaying = false;
            _playingOnEarbud = false;
            _cueIndex = null;
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    unawaited(_endEvents?.cancel());
    _connection?.dispose();
    if (_isPlaying) unawaited(_stopQuietly());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // NOTE: No exercise in the background: nobody is standing at the chair,
    // and the sound could not be stopped from there.
    if (state != AppLifecycleState.resumed && _isPlaying) _stop();
  }

  /// Reads the accessibility audio settings once, so the screen can say that
  /// they are in the way before the user tries to hear a direction.
  Future<void> _loadAudioSettings() async {
    final settings = await AudioDeviceService.audioAccessibility();
    if (mounted) setState(() => _audioSettings = settings);
  }

  /// A system setting that is known to make left and right inaudible.
  String? get _blocked => directionBlockedMessage(_audioSettings);

  /// Whether 'Start' can be used: anywhere the app can play sound.
  bool get _canPlay => _soundSupported;

  /// True while the sound goes to the calibrated earbud.
  bool get _onEarbud => _connection?.connected != null;

  /// The user's calibration; the gains of every cue are scaled with it.
  EarCalibration get _calibration => EarCalibration.fromWheel(
        leftVolume: widget.leftVolume,
        rightVolume: widget.rightVolume,
      );

  /// Where the sound comes from right now, as the status line says it.
  String get _side {
    final index = _cueIndex;
    return index == null ? cueCentreLabel : marchingCues[index].label;
  }

  /// Angle the sound is at right now, for the indicator.
  double get _angle {
    final index = _cueIndex;
    return index == null ? angleCentre : marchingCues[index].angle;
  }

  /// Starts the recording from its beginning, centred, and the cue schedule
  /// with it.
  ///
  /// NOTE: Pressing 'Start' while it already plays starts the exercise over —
  /// the native side stops the running player before it opens the new one
  /// anyway, and a guided exercise is followed from its beginning.
  Future<void> _start() async {
    if (!_canPlay) return;

    final onEarbud = _onEarbud;
    _cancelTimers();

    setState(() => _error = null);
    try {
      await _engine.play(
        asset: marchingAsset,
        calibration: _calibration,
        angle: angleCentre,
        loop: false,
        cues: marchingCues,
        // No device: the native side plays on the default output.
        outputDeviceId: _connection?.connected?.outputDeviceId,
      );
      if (!mounted) {
        unawaited(_stopQuietly());
        return;
      }
      setState(() {
        _isPlaying = true;
        _playingOnEarbud = onEarbud;
        _finished = false;
        _cueIndex = null;
      });
      _scheduleCues();
      _endTimer = Timer(
          marchingDuration + MarchingExerciseScreen.endMargin, _handleEnd);
    } on PlatformException catch (e) {
      logger.e('MarchingExerciseScreen: Playback failed', error: e);
      if (!mounted) return;
      setState(() {
        _error = e.code == 'DEVICE_NOT_CONNECTED'
            ? 'Die Kopfhörer sind nicht mehr verbunden.'
            : 'Die Übung konnte nicht abgespielt werden. Bitte versuche es '
                'noch einmal.';
      });
    }
  }

  /// Schedules the status line for every cue of the recording.
  ///
  /// The sound itself is moved by the native player, which has the whole cue
  /// list (see [_start]); nothing here touches a gain.
  ///
  /// NOTE: All timers are created at once, each with its own offset from the
  /// start, instead of a chain where every cue schedules the next: a timer
  /// that fires late would otherwise push every later cue by the same amount,
  /// and over 74 seconds that adds up.
  void _scheduleCues() {
    for (var index = 0; index < marchingCues.length; index++) {
      final cue = marchingCues[index];
      _cueTimers.add(Timer(cue.at, () {
        setState(() => _cueIndex = index);
        _engine.markAngle(cue.angle);
      }));
    }
  }

  /// The recording has run out on its own.
  ///
  /// NOTE: The first of the native event and the fallback timer wins; the
  /// other one finds nothing playing and does nothing. The same guard covers
  /// an event that arrives after the user has stopped the exercise.
  void _handleEnd() {
    if (!_isPlaying) return;
    _cancelTimers();
    _engine.markStopped();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _playingOnEarbud = false;
      _finished = true;
      _cueIndex = null;
    });
  }

  /// Stops the exercise (no-op if nothing is playing).
  Future<void> _stop() async {
    if (!_isPlaying) return;
    _cancelTimers();
    setState(() {
      _isPlaying = false;
      _playingOnEarbud = false;
      _finished = false;
      _cueIndex = null;
    });
    await _stopQuietly();
  }

  /// Stops the sound without touching the state (also used in [dispose]).
  Future<void> _stopQuietly() async {
    try {
      await _engine.stop();
    } on PlatformException catch (e) {
      logger.e('MarchingExerciseScreen: Stopping the playback failed',
          error: e);
    }
  }

  void _cancelTimers() {
    for (final timer in _cueTimers) {
      timer.cancel();
    }
    _cueTimers.clear();
    _endTimer?.cancel();
    _endTimer = null;
  }

  /// What the user has to know before pressing 'Start', or the error; null if
  /// neither.
  String? get _note {
    if (_error != null) return _error;
    if (!_soundSupported) return 'Die Übung gibt es nur in der Android-App.';
    // Before the earbud: without this the user would look for the fault in
    // their ears.
    final blocked = _blocked;
    if (blocked != null) return blocked;
    if (_connection?.known == true && !_onEarbud) {
      return 'Deine Kopfhörer sind nicht verbunden. Die Übung läuft dann über '
          'den Lautsprecher – links und rechts hörst du nur über die Earbuds.';
    }
    return null;
  }

  /// Whether the exercise runs, in one sentence — the line a screen reader is
  /// told about.
  ///
  /// It changes when the exercise starts and when it is over, and at no point
  /// in between (see [_details]).
  String get _runState {
    if (_isPlaying) {
      final output = _onEarbud ? 'über die Kopfhörer' : 'über den Lautsprecher';
      return 'Übung läuft $output';
    }
    return _finished ? 'Übung beendet' : 'Übung gestoppt';
  }

  /// Where the sound is right now, or the calibrated volumes while nothing
  /// plays.
  ///
  /// NOTE: Deliberately **not** a live region, unlike [_runState]. A screen
  /// reader would read this out at every cue — through the same headphones the
  /// recording is playing on, from the middle, and with the recording turned
  /// down while it speaks (TalkBack's audio ducking). The announcement would
  /// cover the very instruction the direction is there to support. Whoever
  /// wants to know where the sound is puts the focus on this line.
  String get _details => _isPlaying
      ? 'Ton $_side'
      : 'links ${widget.leftVolume}, rechts ${widget.rightVolume}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Marschieren',
              onBackPressed: () async {
                // Captured before the await so no BuildContext is used across
                // the async gap.
                final navigator = Navigator.of(context);
                await _stop();
                if (!mounted) return;
                navigator.pop();
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SideIndicator(angle: _angle, isPlaying: _isPlaying),
                    const SizedBox(height: 14),
                    // The indicator is decorative; these two lines say the
                    // same in words, so the exercise also works without
                    // sight. Only the first one is announced.
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _runState,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _details,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_note != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _note!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PlaybackButton(
                      label: 'Start',
                      icon: Icons.play_arrow_rounded,
                      color: AppColors.primary(context),
                      textColor: AppColors.onPrimary(context),
                      onPressed: _canPlay ? _start : null,
                    ),
                    const SizedBox(height: 10),
                    PlaybackButton(
                      label: 'Stop',
                      icon: Icons.stop_rounded,
                      color: AppColors.stopRed,
                      textColor: Colors.white,
                      onPressed: _isPlaying ? _stop : null,
                    ),
                    if (_blocked != null) ...[
                      const SizedBox(height: 10),
                      PlaybackButton(
                        label: 'Bedienungshilfen öffnen',
                        icon: Icons.accessibility_new_rounded,
                        fontSize: 19,
                        color: AppColors.primary(context),
                        textColor: AppColors.onPrimary(context),
                        onPressed: AudioDeviceService.openAccessibilitySettings,
                      ),
                    ],
                    if (_soundSupported &&
                        _connection?.known == true &&
                        !_onEarbud) ...[
                      const SizedBox(height: 10),
                      PlaybackButton(
                        label: 'Bluetooth-Einstellungen öffnen',
                        icon: Icons.settings_rounded,
                        fontSize: 19,
                        color: AppColors.primary(context),
                        textColor: AppColors.onPrimary(context),
                        onPressed: AudioDeviceService.openBluetoothSettings,
                      ),
                    ],
                    const SizedBox(height: 22),
                    Semantics(
                      header: true,
                      child: Text(
                        'Beschreibung',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Die Aufnahme führt dich durch das Marschieren am '
                      'Stuhl. Wo sie von einer Seite spricht, wandert der Ton '
                      'auf diese Seite – so hörst du, welches Bein gemeint '
                      'ist. Sie läuft einmal durch und endet von selbst.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Side indicator ───────────────────────────────────────────────────────────

/// Three fields — left, centre, right — of which the one the sound is at is
/// filled.
///
/// Decorative: the status line below it says the same in words, so the
/// indicator is hidden from screen readers. It is not colour alone either —
/// the active field carries an icon the others do not have.
class _SideIndicator extends StatelessWidget {
  /// Where the sound is right now (see [StereoGains.forAngle]).
  final double angle;

  /// Grey while nothing plays: an indicator that always shows a side would
  /// claim the exercise is running.
  final bool isPlaying;

  const _SideIndicator({required this.angle, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    // −45, 0 and +45 are the only angles the cues use (see marchingCues).
    final active = angle < angleCentre ? 0 : (angle > angleCentre ? 2 : 1);

    return ExcludeSemantics(
      child: Row(
        children: [
          for (var field = 0; field < 3; field++) ...[
            if (field > 0) const SizedBox(width: 10),
            Expanded(
              child: _IndicatorField(
                icon: const [
                  Icons.volume_up_rounded,
                  Icons.headphones_rounded,
                  Icons.volume_up_rounded,
                ][field],
                filled: isPlaying && field == active,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IndicatorField extends StatelessWidget {
  final IconData icon;
  final bool filled;

  const _IndicatorField({required this.icon, required this.filled});

  @override
  Widget build(BuildContext context) {
    final color =
        filled ? AppColors.primary(context) : AppColors.surface(context);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: filled
              ? AppColors.primary(context)
              : AppColors.legendBorder(context),
          width: 2,
        ),
      ),
      child: filled
          ? Icon(icon, size: 30, color: AppColors.onPrimary(context))
          : null,
    );
  }
}
