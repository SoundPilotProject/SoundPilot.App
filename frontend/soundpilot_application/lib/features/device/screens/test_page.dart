// lib/features/device/screens/test_page.dart
//
// Test exercise: plays a sound with the calibrated left/right volume.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_logger.dart';
import '../../../core/services/audio_device_service.dart';
import '../../../core/services/spatial_audio_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/playback_button.dart';
import '../../exercise/spatial_audio.dart';
import '../headphone_connection.dart';

/// Sound of the test exercise.
const String testSoundAsset = 'assets/audio/Marschieren.mp3';

/// Test exercise after the calibration: plays [testSoundAsset] in a loop
/// through a [SpatialAudioEngine], each side with its calibrated volume.
///
/// Two exercises live on this page (see `docs/PROJECT_CONTEXT.md` §4):
/// 'Start' plays the recording centred — the calibration and nothing else —
/// and 'Richtungstest' moves it through [earbudDirectionSteps], so the user
/// can say whether they hear *where* it comes from at all.
///
/// It plays on the calibrated earbud while that is connected, and on the
/// phone's own output otherwise — where the two sides are of course no
/// longer separate ears. It stops when the page is left, the app goes to the
/// background, or the earbud it was playing on disconnects.
///
/// NOTE: Unlike the test tone of the calibration, which exists to set one
/// ear's volume and therefore needs that earbud, this exercise is also worth
/// something without hardware: it is how the app is shown and tried.
///
/// Pops with `true` when the user taps 'Abschließen'; the back arrow pops
/// without a result.
class TestPage extends StatefulWidget {
  /// Calibrated volume of the left side (1–100).
  final int leftVolume;

  /// Calibrated volume of the right side (1–100).
  final int rightVolume;

  /// Map key of the earbud (its BD_ADDR), to play on it.
  final String address;

  /// The connected headphones, again on every change; tests pass a fake.
  /// Defaults to [AudioDeviceService.headphoneChanges].
  final Stream<List<HeadphoneDevice>> Function() headphoneChanges;

  /// Whether the sound can play here (only the Android app can). Defaults to
  /// [AudioDeviceService.isSupported].
  final bool? soundSupported;

