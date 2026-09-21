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
  /// TODO(improve): The `Future.delayed(2 s)` below only keeps the loading
  /// screen visible for a moment. It slows the UI down on purpose and can be
  /// removed (same in DeviceScreen._logout, TestPage._finishExercise and
  /// BeltVibrationScreen._finishSetup).
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

    await Future.delayed(const Duration(seconds: 2));

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),

              const SoundPilotLogo(width: 320),

              const Spacer(flex: 3),

              Text(
                "Willkommen bei\nSoundPilot",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(context),
                  height: 1.15,
                ),
              ),

              const Spacer(flex: 3),

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

              const SizedBox(height: 25),

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

              const SizedBox(height: 35),

              GestureDetector(
                onTap: () => _continueAsGuest(context),
                child: Text(
                  "Als Gast Fortfahren",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large rounded primary button used on the [StartScreen].
class _StartButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _StartButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 90,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(context),
          foregroundColor: AppColors.onPrimary(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}