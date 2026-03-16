// lib/features/device/screens/TestPage.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';

/// Plays a stereo test tone through the native Android AudioTrack API.
/// Left and right channel volumes are mapped from the calibration range
/// 1–100  →  0.0–1.0 float gain.
class _AudioTestService {
  static const MethodChannel _channel =
  MethodChannel('com.soundpilot/audio_devices');

  static Future<void> playTestTone({
    required int leftVolume,
    required int rightVolume,
  }) async {
    await _channel.invokeMethod('playTestTone', {
      'leftVolume': leftVolume,
      'rightVolume': rightVolume,
    });
  }

  static Future<void> stopTestTone() async {
    await _channel.invokeMethod('stopTestTone');
  }
}

class TestPage extends StatefulWidget {
  final int leftVolume;
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
  bool _isPlaying = false;

  Future<void> _startTone() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    await _AudioTestService.playTestTone(
      leftVolume: widget.leftVolume,
      rightVolume: widget.rightVolume,
    );
  }

  Future<void> _stopTone() async {
    if (!_isPlaying) return;
    await _AudioTestService.stopTestTone();
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    // Make sure tone stops if user navigates away
    _AudioTestService.stopTestTone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _TestTopBar(onBackPressed: () {
              _stopTone();
              Navigator.pop(context);
            }),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Volume display card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 22, horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _VolumeBadge(
                            label: 'Links',
                            value: widget.leftVolume,
                          ),
                          Container(
                            width: 1.5,
                            height: 50,
                            color: AppColors.inputBorder(context),
                          ),
                          _VolumeBadge(
                            label: 'Rechts',
                            value: widget.rightVolume,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Start button
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isPlaying ? null : _startTone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPlaying
                              ? AppColors.inactiveButton(context)
                              : AppColors.primary(context),
                          foregroundColor: AppColors.onPrimary(context),
                          elevation: 4,
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

                    // Stop button
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isPlaying ? _stopTone : null,
                        style: ElevatedButton.styleFrom(
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
                          children: [
                            const Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            const Text(
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

                    // Description
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
                        'Drücke Start um einen Testton\nzu hören. Der Ton entspricht\ndeinen Kalibrierungseinstellungen.\nPrüfe ob links und rechts\nkorrekt klingen.',
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

                    // Finish button
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _stopTone();

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

                          Navigator.pop(context); // loading
                          Navigator.pop(context, true); // TestPage
                        },
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

// ── Volume Badge ──────────────────────────────────────────────────────────────

class _VolumeBadge extends StatelessWidget {
  final String label;
  final int value;

  const _VolumeBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedText(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value %',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.text(context),
          ),
        ),
      ],
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TestTopBar extends StatelessWidget {
  final VoidCallback onBackPressed;

  const _TestTopBar({required this.onBackPressed});

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