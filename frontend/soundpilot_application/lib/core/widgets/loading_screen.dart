// lib/core/widgets/loading_screen.dart
//
// Full-screen loading indicator with the logo and a status text.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'soundpilot_logo.dart';

/// Full-screen loading view: logo, spinner and a status [text].
///
/// Used both as the start-up screen (see AppEntryPoint) and as a route that is
/// pushed on top of a screen while an async action runs and popped afterwards
/// (login, register, logout, ...).
///
/// NOTE: Several callers combine it with an artificial `Future.delayed` so the
/// screen stays visible for a moment (see the TODOs there).
class LoadingScreen extends StatelessWidget {
  /// Status message shown below the spinner (e.g. 'Wird abgemeldet...').
  final String text;

  const LoadingScreen({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SoundPilotLogo(width: 220),

                const SizedBox(height: 60),

                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.primary(context),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
