// lib/core/services/calibration_service.dart
//
// Local persistence of the left/right volume calibration (SharedPreferences).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';

/// Left/right volume of a calibration as whole numbers.
///
/// The calibration screen offers the values 1–100.
class CalibrationData {
  /// Volume of the left side.
  final int leftVolume;

  /// Volume of the right side.
  final int rightVolume;

  const CalibrationData({
    required this.leftVolume,
    required this.rightVolume,
  });

  /// Default calibration: 50 on both sides.
  const CalibrationData.defaults()
      : leftVolume = 50,
        rightVolume = 50;
}

/// Saves and loads the volume calibration in SharedPreferences.
///
/// Keys are `calibration_left_<userId>` and `calibration_right_<userId>`; guests
/// use the suffix `guest`.
///
/// TODO(improve): The values are stored per user, not per device, so every
/// earbud shares one calibration. The per-device values in
/// [HeadphoneCalib.volumeLeft]/[HeadphoneCalib.volumeRight] (double, stored by
/// DeviceStorageService) are never filled by the calibration flow. There are
/// two parallel stores with different types (int here, double in the model);
/// they should be merged into the device map keyed by BD_ADDR.
class CalibrationService {
  /// Current Firebase user id, or 'guest' if nobody is signed in.
  static String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  static String get _leftKey => 'calibration_left_$_userId';
  static String get _rightKey => 'calibration_right_$_userId';

  /// Stores [data] locally for the current user (or guest).
  static Future<void> save(CalibrationData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leftKey, data.leftVolume);
    await prefs.setInt(_rightKey, data.rightVolume);
    logger.i('CalibrationService: L=${data.leftVolume} R=${data.rightVolume} für $_userId gespeichert');
  }

  /// Loads the saved calibration, or [CalibrationData.defaults] if nothing (or
  /// only one of the two values) has been saved yet.
  static Future<CalibrationData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final left = prefs.getInt(_leftKey);
    final right = prefs.getInt(_rightKey);

    if (left != null && right != null) {
      logger.i('CalibrationService: L=$left R=$right für $_userId geladen');
      return CalibrationData(leftVolume: left, rightVolume: right);
    }

    logger.i('CalibrationService: keine Daten für $_userId, nutze Standard');
    return const CalibrationData.defaults();
  }

  /// Planned upload of the local calibration to Firestore.
  ///
  /// Currently a stub – Firestore is not used on Windows.
  ///
  /// TODO(improve): Implement the Firestore sync with field-path updates
  /// (`calibration.headphones.<BD_ADDR>.volLeft`, see docs/PROJECT_CONTEXT.md).
  static Future<void> migrateLocalToFirestoreIfNeeded() async {
    // Stub – Firestore is not used on Windows.
  }
}
