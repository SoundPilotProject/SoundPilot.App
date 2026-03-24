/// USER MODEL & CALIBRATION DATA STRUCTURE
///
/// This file defines how user data and device-specific calibrations are
/// structured in the app and synchronized with Firestore.
///
/// STRUCTURE:
/// 1. HeadphoneCalib: Holds audio-specific settings (volume, model ID).
/// 2. BeltCalib: Holds sensor-specific settings for the hardware belt.
/// 3. UserModel: The central profile that manages basic user info
///    and maps multiple devices by their unique BD_ADDR (Bluetooth Address).
///
/// DATA FLOW:
/// - From Firestore: factory UserModel.fromFirestore() converts raw database maps
///   into type-safe Dart objects.
/// - To Firestore: .toMap() methods convert objects back into maps for updates.
///
/// NOTE: Devices are stored in Maps using their Bluetooth MAC Address as the Key
/// to allow one user to have multiple calibrated devices of the same type.
library;

/// Calibration data for headphones
class HeadphoneCalib {
  final String modelId;
  final double volumeLeft;
  final double volumeRight;

  HeadphoneCalib({
    required this.modelId,
    this.volumeLeft = 0.5,
    this.volumeRight = 0.5,
  });

  factory HeadphoneCalib.fromMap(Map<String, dynamic> map) {
    return HeadphoneCalib(
      modelId: map['modelId'] ?? 'unknown',
      volumeLeft: (map['volLeft'] ?? 0.5).toDouble(),
      volumeRight: (map['volRight'] ?? 0.5).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'modelId': modelId,
    'volLeft': volumeLeft,
    'volRight': volumeRight,
  };
}

/// Placeholder for future belt calibration data
class BeltCalib {
  final String modelId;
  // Add more belt-specific fields here later

  BeltCalib({required this.modelId});

  factory BeltCalib.fromMap(Map<String, dynamic> map) {
    return BeltCalib(modelId: map['modelId'] ?? 'unknown');
  }

  Map<String, dynamic> toMap() => {'modelId': modelId};
}

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final Map<String, HeadphoneCalib> headphones; // Key: BD_ADDR
  final Map<String, BeltCalib> belts;           // Key: BD_ADDR

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.headphones = const {},
    this.belts = const {},
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    final calib = data['calibration'] as Map<String, dynamic>? ?? {};

    // Parse Headphones
    final hpMap = calib['headphones'] as Map<String, dynamic>? ?? {};
    Map<String, HeadphoneCalib> parsedHeadphones = hpMap.map(
            (key, value) => MapEntry(key, HeadphoneCalib.fromMap(value))
    );

    // Parse Belts
    final beltMap = calib['belts'] as Map<String, dynamic>? ?? {};
    Map<String, BeltCalib> parsedBelts = beltMap.map(
            (key, value) => MapEntry(key, BeltCalib.fromMap(value))
    );

    return UserModel(
      id: id,
      displayName: data['displayName'] ?? 'User',
      email: data['email'] ?? '',
      headphones: parsedHeadphones,
      belts: parsedBelts,
    );
  }
}