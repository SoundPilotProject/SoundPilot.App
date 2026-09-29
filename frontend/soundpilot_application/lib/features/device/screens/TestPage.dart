// lib/features/device/screens/TestPage.dart
//
// Test exercise: plays a sound with the calibrated left/right volume.

import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/loading_screen.dart';

/// Test exercise after the calibration: plays `assets/audio/Marschieren.mp3` in
/// a loop with the volume and balance derived from the calibrated values.
///
/// Pops with `true` when the user taps 'Abschließen'; the back arrow pops
/// without a result.
///
/// TODO(improve): Rename the file to `test_page.dart` (Dart `file_names` lint).
class TestPage extends StatefulWidget {
  /// Calibrated volume of the left side (1–100).
  final int leftVolume;

  /// Calibrated volume of the right side (1–100).
  final int rightVolume;

  const TestPage({
    super.key,
    required this.leftVolume,
    required this.rightVolume,
  });

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// True while the sound is playing.
  bool _isPlaying = false;

  /// Limits [value] to the range 0.0–1.0.
  double _clamp01(double value) {
    return value.clamp(0.0, 1.0);
  }

  /// Player volume (0.0–1.0): the louder of the two sides.
  double _calculateOverallVolume() {
    final left = _clamp01(widget.leftVolume / 100.0);
    final right = _clamp01(widget.rightVolume / 100.0);
    return math.max(left, right);
  }

  /// Player balance from -1.0 (only left) to 1.0 (only right), relative to the
  /// louder side. 0.0 if both sides are 0.
  ///
  /// TODO(improve): The conversion of both sides to 0.0–1.0 is repeated in
  /// [_calculateOverallVolume]; compute it once.
  double _calculateBalance() {
    final left = _clamp01(widget.leftVolume / 100.0);
    final right = _clamp01(widget.rightVolume / 100.0);
    final maxSide = math.max(left, right);

    if (maxSide == 0) return 0.0;

    final balance = (right - left) / maxSide;
    return balance.clamp(-1.0, 1.0);
  }

  /// Starts the looping playback with the calculated volume and balance.
  Future<void> _startAudio() async {
    if (_isPlaying) return;

    final overallVolume = _calculateOverallVolume();
    final balance = _calculateBalance();

    await _audioPlayer.stop();
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setSource(AssetSource('audio/Marschieren.mp3'));
    await _audioPlayer.setVolume(overallVolume);
    await _audioPlayer.setBalance(balance);
    await _audioPlayer.resume();

    if (!mounted) return;
    setState(() => _isPlaying = true);
  }

  /// Stops the playback (no-op if nothing is playing).
  Future<void> _stopAudio() async {
    if (!_isPlaying) return;

    await _audioPlayer.stop();

    if (!mounted) return;
    setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Stops the audio, shows a short loading screen and pops back to the
  /// calibration screen with `true`.
  ///
  /// TODO(improve): The `Future.delayed(2 s)` only keeps the loading screen
  /// visible for a moment and slows the UI down on purpose (see
  /// StartScreen._continueAsGuest).
  Future<void> _finishExercise() async {
    await _stopAudio();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(
          text: 'Übung wird abgeschlossen...',
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pop(context);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
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
                      leftVolume: widget.leftVolume,
                      rightVolume: widget.rightVolume,
                      isPlaying: _isPlaying,
                    ),
                    const SizedBox(height: 10),
                    // The waveform is decorative; this line states the same
                    // information in words, so it also works without sight.
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _isPlaying
                            ? 'Wiedergabe läuft – links '
                                '${widget.leftVolume}, rechts '
                                '${widget.rightVolume}'
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
                    _PlaybackButton(
                      label: 'Start',
                      icon: Icons.play_arrow_rounded,
                      enabled: !_isPlaying,
                      activeColor: AppColors.primary(context),
                      activeTextColor: AppColors.onPrimary(context),
                      onPressed: _startAudio,
                    ),
                    const SizedBox(height: 12),
                    _PlaybackButton(
                      label: 'Stop',
                      icon: Icons.stop_rounded,
                      enabled: _isPlaying,
                      activeColor: AppColors.stopRed,
                      activeTextColor: Colors.white,
                      onPressed: _stopAudio,
                    ),
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
                      'angepasst.',
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

// ── Playback buttons ─────────────────────────────────────────────────────────

/// Wide 'Start' / 'Stop' button with an icon and a centred label.
///
/// Disabled state is not shown by colour alone: a disabled button is also
/// reported as disabled to screen readers because [onPressed] is null.
class _PlaybackButton extends StatelessWidget {
  final String label;
  final IconData icon;

  /// False while the action is not available (e.g. 'Stop' while nothing plays).
  final bool enabled;

  final Color activeColor;
  final Color activeTextColor;
  final VoidCallback onPressed;

  const _PlaybackButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.activeColor,
    required this.activeTextColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? activeTextColor : Colors.white;

    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: activeColor,
        foregroundColor: activeTextColor,
        disabledBackgroundColor: AppColors.inactiveButton(context),
        disabledForegroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        minimumSize: const Size(double.infinity, 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground, size: 30),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waveform ─────────────────────────────────────────────────────────────────

/// Translucent card with two bar "waveforms" (left and right). The bar heights
/// follow the calibrated volumes and travel sideways while the sound plays.
///
/// The animation runs exactly as long as the playback: it starts with 'Start'
/// and freezes at its current shape with 'Stop', so the card doubles as a
/// visible playback indicator.
///
/// Decorative: the same information is available as text below the card, so the
/// card is hidden from screen readers.
class _WaveCard extends StatefulWidget {
  final int leftVolume;
  final int rightVolume;

  /// Drives the animation: `true` while the sound is playing.
  final bool isPlaying;

  const _WaveCard({
    required this.leftVolume,
    required this.rightVolume,
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

    final leftStrength = (widget.leftVolume / 100).clamp(0.0, 1.0).toDouble();
    final rightStrength = (widget.rightVolume / 100).clamp(0.0, 1.0).toDouble();

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
