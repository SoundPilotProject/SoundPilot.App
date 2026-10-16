// lib/core/services/guest_mode_service.dart
//
// Remembers whether the app is used without an account (guest mode).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';
import 'device_repository.dart';
import 'device_storage_service.dart';

/// Guest mode: set when the user chooses "Als Gast fortfahren" on the
/// StartScreen, turned off on sign-in and registration (the guest's devices
/// are then offered for take-over, see offerGuestDevices) and ended ([end])
/// on logout.
///
/// NOTE: Nothing a guest does is written to the phone. The flag lives in
/// memory only, so every app start begins at the StartScreen; the devices do
/// the same ([GuestDeviceRepository]). Both used to be stored, which sent a
/// guest straight to the DeviceScreen on every later start with no way back
/// (there is no button that leaves guest mode, see
/// `docs/PROJECT_CONTEXT.md` §7) and left their devices on the phone.
///
/// AppEntryPoint listens to [active] and switches screens when it changes.
class GuestModeService {
  GuestModeService._();

  /// Current guest mode, for this app run only.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Removes what earlier app versions stored for a guest: the guest mode
  /// flag, so an install carrying it does not start in guest mode, and the
  /// guest's devices. Run once before `runApp`.
  static Future<void> load() async {
    active.value = false;
    final prefs = await SharedPreferences.getInstance();
    // Stored guest mode of earlier app versions, and the read-once flag
    // before that.
    await prefs.remove('guestMode');
    await prefs.remove('continueAsGuestThisSession');
    await DeviceStorageService.clear(DeviceStorageService.guestOwner);
    logger.d('GuestModeService: guest mode = ${active.value}');
  }

  /// Sets guest mode for this app run.
  static Future<void> set(bool value) async {
    active.value = value;
  }

  /// Ends guest mode and forgets the guest's devices, so the next guest
  /// starts with an empty list.
  static Future<void> end() async {
    await set(false);
    GuestDeviceRepository.clear();
  }
}
