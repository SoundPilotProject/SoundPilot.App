// lib/core/services/device_storage_service.dart
//
// Manages local persistence for device lists and calibration data using SharedPreferences.
// Key schema: user_calibration_<userId>
// Guests use the "guest" suffix.

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';
import '../../models/user_model.dart';

/// Local (SharedPreferences) storage for the device list and the calibration
/// of headphones and belts, including the guest-to-user migration.
///
/// TODO(improve): Everything is stored locally only. The Firestore document
/// (`users/{uid}.calibration`) is not used yet; see CLAUDE.md for the planned
/// field-path updates per device.
class DeviceStorageService {
  /// Current Firebase User ID or 'guest' for anonymous mode.
  static String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  /// We store the entire calibration structure (Headphones + Belts) as a
  /// single JSON string.
  static String get _calibrationKey => 'user_calibration_$_userId';

  // ── Save Calibration ───────────────────────────────────────────────────────

  /// Stores both headphone and belt calibration maps to local storage.
  /// Converts the typed objects into JSON-compatible maps.
  static Future<void> saveUserCalibration({
    required Map<String, HeadphoneCalib> headphones,
    required Map<String, BeltCalib> belts,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'headphones': headphones.map((key, val) => MapEntry(key, val.toMap())),
      'belts': belts.map((key, val) => MapEntry(key, val.toMap())),
    };

    await prefs.setString(_calibrationKey, jsonEncode(data));
    logger.i('DeviceStorageService: Calibration for $_userId saved locally.');
  }

  // ── Load Calibration ───────────────────────────────────────────────────────

  /// Loads the stored device calibrations from local storage.
  /// Returns a Map containing 'headphones' and 'belts' maps.
  ///
  /// TODO(improve): Return a small typed class instead of an untyped
  /// `Map<String, dynamic>`. Callers currently have to cast the values
  /// (see DeviceScreen._loadDevices).
  static Future<Map<String, dynamic>> loadUserCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_calibrationKey);

    if (raw == null || raw.isEmpty) {
      logger.i('DeviceStorageService: No local data found for $_userId');
      return {
        'headphones': <String, HeadphoneCalib>{},
        'belts': <String, BeltCalib>{}
      };
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      // Reconstruct HeadphoneCalib objects from stored maps
      final headphones = (decoded['headphones'] as Map<String, dynamic>).map(
            (key, val) => MapEntry(key, HeadphoneCalib.fromMap(val as Map<String, dynamic>)),
      );

      // Reconstruct BeltCalib objects from stored maps
      final belts = (decoded['belts'] as Map<String, dynamic>).map(
            (key, val) => MapEntry(key, BeltCalib.fromMap(val as Map<String, dynamic>)),
      );

      logger.i('DeviceStorageService: Calibration for $_userId loaded successfully.');
      return {
        'headphones': headphones,
        'belts': belts
      };
    } catch (e) {
      // NOTE: A parse error results in an empty device list. The corrupt data
      // is then overwritten with the next save, so it is lost.
      logger.e('DeviceStorageService: Error parsing local calibration', error: e);
      return {
        'headphones': <String, HeadphoneCalib>{},
        'belts': <String, BeltCalib>{}
      };
    }
  }

  // ── Guest to User Migration ────────────────────────────────────────────────

  /// Transfers guest data to the user's account after a successful login.
  /// Ensures that calibration work done in guest mode is preserved.
  static Future<void> migrateGuestDataAfterLogin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();

    final guestData = prefs.getString('user_calibration_guest');
    final userData = prefs.getString('user_calibration_$uid');

    // Only migrate if the user doesn't have data yet and guest data exists
    if (userData == null && guestData != null) {
      await prefs.setString('user_calibration_$uid', guestData);

      // Optional: Clear guest data to avoid redundant migrations
      // await prefs.remove('user_calibration_guest');
      // TODO: Decide whether to clear the guest data. While it stays, the next
      // guest session sees the old data again, and any other new account on
      // this device also inherits it (the migration only checks that the user
      // has no data yet).

      logger.i('DeviceStorageService: Guest data successfully migrated to user $uid.');
    }
  }
}