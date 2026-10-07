// lib/features/device/widgets/unsynced_logout_dialog.dart
//
// Warning before a logout that would lose changes not yet sent to the server.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Asks whether to log out although some changes are not saved yet (no
/// internet connection). Pops with `true` for "Trotzdem abmelden"; staying
/// signed in (button, back or tapping outside) pops with `false` or `null`.
///
/// The safe choice is the prominent button. There is no time limit.
class UnsyncedLogoutDialog extends StatelessWidget {
  const UnsyncedLogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      // Scrollable: at large system font sizes the text is taller than a
      // small phone.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.cloud_off,
                size: 40,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              header: true,
              child: Text(
                'Nicht gespeicherte Änderungen',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text(context),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Einige Änderungen sind noch nicht gespeichert, weil keine '
              'Internetverbindung besteht. Wenn du dich jetzt abmeldest, '
              'gehen sie verloren.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                elevation: 3,
                minimumSize: const Size(double.infinity, 54),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              child: Text(
                'Angemeldet bleiben',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onPrimary(context),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                'Trotzdem abmelden',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
