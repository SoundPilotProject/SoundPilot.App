// lib/core/widgets/google_sign_in_button.dart
//
// Shared "Mit Google anmelden" button of the login and registration screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'google_logo.dart';

/// Button that starts the Google sign-in, used by the login and the
/// registration screen.
///
/// Outlined instead of filled, so the primary action of the screen
/// ('Anmelden' resp. 'Registrieren') stays the most prominent one, while the
/// border and the logo still mark this clearly as a button.
///
/// Accessibility: the label grows with the system font size and wraps to a
/// second line instead of being clipped, the button is at least 80 dp tall,
/// and the [GoogleLogo] is decoration only — the label carries the meaning,
/// never the picture or a colour.
class GoogleSignInButton extends StatelessWidget {
  /// Called when the button is pressed. `null` disables the button, e.g.
  /// while a sign-in is already running.
  final VoidCallback? onPressed;

  /// Label of the button. Defaults to the wording of the login screen; the
  /// registration screen says 'Mit Google registrieren'.
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Mit Google anmelden',
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = onPressed == null
        ? AppColors.mutedText(context)
        : AppColors.text(context);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.text(context),
        side: BorderSide(color: AppColors.inputBorder(context), width: 2),
        minimumSize: const Size(double.infinity, 80),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _LogoBadge(),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White circle holding the [GoogleLogo].
///
/// The circle stays white in both themes: Google's branding guidelines ask for
/// the logo on a light surface, and it keeps the mark recognisable on the dark
/// theme's near-black button as well. Its diameter follows the system font
/// size, so the logo grows together with the label next to it.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    final diameter = MediaQuery.textScalerOf(context).scale(36);

    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: GoogleLogo(size: diameter * 0.6),
    );
  }
}
