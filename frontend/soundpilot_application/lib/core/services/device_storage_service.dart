// lib/core/services/device_storage_service.dart
//
// Speichert Geräteliste + Kalibrierung pro Benutzer in SharedPreferences.
// Key-Schema:  devices_<userId>   und   calibration_<userId>
// Gäste nutzen den Key "guest".

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';
import 'calibration_service.dart';

// ── Geräte-Modell ─────────────────────────────────────────────────────────

class DeviceItem {
  final String name;
  final String category; // 'Earbuds' oder 'Gürtel'
  bool isConnected;

  DeviceItem({
    required this.name,
    required this.category,
    this.isConnected = false,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'isConnected': isConnected,
      };

  factory DeviceItem.fromMap(Map<String, dynamic> map) => DeviceItem(
        name: map['name'] as String,
        category: map['category'] as String,
        isConnected: (map['isConnected'] as bool?) ?? false,
      );
}

// ── Service ────────────────────────────────────────────────────────────────

class DeviceStorageService {
  // Aktuelle User-ID oder 'guest' für Gastmodus
  static String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  static String get _devicesKey => 'devices_$_userId';
  static String get _calibLeftKey => 'calibration_left_$_userId';
  static String get _calibRightKey => 'calibration_right_$_userId';

  // ── Geräte speichern ────────────────────────────────────────────────────

  static Future<void> saveDevices(List<DeviceItem> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(devices.map((d) => d.toMap()).toList());
    await prefs.setString(_devicesKey, encoded);
    logger.i('DeviceStorageService: ${devices.length} Geräte gespeichert für $_userId');
  }

  // ── Geräte laden ────────────────────────────────────────────────────────

  static Future<List<DeviceItem>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_devicesKey);

    if (raw == null || raw.isEmpty) {
      logger.i('DeviceStorageService: keine gespeicherten Geräte für $_userId');
      return [];
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final devices = list
          .map((e) => DeviceItem.fromMap(e as Map<String, dynamic>))
          .toList();
      logger.i('DeviceStorageService: ${devices.length} Geräte geladen für $_userId');
      return devices;
    } catch (e) {
      logger.e('DeviceStorageService: Fehler beim Laden der Geräte', error: e);
      return [];
    }
  }

  // ── Kalibrierung speichern ───────────────────────────────────────────────

  static Future<void> saveCalibration(CalibrationData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_calibLeftKey, data.leftVolume);
    await prefs.setInt(_calibRightKey, data.rightVolume);
    logger.i(
      'DeviceStorageService: Kalibrierung L=${data.leftVolume} R=${data.rightVolume} für $_userId',
    );
  }

  // ── Kalibrierung laden ───────────────────────────────────────────────────

  static Future<CalibrationData> loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final left = prefs.getInt(_calibLeftKey);
    final right = prefs.getInt(_calibRightKey);

    if (left != null && right != null) {
      logger.i('DeviceStorageService: Kalibrierung L=$left R=$right für $_userId geladen');
      return CalibrationData(leftVolume: left, rightVolume: right);
    }

    logger.i('DeviceStorageService: keine Kalibrierung für $_userId, nutze Standard');
    return const CalibrationData.defaults();
  }

  // ── Nach Login: Gastdaten → Benutzerkonto übertragen ───────────────────
  //
  // Wenn der Nutzer vorher als Gast kalibriert/Geräte hinzugefügt hat,
  // werden diese Daten beim ersten Login in sein Konto übernommen.

  static Future<void> migrateGuestDataAfterLogin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Prüfen ob bereits Nutzerdaten vorhanden sind
    final hasUserDevices = prefs.getString('devices_$uid') != null;
    final hasUserCalib = prefs.getInt('calibration_left_$uid') != null;

    // Gastdaten
    final guestDevices = prefs.getString('devices_guest');
    final guestLeft = prefs.getInt('calibration_left_guest');
    final guestRight = prefs.getInt('calibration_right_guest');

    // Geräte migrieren (nur wenn Nutzer noch keine hat)
    if (!hasUserDevices && guestDevices != null) {
      await prefs.setString('devices_$uid', guestDevices);
      logger.i('DeviceStorageService: Gastgeräte zu Nutzer $uid migriert');
    }

    // Kalibrierung migrieren (nur wenn Nutzer noch keine hat)
    if (!hasUserCalib && guestLeft != null && guestRight != null) {
      await prefs.setInt('calibration_left_$uid', guestLeft);
      await prefs.setInt('calibration_right_$uid', guestRight);
      logger.i('DeviceStorageService: Gastkalibrierung zu Nutzer $uid migriert');
    }
  }
}
