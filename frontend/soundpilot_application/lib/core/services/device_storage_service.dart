// lib/core/services/device_storage_service.dart
//
// Local persistence of the device list and calibration in SharedPreferences.
// Key schema: user_calibration_<owner>; the guest is the owner "guest".

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';
import '../../models/user_model.dart';

/// Local (SharedPreferences) storage for the devices of one owner.
///
/// Guests keep their devices here ([LocalDeviceRepository]), only on this
/// phone, until guest mode ends (GuestModeService.end deletes them).
/// Signed-in users keep them in Firestore; for them this storage only holds
/// data from before the Firestore sync, which [FirestoreDeviceRepository]
/// uploads once and then clears.
class DeviceStorageService {
  /// Owner of the guest's devices.
  static const String guestOwner = 'guest';

  /// The whole structure (headphones + belts) is stored as one JSON string,
  /// in the same format as the Firestore field `calibration`.
  static String _key(String owner) => 'user_calibration_$owner';

  // ── Save ───────────────────────────────────────────────────────────────────

  /// Stores [data] as the devices of [owner].
  static Future<void> save(String owner, DeviceData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(owner), jsonEncode(data.toMap()));
    logger.i('DeviceStorageService: Devices of $owner saved locally.');
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  /// Loads the devices of [owner]; no devices if nothing is stored.
  static Future<DeviceData> load(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(owner));

    if (raw == null || raw.isEmpty) {
      logger.i('DeviceStorageService: No local data found for $owner');
      return const DeviceData();
    }

    try {
      // Invalid entries are skipped, see parseDeviceMap.
      final data = DeviceData.fromMap(jsonDecode(raw));
      logger.i('DeviceStorageService: Devices of $owner loaded successfully.');
      return data;
    } catch (e) {
      // NOTE: A parse error results in an empty device list. The corrupt data
      // is then overwritten with the next save, so it is lost.
      logger.e('DeviceStorageService: Error parsing local calibration', error: e);
      return const DeviceData();
    }
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

  /// Removes the stored devices of [owner].
  static Future<void> clear(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(owner));
    logger.i('DeviceStorageService: Local devices of $owner removed.');
  }
}
