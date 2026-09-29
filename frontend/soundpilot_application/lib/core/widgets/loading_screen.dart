// lib/core/widgets/loading_screen.dart
//
// Full-screen loading indicator with the logo and a status text.

import 'dart:math' as math;

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
/// The status text is a live region, so screen readers announce it instead of
/// leaving blind users with a silent screen.
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Sized from the screen width so the logo stays large on a
                // phone but does not blow up on a tablet.
                SoundPilotLogo(
                  width: math.min(MediaQuery.sizeOf(context).width * 0.82, 380),
                ),

                const SizedBox(height: 44),

                SizedBox(
                  width: 62,
                  height: 62,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.primary(context),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Semantics(
                  liveRegion: true,
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text(context),
                      height: 1.3,
                    ),
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
