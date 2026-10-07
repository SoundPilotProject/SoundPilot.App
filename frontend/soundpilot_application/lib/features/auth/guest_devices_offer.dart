// lib/features/auth/guest_devices_offer.dart
//
// After a sign-in or registration on a phone with stored guest devices: asks
// whether they go into the account, then uploads or deletes them.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_logger.dart';
import '../../core/services/device_storage_service.dart';
import '../../core/services/firestore_device_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_screen.dart';
import '../../models/user_model.dart';

/// Uploads guest devices into the account of the signed-in user.
typedef GuestDeviceUpload = Future<void> Function(DeviceData devices);

/// How long the upload may take (including waiting for the user document of
/// a new account) before it counts as failed. Not a limit for the user.
const Duration guestUploadTimeout = Duration(seconds: 30);

/// Offers the guest devices stored on this phone to the user [uid] who just
/// signed in. Does nothing if there are none.
///
/// - "Geräte übernehmen": uploads the devices that are not in the account yet
///   ([upload], by default [FirestoreDeviceRepository.addMissingDevices]),
///   then deletes them on the phone. If that fails, a message says so and
///   they stay, so the question comes again on the next sign-in.
/// - "Geräte löschen": deletes them on the phone.
///
/// NOTE: If the app is closed while the dialog is open, the devices stay on
/// the phone and are offered again on the next sign-in (docs §7).
Future<void> offerGuestDevices(
  BuildContext context, {
  required String uid,
  GuestDeviceUpload? upload,
}) async {
  const guest = DeviceStorageService.guestOwner;
  final devices = await DeviceStorageService.load(guest);
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
    await DeviceStorageService.clear(guest);
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
    await DeviceStorageService.clear(guest);
  } catch (e) {
    logger.e('offerGuestDevices: Taking over the guest devices failed',
        error: e);
    messenger.showSnackBar(const SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Die Geräte konnten nicht übernommen werden. Sie bleiben auf '
              'diesem Gerät gespeichert, und du wirst bei der nächsten '
              'Anmeldung noch einmal gefragt.',
            ),
          ),
        ],
      ),
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
                'Du hast als Gast $devices gespeichert. Sollen sie in dein '
                'Konto übernommen werden? Sonst werden sie von diesem Gerät '
                'gelöscht.',
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