  const TestPage({
    super.key,
    required this.leftVolume,
    required this.rightVolume,
    required this.address,
    this.headphoneChanges = AudioDeviceService.headphoneChanges,
    this.soundSupported,
  });

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with WidgetsBindingObserver {
  late final bool _soundSupported =
      widget.soundSupported ?? AudioDeviceService.isSupported;

  /// Plays the recording from a direction; the only thing on this page that
  /// reaches the native player.
  final SpatialAudioEngine _engine = SpatialAudioEngine();

  /// Whether the earbud is connected; null without sound support.
  HeadphoneConnection? _connection;

  /// True while the sound is playing.
  bool _isPlaying = false;

  /// Whether the running playback was sent to the earbud. Only that one is
  /// stopped by the native side when the earbud disconnects; sound on the
  /// phone's own output keeps going.
  bool _playingOnEarbud = false;

  /// Shown if the sound could not be started.
  String? _error;

  /// Index in [earbudDirectionSteps] of the direction that is playing; null
  /// while the centred exercise runs or nothing does.
  int? _directionStep;

  /// Moves the direction test to its next step.
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_soundSupported) {
      _connection = HeadphoneConnection(
        address: widget.address,
        changes: widget.headphoneChanges,
        onChanged: () => setState(() {
          // The native side stops the sound itself when the earbud goes; a
          // running direction test ends with it.
          if (_playingOnEarbud && _connection?.connected == null) {
            _engine.markStopped();
            _stepTimer?.cancel();
            _stepTimer = null;
            _isPlaying = false;
            _playingOnEarbud = false;
            _directionStep = null;
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepTimer?.cancel();
    _connection?.dispose();
    if (_isPlaying) unawaited(_stopQuietly());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // NOTE: No sound in the background, where the user cannot stop it.
    if (state != AppLifecycleState.resumed && _isPlaying) _stopAudio();
  }

  /// Whether 'Start' can be used: anywhere the app can play sound.
  ///
  /// NOTE: It used to need the connected earbud. Without one the exercise
  /// could not be tried at all, which is what everyone hits who opens it
  /// before pairing anything. It now falls back to the phone's own speaker
  /// ([_onEarbud] says which it is); the left/right calibration is only
  /// audible on the earbud, and [_note] says so.
  bool get _canPlay => _soundSupported;

  /// True while the sound goes to the calibrated earbud rather than to
  /// whatever the phone plays on by default.
  bool get _onEarbud => _connection?.connected != null;

  /// The user's calibration; the gains of every direction are scaled with it.
  EarCalibration get _calibration => EarCalibration.fromWheel(
        leftVolume: widget.leftVolume,
        rightVolume: widget.rightVolume,
      );

  /// Starts the centred exercise: the recording in both ears, each with its
  /// calibrated volume and no direction on top.
  Future<void> _startAudio() =>
      _start(angle: angleCentre, directionTest: false);

  /// Starts the direction test: the same recording, moved through
  /// [earbudDirectionSteps] one step at a time.
  Future<void> _startDirectionTest() =>
      _start(angle: earbudDirectionSteps.first.angle, directionTest: true);

  /// Starts the looping playback from [angle], on the earbud if it is
  /// connected and on the phone's default output otherwise.
  ///
  /// NOTE: Pressing a start button while something already plays starts the
  /// recording over rather than doing nothing — the native side stops the
  /// running player before it opens the new one anyway. That is also how the
  /// two exercises replace each other.
  Future<void> _start({
    required double angle,
    required bool directionTest,
  }) async {
    if (!_canPlay) return;

    final onEarbud = _onEarbud;
    _stepTimer?.cancel();
    _stepTimer = null;

    setState(() => _error = null);
    try {
      await _engine.play(
        asset: testSoundAsset,
        calibration: _calibration,
        angle: angle,
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
        _directionStep = directionTest ? 0 : null;
      });
      if (directionTest) _scheduleNextStep();
    } on PlatformException catch (e) {
      logger.e('TestPage: Playback failed', error: e);
      if (!mounted) return;
      setState(() {
        _error = e.code == 'DEVICE_NOT_CONNECTED'
            ? 'Die Kopfhörer sind nicht mehr verbunden.'
            : 'Die Aufnahme konnte nicht abgespielt werden. Bitte versuche es '
                'noch einmal.';
      });
    }
  }

  /// Lets the direction test wait [directionStepDuration] and then move on to
  /// its next direction; after the last one it stops.
  ///
  /// NOTE: Only the gains change ([SpatialAudioEngine.setAngle]), and they
  /// glide over [panRamp]: the recording keeps running, so the sound is heard
  /// travelling from one ear to the other instead of jumping there.
  void _scheduleNextStep() {
    _stepTimer = Timer(directionStepDuration, () {
      final next = (_directionStep ?? 0) + 1;
      if (next >= earbudDirectionSteps.length) {
        unawaited(_stopAudio());
        return;
      }

      setState(() => _directionStep = next);
      unawaited(
          _engine.setAngle(earbudDirectionSteps[next].angle, ramp: panRamp));
      _scheduleNextStep();
    });
  }

  /// Stops the playback and a running direction test (no-op if nothing is
  /// playing).
  Future<void> _stopAudio() async {
    if (!_isPlaying) return;
    _stepTimer?.cancel();
    _stepTimer = null;
    setState(() {
      _isPlaying = false;
      _playingOnEarbud = false;
      _directionStep = null;
    });
    await _stopQuietly();
  }

  /// Stops the sound without touching the state (also used in [dispose]).
  Future<void> _stopQuietly() async {
    try {
      await _engine.stop();
    } on PlatformException catch (e) {
      logger.e('TestPage: Stopping the playback failed', error: e);
    }
  }

  /// Stops the audio and pops back to the calibration screen with `true`.
  Future<void> _finishExercise() async {
    await _stopAudio();

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  /// What the user has to know before pressing 'Start', or the playback
  /// error; null if neither.
  String? get _note {
    if (_error != null) return _error;
    if (!_soundSupported) return 'Die Aufnahme gibt es nur in der Android-App.';
    if (_connection?.known == true && !_onEarbud) {
      return 'Deine Kopfhörer sind nicht verbunden. Die Aufnahme läuft dann '
          'über den Lautsprecher – links, rechts und der Richtungstest sind '
          'nur über die Earbuds zu hören.';
    }
    return null;
  }

  /// The direction the recording comes from right now, for the status line;
  /// empty while the centred exercise plays.
  String get _directionSuffix {
    final step = _directionStep;
    if (step == null) return '';
    return ' – Richtung ${earbudDirectionSteps[step].label}, Schritt '
        '${step + 1} von ${earbudDirectionSteps.length}';
  }

  /// Height of one side's bars in the card: the wheel value, leaned by the
  /// share of the sound this side gets right now.
  ///
  /// NOTE: The wheel value, not the played gain. The gain runs over 40 dB, so
  /// a bar would be a stump at half volume; the card shows what the user set,
  /// with the direction on top of it.
  double _barStrength(int volume, double pan) => volume / 100 * pan;

  /// The playback controls: 'Start', 'Richtungstest' and 'Stop' are always on
  /// the screen, each usable only while it applies, plus the way to the
  /// Bluetooth settings while the earbud is missing.
  ///
  /// NOTE: In between, the page showed only the one button that applied, so
  /// there was never a disabled one. The team asked for the pair back: the
  /// exercise is explained in terms of 'Start' and 'Stop', and a control
  /// that exists only in one state is easy to miss. The dead end that
  /// arrangement once had is gone from the other side as well — 'Start' now
  /// works without an earbud (on the phone's own output, see [_canPlay]),
  /// and the Bluetooth settings stay one tap away for the user who wants to
  /// hear the calibration itself.
  List<Widget> _buildPlaybackControls() {
    final needsBluetooth =
        _soundSupported && _connection?.known == true && !_onEarbud;

    return [
      // Always in the app's colour where there is sound at all: 'Start' is
      // what the screen is for, and it also restarts a running playback.
      PlaybackButton(
        label: 'Start',
        icon: Icons.play_arrow_rounded,
        color: AppColors.primary(context),
        textColor: AppColors.onPrimary(context),
        onPressed: _canPlay ? _startAudio : null,
      ),
      const SizedBox(height: 10),
      // The second exercise. Usable wherever 'Start' is; that the directions
      // themselves need the earbuds is what the note says.
      PlaybackButton(
        label: 'Richtungstest',
        icon: Icons.compare_arrows_rounded,
        color: AppColors.primary(context),
        textColor: AppColors.onPrimary(context),
        onPressed: _canPlay ? _startDirectionTest : null,
      ),
      const SizedBox(height: 10),
      // Grey until there is something to stop, red while the sound runs.
      PlaybackButton(
        label: 'Stop',
        icon: Icons.stop_rounded,
        color: AppColors.stopRed,
        textColor: Colors.white,
        onPressed: _isPlaying ? _stopAudio : null,
      ),
      if (needsBluetooth) ...[
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
    ];
  }

  @override
  Widget build(BuildContext context) {
    // How the sound is shared between the ears right now: both at 1.0 while
    // the centred exercise runs, leaning during the direction test.
    final pan = StereoGains.forAngle(_engine.angle);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Testübung',
              onBackPressed: () async {
                // Captured before the await so no BuildContext is used across
                // the async gap.
                final navigator = Navigator.of(context);
                await _stopAudio();
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
                    _WaveCard(
                      leftStrength: _barStrength(widget.leftVolume, pan.left),
                      rightStrength:
                          _barStrength(widget.rightVolume, pan.right),
                      isPlaying: _isPlaying,
                    ),
                    const SizedBox(height: 10),
                    // The waveform is decorative; this line states the same
                    // information in words — the direction included, which the
                    // leaning bars only show — so it also works without sight.
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _isPlaying
                            ? 'Wiedergabe läuft ${_onEarbud ? 'über die '
                                'Kopfhörer' : 'über den Lautsprecher'} – '
                                'links ${widget.leftVolume}, rechts '
                                '${widget.rightVolume}$_directionSuffix'
                            : 'Wiedergabe gestoppt – links '
                                '${widget.leftVolume}, rechts '
                                '${widget.rightVolume}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                          height: 1.3,
                        ),
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
                    ..._buildPlaybackControls(),
                    const SizedBox(height: 22),
                    Semantics(
                      header: true,
                      child: Text(
                        'Beschreibung',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text(context),
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Drücke Start, um die Marschieren-Aufnahme abzuspielen. '
                      'Die Wiedergabe wird an deine Links-Rechts-Kalibrierung '
                      'angepasst. Beim Richtungstest wandert die Aufnahme in '
                      'fünf Schritten von ganz links nach ganz rechts – sage '
                      'dabei, aus welcher Richtung du sie hörst.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
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
            // 'Abschließen' sits outside the scroll view, so it stays pinned to
            // the bottom of the screen and is always reachable.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ElevatedButton(
                    onPressed: _finishExercise,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: AppColors.onPrimary(context),
                      elevation: 4,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      minimumSize: const Size(double.infinity, 72),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(42),
                      ),
                    ),
                    child: Text(
                      'Abschließen',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Waveform ─────────────────────────────────────────────────────────────────

/// Translucent card with two bar "waveforms" (left and right). The bar heights
/// follow how much sound each side gets right now — the calibrated volume,
/// leaned by the direction — and travel sideways while the sound plays.
///
/// The animation runs exactly as long as the playback: it starts with 'Start'
/// and freezes at its current shape with 'Stop', so the card doubles as a
/// visible playback indicator.
///
/// Decorative: the same information is available as text below the card, so the
/// card is hidden from screen readers.
class _WaveCard extends StatefulWidget {
  /// Height of the left bars, 0.0-1.0.
  final double leftStrength;

  /// Height of the right bars, 0.0-1.0.
  final double rightStrength;

  /// Drives the animation: `true` while the sound is playing.
  final bool isPlaying;

  const _WaveCard({
    required this.leftStrength,
    required this.rightStrength,
    required this.isPlaying,
  });

  @override
  State<_WaveCard> createState() => _WaveCardState();
}

class _WaveCardState extends State<_WaveCard>
    with SingleTickerProviderStateMixin {
  /// Runs from 0 to 1 and repeats; the value is the phase of the wave.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// True if the system asks for reduced motion
  /// (see docs/PROJECT_CONTEXT.md §1).
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _WaveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncAnimation();
    }
  }

  /// Starts or stops the repeating animation to match the playback state.
  ///
  /// `stop()` keeps the current value, so the bars freeze in place instead of
  /// snapping back to their starting shape.
  void _syncAnimation() {
    final shouldRun = widget.isPlaying && !_reduceMotion;

    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = AppColors.primary(context);

    final leftStrength = widget.leftStrength.clamp(0.0, 1.0).toDouble();
    final rightStrength = widget.rightStrength.clamp(0.0, 1.0).toDouble();

    return ExcludeSemantics(
      child: Container(
        width: double.infinity,
        height: 108,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          // Translucent, so the card reads as part of the background instead of
          // a solid block. It is decoration only; the bars themselves keep the
          // full accent colour.
          color: AppColors.waveCard(context).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: lineColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              children: [
                Expanded(
                  child: _WaveHalf(
                    strength: leftStrength,
                    phase: _controller.value,
                    color: lineColor,
                    alignRight: true,
                  ),
                ),
                Container(
                  width: 2,
                  height: 62,
                  color: lineColor.withValues(alpha: 0.9),
                ),
                Expanded(
                  child: _WaveHalf(
                    strength: rightStrength,
                    // Half a period offset, so the two sides do not pulse in
                    // lockstep and the movement reads as stereo.
                    phase: (_controller.value + 0.5) % 1.0,
                    color: lineColor,
                    alignRight: false,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One half of the [_WaveCard]: a row of glowing bars.
///
/// NOTE: The number of bars follows the available width (at most [_maxBars]).
/// A fixed count of 22 overflowed the card on narrow phones.
class _WaveHalf extends StatelessWidget {
  /// Volume of this side as 0.0–1.0; scales every bar.
  final double strength;

  /// Phase of the travelling wave, 0.0–1.0. A constant value renders a still
  /// waveform, which is what a stopped playback shows.
  final double phase;

  final Color color;

  /// True for the left half, so its bars sit against the centre line.
  final bool alignRight;

  const _WaveHalf({
    required this.strength,
    required this.phase,
    required this.color,
    required this.alignRight,
  });

  static const double _barWidth = 4;
  static const double _barGap = 3;
  static const int _maxBars = 22;

  /// Height factor (0.10–1.0) of the bar at [index] for the current [phase].
  ///
  /// The sine runs over the bar index *and* the phase, so raising the phase
  /// moves the whole pattern sideways.
  double _barValue(int index) {
    final wave = math.sin((index * 0.55) + (phase * 2 * math.pi)).abs();
    final shape = 0.35 + (wave * 0.65);
    return (shape * strength).clamp(0.10, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitting =
            ((constraints.maxWidth + _barGap) / (_barWidth + _barGap)).floor();
        final count = fitting.clamp(0, _maxBars);

        final bars = <Widget>[];
        for (int i = 0; i < count; i++) {
          if (i > 0) bars.add(const SizedBox(width: _barGap));
          bars.add(Container(
            width: _barWidth,
            height: 10 + (_barValue(i) * 42),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 5,
                  spreadRadius: 0.3,
                ),
              ],
            ),
          ));
        }

        return Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: bars,
        );
      },
    );
  }
}
