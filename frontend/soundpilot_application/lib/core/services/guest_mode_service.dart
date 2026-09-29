// lib/core/services/guest_mode_service.dart
//
// Remembers whether the app is used without an account (guest mode).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';

/// Guest mode: set when the user chooses "Als Gast fortfahren" on the
/// StartScreen, cleared on sign-in and on logout.
///
/// The value is stored in SharedPreferences, so a guest goes straight to the
/// DeviceScreen on the next app start. AppEntryPoint listens to [active] and
/// switches screens when it changes.
class GuestModeService {
  GuestModeService._();

  static const String _key = 'guestMode';

  /// Current guest mode. Read [load] once before `runApp`.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Reads the stored value into [active].
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    active.value = prefs.getBool(_key) ?? false;
    // Old read-once flag of earlier app versions, replaced by [_key].
    await prefs.remove('continueAsGuestThisSession');
    logger.d('GuestModeService: guest mode = ${active.value}');
  }

  /// Sets guest mode and stores it.
  static Future<void> set(bool value) async {
    active.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
