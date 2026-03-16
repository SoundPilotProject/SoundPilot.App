// lib/core/services/calibration_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';

class CalibrationData {
  final int leftVolume;
  final int rightVolume;

  const CalibrationData({
    required this.leftVolume,
    required this.rightVolume,
  });

  const CalibrationData.defaults()
      : leftVolume = 50,
        rightVolume = 50;
}

class CalibrationService {
  static String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  static String get _leftKey => 'calibration_left_$_userId';
  static String get _rightKey => 'calibration_right_$_userId';

  static Future<void> save(CalibrationData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leftKey, data.leftVolume);
    await prefs.setInt(_rightKey, data.rightVolume);
    logger.i('CalibrationService: L=${data.leftVolume} R=${data.rightVolume} für $_userId gespeichert');
  }

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

  static Future<void> migrateLocalToFirestoreIfNeeded() async {
    // Stub – Firestore nicht verwendet auf Windows
  }
}