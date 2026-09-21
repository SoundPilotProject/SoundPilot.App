// lib/features/device/screens/TestPage.dart
//
// Test exercise: plays a sound with the calibrated left/right volume.

import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
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
            _TestTopBar(
              onBackPressed: () async {
                await _stopAudio();
                if (!mounted) return;
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WaveCard(
                      leftVolume: widget.leftVolume,
                      rightVolume: widget.rightVolume,
                      isPlaying: _isPlaying,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isPlaying ? null : _startAudio,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPlaying
                              ? AppColors.inactiveButton(context)
                              : AppColors.primary(context),
                          foregroundColor: AppColors.onPrimary(context),
                          elevation: 4,
                          // TODO(improve): `withOpacity` is deprecated, use
                          // `withValues(alpha: ...)` (see LoginScreen).
                          shadowColor: Colors.black.withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.onPrimary(context),
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Start',
                              // TODO(improve): 'Start' and 'Stop' use the
                              // default TextStyle, all other texts use
                              // GoogleFonts.poppins. Use the same font.
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isPlaying ? _stopAudio : null,
                        style: ElevatedButton.styleFrom(
                          // TODO(improve): Hard-coded red; move it to
                          // AppColors (e.g. next to `disconnectedRed`).
                          backgroundColor: _isPlaying
                              ? const Color(0xFFFF0000)
                              : AppColors.inactiveButton(context),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Stop',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Beschreibung',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(context),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Drücke Start um die Marschieren-MP3\nabzuspielen. Die Wiedergabe wird an\ndeine Links/Rechts-Kalibrierung\nangepasst.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                          height: 1.32,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: _finishExercise,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          foregroundColor: AppColors.onPrimary(context),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(42),
                          ),
                        ),
                        child: Text(
                          'Abschließen',
                          style: GoogleFonts.poppins(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary(context),
                          ),
                        ),
                      ),
                    ),
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

/// Card with two bar "waveforms" (left and right) whose height follows the
/// calibrated volumes.
class _WaveCard extends StatelessWidget {
  final int leftVolume;
  final int rightVolume;

  /// Slightly changes the bar heights while the sound is playing.
  final bool isPlaying;

  const _WaveCard({
    required this.leftVolume,
    required this.rightVolume,
    required this.isPlaying,
  });

  /// Builds [count] bar heights (0.10–1.0) from a fixed sine pattern, scaled by
  /// [strength] (0.0–1.0).
  ///
  /// NOTE: With [animated] the bars get a fixed per-bar factor; it is not a
  /// running animation. The heights only change once when playback starts or
  /// stops.
  /// TODO(improve): Use an AnimationController for a real animation.
  List<double> _buildBars({
    required int count,
    required double strength,
    required bool animated,
  }) {
    final List<double> values = [];
    for (int i = 0; i < count; i++) {
      final wave = math.sin((i + 1) * 0.9).abs();
      final shape = 0.25 + (wave * 0.75);
      final pulse = animated ? (0.88 + (math.cos(i * 0.7).abs() * 0.22)) : 1.0;
      values.add((shape * strength * pulse).clamp(0.10, 1.0));
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark(context);
    // TODO(improve): The dark-mode colours below (0xFF121212 card, 0xFFF2E38A
    // lines) are hard-coded. 0xFFF2E38A equals the dark `primary`; move both to
    // AppColors.
    final cardColor = isDark ? const Color(0xFF121212) : AppColors.surface(context);
    final lineColor = isDark
        ? const Color(0xFFF2E38A)
        : AppColors.primary(context);

    final leftStrength = (leftVolume / 100).clamp(0.0, 1.0);
    final rightStrength = (rightVolume / 100).clamp(0.0, 1.0);

    final leftBars = _buildBars(
      count: 22,
      strength: leftStrength.toDouble(),
      animated: isPlaying,
    );
    final rightBars = _buildBars(
      count: 22,
      strength: rightStrength.toDouble(),
      animated: isPlaying,
    );

    return Container(
      width: double.infinity,
      height: 108,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: _WaveHalf(
              bars: leftBars,
              color: lineColor,
              alignRight: true,
            ),
          ),
          Container(
            width: 2,
            height: 62,
            color: lineColor.withOpacity(0.9),
          ),
          Expanded(
            child: _WaveHalf(
              bars: rightBars,
              color: lineColor,
              alignRight: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the [_WaveCard]: a row of glowing bars.
class _WaveHalf extends StatelessWidget {
  /// Relative bar heights (0.0–1.0).
  final List<double> bars;
  final Color color;

  /// True for the left half, so its bars sit against the centre line.
  final bool alignRight;

  const _WaveHalf({
    required this.bars,
    required this.color,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final children = bars.map((value) {
      final barHeight = 10 + (value * 42);
      return Container(
        width: 4,
        height: barHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 5,
              spreadRadius: 0.3,
            ),
          ],
        ),
      );
    }).toList();

    return Row(
      mainAxisAlignment:
      alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}

/// Blue top bar with a back arrow and the title 'Testübung'.
///
/// TODO(improve): Duplicate of the other screens' top bars, see
/// `_LoginTopBar`.
class _TestTopBar extends StatelessWidget {
  final VoidCallback onBackPressed;

  const _TestTopBar({
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      width: double.infinity,
      color: AppColors.primary(context),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackPressed,
            splashRadius: 24,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.onPrimary(context),
              size: 36,
            ),
          ),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(-18, 0),
                child: Text(
                  'Testübung',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}