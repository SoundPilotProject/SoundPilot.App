// lib/features/device/widgets/remove_device_dialog.dart
//
// Confirmation before a device and its settings are removed from the list.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Asks whether to remove the device [name]. Pops with `true` for
/// "Entfernen"; keeping it (button, back or tapping outside) pops with `false`
/// or `null`.
///
/// NOTE: With a screen reader the delete button is the element right after
/// the card, so one double tap too many would drop the device and its
/// calibration for good. The safe choice is the prominent button. There is no
/// time limit.
class RemoveDeviceDialog extends StatelessWidget {
  final String name;

  const RemoveDeviceDialog({super.key, required this.name});

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
                Icons.delete_outline_rounded,
                size: 40,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              header: true,
              // Names the dialog's route, so screen readers say what has
              // just opened.
              namesRoute: true,
              child: Text(
                'Gerät entfernen?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '„$name“ wird mit seinen Einstellungen aus der Liste entfernt. '
              'Das kann nicht rückgängig gemacht werden.',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              child: Text(
                'Behalten',
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
                'Entfernen',
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
