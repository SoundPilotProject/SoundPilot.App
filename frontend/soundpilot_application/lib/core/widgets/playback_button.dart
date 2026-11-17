// lib/core/widgets/playback_button.dart
//
// Wide button for the playback controls of the exercise screens.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Wide button with an icon and a centred label, used for the playback
/// controls of the test exercise and the guided exercises: 'Start', 'Stop',
/// 'Richtungstest' and the way to the Bluetooth settings.
///
/// Disabled while its control does not apply ([onPressed] null); the note on
/// the screen then says why.
///
/// NOTE: The label sits inside the button's own content and never in a
/// [Semantics] around it (see `docs/PROJECT_CONTEXT.md` §1): an
/// [ElevatedButton] wraps itself in `Semantics(container: true)`, so a wrapper
/// would become a node of its own that a screen reader never focuses.
class PlaybackButton extends StatelessWidget {
  final String label;
  final IconData icon;

  final Color color;
  final Color textColor;

  /// `null` while this control does not apply; the button is then disabled,
  /// and the note on the screen says why.
  final VoidCallback? onPressed;

  /// Smaller for a long label, e.g. the one of the Bluetooth settings.
  final double fontSize;

  const PlaybackButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onPressed,
    this.fontSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // White on the inactive grey is the pair the contrast test measures.
    final contentColor = enabled ? textColor : Colors.white;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        disabledBackgroundColor: AppColors.inactiveButton(context),
        disabledForegroundColor: Colors.white,
        elevation: enabled ? 4 : 0,
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
          Icon(icon, color: contentColor, size: 30),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              // Two lines instead of being cut off at large font sizes.
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: contentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
