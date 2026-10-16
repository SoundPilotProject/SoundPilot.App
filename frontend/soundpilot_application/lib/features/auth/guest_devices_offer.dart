// lib/features/auth/guest_devices_offer.dart
//
// After a sign-in or registration with devices added as a guest: asks
// whether they go into the account, then uploads or forgets them.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_logger.dart';
import '../../core/services/device_repository.dart';
import '../../core/services/firestore_device_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/loading_screen.dart';
import '../../models/user_model.dart';

/// Uploads guest devices into the account of the signed-in user.
typedef GuestDeviceUpload = Future<void> Function(DeviceData devices);

/// How long the upload may take (including waiting for the user document of
/// a new account) before it counts as failed. Not a limit for the user.
const Duration guestUploadTimeout = Duration(seconds: 30);

/// Offers the devices added as a guest ([GuestDeviceRepository], in memory
/// only) to the user [uid] who just signed in. Does nothing if there are
/// none.
///
/// - "Geräte übernehmen": uploads the devices that are not in the account yet
///   ([upload], by default [FirestoreDeviceRepository.addMissingDevices]),
///   the only way they are ever stored. If that fails, a message says so and
///   they stay for this app run.
/// - "Geräte löschen": forgets them.
///
/// NOTE: If the app is closed while the dialog is open, the guest devices are
/// gone with it — nothing a guest adds is written to the phone (docs §4).
Future<void> offerGuestDevices(
  BuildContext context, {
  required String uid,
  GuestDeviceUpload? upload,
}) async {
  final devices = GuestDeviceRepository.devices;
  final count = devices.headphones.length + devices.belts.length;
  if (count == 0 || !context.mounted) return;

  final takeOver = await showDialog<bool>(
    context: context,
    // Both answers have consequences, so tapping outside decides nothing.
    barrierDismissible: false,
    builder: (_) => GuestDevicesDialog(count: count),
  );
  if (!context.mounted) return;

  if (takeOver != true) {
    GuestDeviceRepository.clear();
    return;
  }

  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  navigator.push(MaterialPageRoute(
    builder: (_) =>
        const LoadingScreen(text: 'Geräte werden übernommen...'),
  ));
  try {
    final doUpload = upload ??
        FirestoreDeviceRepository(uid: uid).addMissingDevices;
    await doUpload(devices).timeout(guestUploadTimeout);
    GuestDeviceRepository.clear();
  } catch (e) {
    logger.e('offerGuestDevices: Taking over the guest devices failed',
        error: e);
    messenger.showSnackBar(appErrorSnackBar(
      'Die Geräte konnten nicht übernommen werden. Sie sind nur noch in '
      'dieser Sitzung vorhanden und müssen sonst neu hinzugefügt werden.',
    ));
  } finally {
    navigator.pop();
  }
}

/// Asks whether the [count] guest devices go into the account. Pops with
/// `true` for "Geräte übernehmen", `false` for "Geräte löschen".
///
/// The system back button does nothing here: both answers have consequences.
/// There is no time limit.
class GuestDevicesDialog extends StatelessWidget {
  /// Number of guest devices (headphones and belts).
  final int count;

  const GuestDevicesDialog({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final devices = count == 1 ? '1 Gerät' : '$count Geräte';
    return PopScope(
      canPop: false,
      child: Dialog(
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
                  Icons.devices_other,
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
                  'Gast-Geräte übernehmen?',
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
                'Du hast als Gast $devices hinzugefügt. Sollen sie in dein '
                'Konto übernommen werden? Sonst gehen sie verloren, denn als '
                'Gast wird nichts gespeichert.',
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
                onPressed: () => Navigator.of(context).pop(true),
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
                  'Geräte übernehmen',
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
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  'Geräte löschen',
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
      ),
    );
  }
}
