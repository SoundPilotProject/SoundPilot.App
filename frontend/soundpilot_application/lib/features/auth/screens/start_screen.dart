// lib/features/auth/screens/start_screen.dart
//
// Welcome screen with the options: register, login or continue as guest.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/guest_mode_service.dart';
import '../../../core/theme/app_colors.dart';
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

  /// Starts guest mode. AppEntryPoint then replaces this screen with the
  /// [DeviceScreen]; guest mode stays active on later app starts until the
  /// user signs in or logs out.
  ///
  /// NOTE: This used to keep the loading screen visible for a moment with a
  /// `Future.delayed(2 s)`. Original comment: "It slows the UI down on
  /// purpose and can be removed (same in DeviceScreen._logout,
  /// TestPage._finishExercise and BeltVibrationScreen._finishSetup)." Removed
  /// here; the other three call sites still have it. The loading screen is
  /// gone as well, because switching to guest mode is instant.
  Future<void> _continueAsGuest() async {
    await GuestModeService.set(true);
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
                      builder: (_) => const RegisterScreen(),
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
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 35),

              GestureDetector(
                onTap: _continueAsGuest,
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