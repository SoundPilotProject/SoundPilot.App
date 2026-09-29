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
/// NOTE:
/// - Devices are stored in Maps using their Bluetooth MAC Address as the Key.
/// - 'isConnected' is a RUNTIME property and is NOT persisted in the database.
///
/// CURRENT STATE:
/// - The app does not read or write Firestore yet. These models are persisted
///   locally as JSON by DeviceStorageService (SharedPreferences), using the
///   same toMap()/fromMap() format that is planned for Firestore.
/// - Firestore field names: `volLeft`/`volRight` (Dart: volumeLeft/volumeRight).
library;

import '../core/app_logger.dart';

/// Kind of device. Runtime only, not persisted.
enum DeviceCategory {
  earbuds('Earbuds'),
  belt('Gürtel');

  const DeviceCategory(this.label);

  /// German label shown in the UI.
  final String label;
}

/// Parses a stored device map (`calibration.headphones` or
/// `calibration.belts`, key = BD_ADDR) with [fromMap].
///
/// Entries that are not maps are skipped and logged instead of throwing, so
/// one broken entry does not lose all other devices. A [raw] value that is not
/// a map gives an empty map.
Map<String, T> parseDeviceMap<T>(
  Object? raw,
  T Function(Map<String, dynamic>) fromMap,
) {
  if (raw is! Map) return {};
  final result = <String, T>{};
  raw.forEach((key, value) {
    if (key is String && value is Map) {
      result[key] = fromMap(Map<String, dynamic>.from(value));
    } else {
      logger.w('parseDeviceMap: Skipping invalid device entry "$key"');
    }
  });
  return result;
}

/// Calibration data for headphones
///
/// TODO(improve): The calibration flow never sets [volumeLeft]/[volumeRight]
/// (see CalibrationService), so they always keep their default of 0.5.
class HeadphoneCalib {
  /// Model name of the device (Firestore: `modelId`).
  final String modelId;

  /// Volume of the left side (Firestore: `volLeft`), default 0.5.
  final double volumeLeft;

  /// Volume of the right side (Firestore: `volRight`), default 0.5.
  final double volumeRight;

  // UI & Runtime helpers (Not stored in Firestore)

  /// Whether the device counts as connected. Runtime only, not persisted.
  bool isConnected;

  /// Category of every headphone device.
  static const DeviceCategory category = DeviceCategory.earbuds;

  HeadphoneCalib({
    required this.modelId,
    this.volumeLeft = 0.5,
    this.volumeRight = 0.5,
    this.isConnected = false, // Defaults to disconnected on app start
  });

  /// Converts Firestore Map to Object.
  /// Note: isConnected is always initialized as false here.
  factory HeadphoneCalib.fromMap(Map<String, dynamic> map) {
    // Fields of the wrong type fall back to the defaults as well.
    final volLeft = map['volLeft'];
    final volRight = map['volRight'];
    return HeadphoneCalib(
      modelId: map['modelId'] is String ? map['modelId'] : 'unknown',
      volumeLeft: volLeft is num ? volLeft.toDouble() : 0.5,
      volumeRight: volRight is num ? volRight.toDouble() : 0.5,
      isConnected: false,
    );
  }

  /// Converts Object to Map for Firestore.
  /// Note: isConnected and category are EXCLUDED from the map.
  Map<String, dynamic> toMap() => {
    'modelId': modelId,
    'volLeft': volumeLeft,
    'volRight': volumeRight,
  };
}

/// Calibration data for the hardware belt
class BeltCalib {
  /// Model name of the device (Firestore: `modelId`).
  final String modelId;

  // UI & Runtime helpers (Not stored in Firestore)

  /// Whether the device counts as connected. Runtime only, not persisted.
  bool isConnected;

  /// Category of every belt device.
  static const DeviceCategory category = DeviceCategory.belt;

  BeltCalib({
    required this.modelId,
    this.isConnected = false, // Defaults to disconnected on app start
  });

  factory BeltCalib.fromMap(Map<String, dynamic> map) {
    return BeltCalib(
      modelId: map['modelId'] is String ? map['modelId'] : 'unknown',
      isConnected: false,
    );
  }

  /// Only saves the modelId to Firestore
  Map<String, dynamic> toMap() => {
    'modelId': modelId,
  };
}

/// The user profile: basic info plus all calibrated devices.
///
/// Corresponds to the Firestore document `users/{uid}` (the cloud function
/// `createUserDoc` creates it with `displayName`, `email` and empty maps).
class UserModel {
  /// Schema version this app version expects in `users/{uid}`
  /// (Firestore: `schemaVersion`). Keep it in sync with `SCHEMA_VERSION` in
  /// the cloud function `createUserDoc`.
  static const int currentSchemaVersion = 1;

  /// Display name used when the account has none. Keep it in sync with the
  /// default in the cloud function `createUserDoc` ('New User').
  static const String defaultDisplayName = 'New User';

  /// Firebase Auth UID (= Firestore document id).
  final String id;

  /// Schema version of the loaded document (Firestore: `schemaVersion`).
  /// 0 means the field is missing, i.e. a document created before versioning.
  ///
  /// NOTE: Read-only. It is not written by [toMap]; only the cloud function
  /// sets it, and the security rules block client writes to it.
  final int schemaVersion;

  /// Display name. Not `username`: the cloud function, this model and
  /// AuthService all use `displayName`.
  final String displayName;

  /// E-mail address of the account.
  final String email;

  final Map<String, HeadphoneCalib> headphones; // Key: BD_ADDR (MAC Address)
  final Map<String, BeltCalib> belts;           // Key: BD_ADDR (MAC Address)

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.schemaVersion = 0,
    this.headphones = const {},
    this.belts = const {},
  });

  /// Builds a [UserModel] from a Firestore document map.
  ///
  /// Missing fields fall back to defaults. Note that the cloud function uses
  /// 'New User' as the default display name, this factory uses
  /// [defaultDisplayName] (the same value).
  ///
  /// Fields of the wrong type fall back to the defaults too, and invalid
  /// device entries are skipped (see [parseDeviceMap]).
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    final calib = data['calibration'];
    final calibMap = calib is Map ? calib : const {};

    // Parse Headphones Map
    final parsedHeadphones =
        parseDeviceMap(calibMap['headphones'], HeadphoneCalib.fromMap);

    // Parse Belts Map
    final parsedBelts = parseDeviceMap(calibMap['belts'], BeltCalib.fromMap);

    final displayName = data['displayName'];
    final email = data['email'];
    final schemaVersion = data['schemaVersion'];
    return UserModel(
      id: id,
      displayName: displayName is String ? displayName : defaultDisplayName,
      email: email is String ? email : '',
      schemaVersion: schemaVersion is num ? schemaVersion.toInt() : 0,
      headphones: parsedHeadphones,
      belts: parsedBelts,
    );
  }

  /// Helper to convert the whole user back to a Firestore-compatible map
  ///
  /// NOTE: With the current security rules a client may only update
  /// `calibration` and `settings`. Writing this whole map (it contains
  /// `displayName` and `email`) would be rejected. Update single field paths
  /// instead, see docs/PROJECT_CONTEXT.md §4.
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'calibration': {
        'headphones': headphones.map((k, v) => MapEntry(k, v.toMap())),
        'belts': belts.map((k, v) => MapEntry(k, v.toMap())),
      },
    };
  }
}