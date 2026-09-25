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

  /// Category label, also used as a string in the UI (compare 'Earbuds' in
  /// DeviceScreen).
  ///
  /// TODO(improve): Replace the string categories ('Earbuds' / 'Belt' here,
  /// 'Earbuds' / 'Gürtel' in DeviceScreen) with an enum, and make this a
  /// `static const` since it is the same for every instance.
  final String category = 'Earbuds';

  HeadphoneCalib({
    required this.modelId,
    this.volumeLeft = 0.5,
    this.volumeRight = 0.5,
    this.isConnected = false, // Defaults to disconnected on app start
  });

  /// Converts Firestore Map to Object.
  /// Note: isConnected is always initialized as false here.
  factory HeadphoneCalib.fromMap(Map<String, dynamic> map) {
    return HeadphoneCalib(
      modelId: map['modelId'] ?? 'unknown',
      volumeLeft: (map['volLeft'] ?? 0.5).toDouble(),
      volumeRight: (map['volRight'] ?? 0.5).toDouble(),
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

  /// Category label (see the TODO at [HeadphoneCalib.category]).
  final String category = 'Belt';

  BeltCalib({
    required this.modelId,
    this.isConnected = false, // Defaults to disconnected on app start
  });

  factory BeltCalib.fromMap(Map<String, dynamic> map) {
    return BeltCalib(
      modelId: map['modelId'] ?? 'unknown',
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
  /// TODO(improve): The fallbacks only cover missing keys. A device entry of
  /// the wrong type (`value as Map<String, dynamic>`) still throws.
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    final calib = data['calibration'] as Map<String, dynamic>? ?? {};

    // Parse Headphones Map
    final hpMap = calib['headphones'] as Map<String, dynamic>? ?? {};
    Map<String, HeadphoneCalib> parsedHeadphones = hpMap.map(
            (key, value) => MapEntry(key, HeadphoneCalib.fromMap(value as Map<String, dynamic>))
    );

    // Parse Belts Map
    final beltMap = calib['belts'] as Map<String, dynamic>? ?? {};
    Map<String, BeltCalib> parsedBelts = beltMap.map(
            (key, value) => MapEntry(key, BeltCalib.fromMap(value as Map<String, dynamic>))
    );

    return UserModel(
      id: id,
      displayName: data['displayName'] ?? defaultDisplayName,
      email: data['email'] ?? '',
      schemaVersion: (data['schemaVersion'] ?? 0) as int,
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