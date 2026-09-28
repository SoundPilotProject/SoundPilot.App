// lib/features/auth/screens/start_screen.dart
//
// Welcome screen with the options: register, login or continue as guest.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../core/widgets/soundpilot_logo.dart';

import '../../device/screens/device_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// First screen for users who are not signed in (see AppEntryPoint).
///
/// Leads to the [RegisterScreen], the [LoginScreen] or, as a guest, directly to
/// the [DeviceScreen].
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  /// Starts guest mode: sets the guest flag `continueAsGuestThisSession` and
  /// replaces this screen with the [DeviceScreen].
  ///
  /// The flag is consumed by AppEntryPoint on the next app start.
  ///
  /// NOTE: This used to keep the loading screen visible for a moment with a
  /// `Future.delayed(2 s)`. Original comment: "It slows the UI down on
  /// purpose and can be removed (same in DeviceScreen._logout,
  /// TestPage._finishExercise and BeltVibrationScreen._finishSetup)." Removed
  /// here; the other three call sites still have it.
  Future<void> _continueAsGuest(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(
          text: "Gastmodus wird gestartet...",
        ),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('continueAsGuestThisSession', true);

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const DeviceScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          // Decoration only: sits behind the content and takes no input.
          const Positioned.fill(child: _StartBackdrop()),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Scrollable so the screen survives very large system font
                // sizes. The IntrinsicHeight keeps the Spacers working as long
                // as the content still fits on one page.
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          const SoundPilotLogo(width: 300),

                          const Spacer(flex: 2),

                          Semantics(
                            header: true,
                            child: Text(
                              "Willkommen bei\nSoundPilot",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text(context),
                                height: 1.15,
                              ),
                            ),
                          ),

                          const Spacer(flex: 2),

                          _StartButton(
                            text: "Registrieren",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(
                                    returnToDeviceOnBack: false,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          _StartButton(
                            text: "Login",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(
                                    returnToDeviceOnBack: false,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          // TextButton instead of a bare GestureDetector: it
                          // brings a large tap target, a focus ring and the
                          // button role for screen readers.
                          TextButton(
                            onPressed: () => _continueAsGuest(context),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            child: Text(
                              "Als Gast fortfahren",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text(context),
                              ),
                            ),
                          ),

                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background decoration ────────────────────────────────────────────────────

/// Purely decorative backdrop of the [StartScreen].
///
/// Draws a band in the accent colour (blue in light mode, yellow in dark mode)
/// that fades into the background towards the middle of the screen, plus two
/// soft colour blobs. Everything here is excluded from the semantics tree and
/// ignores pointer events, so it can never get in the way of the content.
class _StartBackdrop extends StatelessWidget {
  const _StartBackdrop();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary(context);
    final size = MediaQuery.sizeOf(context);

    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top band: strong accent colour at the very top, fading out
            // completely towards the middle of the screen.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.85),
                      accent.withValues(alpha: 0.32),
                      accent.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Soft blob behind the logo.
            Positioned(
              top: -size.width * 0.28,
              right: -size.width * 0.22,
              child: _Blob(
                diameter: size.width * 0.85,
                color: accent.withValues(alpha: 0.22),
              ),
            ),

            // Second blob near the buttons; keeps the lower half from looking
            // empty without touching the content.
            Positioned(
              bottom: -size.width * 0.35,
              left: -size.width * 0.30,
              child: _Blob(
                diameter: size.width * 0.90,
                color: accent.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A circle that fades out towards its edge, used by [_StartBackdrop].
class _Blob extends StatelessWidget {
  final double diameter;
  final Color color;

  const _Blob({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

// ── Buttons ──────────────────────────────────────────────────────────────────

/// Large rounded primary button used on the [StartScreen].
///
/// The label is centred and may wrap to two lines, so it stays readable at
/// large system font sizes instead of being clipped.
class _StartButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _StartButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary(context),
        foregroundColor: AppColors.onPrimary(context),
        minimumSize: const Size(double.infinity, 84),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
