/// USER MODEL & CALIBRATION DATA STRUCTURE
///
/// This file defines how user data and device-specific calibrations are
/// structured in the app and synchronized with Firestore.
///
/// STRUCTURE:
/// 1. HeadphoneCalib: Holds audio-specific settings (volume, model ID).
/// 2. BeltCalib: Holds sensor-specific settings for the hardware belt
///    (warning distance, vibration strength and side).
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
/// - Signed-in users' devices ([DeviceData]) are stored in Firestore by
///   FirestoreDeviceRepository; a guest's are not stored at all, they live in
///   memory in GuestDeviceRepository until the guest signs in. The same
///   toMap()/fromMap() format is used for Firestore and for the local JSON
///   of DeviceStorageService (devices of app versions before the sync).
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

  /// Copy with the given volumes replaced; [isConnected] is kept.
  HeadphoneCalib copyWith({double? volumeLeft, double? volumeRight}) {
    return HeadphoneCalib(
      modelId: modelId,
      volumeLeft: volumeLeft ?? this.volumeLeft,
      volumeRight: volumeRight ?? this.volumeRight,
      isConnected: isConnected,
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

/// One of the belt's three vibration motors (front, left, right): the side the
/// belt vibrates on.
enum BeltSide {
  left('left'),
  front('front'),
  right('right');

  const BeltSide(this.firestoreValue);

  /// Value stored in Firestore (`vibrationSide`).
  final String firestoreValue;

  /// The side stored as [value]; anything unknown falls back to [front].
  static BeltSide fromFirestore(Object? value) => BeltSide.values.firstWhere(
    (side) => side.firestoreValue == value,
    orElse: () => BeltSide.front,
  );
}

/// Calibration data for the hardware belt
class BeltCalib {
  /// Default of [warningDistanceCm].
  static const int defaultWarningDistanceCm = 200;

  /// Default of [vibrationStrength].
  static const int defaultVibrationStrength = 100;

  /// Default of [vibrationSide].
  static const BeltSide defaultVibrationSide = BeltSide.front;

  /// Allowed range of [warningDistanceCm] in the belt setup (team decision).
  static const int minWarningDistanceCm = 50;
  static const int maxWarningDistanceCm = 500;

  /// Allowed range of [vibrationStrength] in the belt setup (team decision).
  static const int minVibrationStrength = 50;
  static const int maxVibrationStrength = 100;

  /// Model name of the device (Firestore: `modelId`).
  final String modelId;

  /// Distance in cm at which the belt starts to warn
  /// (Firestore: `warningDistanceCm`), default 200.
  final int warningDistanceCm;

  /// Vibration strength in percent, as typed in the belt setup
  /// (Firestore: `vibrationStrength`), default 100.
  final int vibrationStrength;

  /// Motor the belt vibrates with (Firestore: `vibrationSide`), default front.
  final BeltSide vibrationSide;

  // UI & Runtime helpers (Not stored in Firestore)

  /// Whether the device counts as connected. Runtime only, not persisted.
  bool isConnected;

  /// Category of every belt device.
  static const DeviceCategory category = DeviceCategory.belt;

  BeltCalib({
    required this.modelId,
    this.warningDistanceCm = defaultWarningDistanceCm,
    this.vibrationStrength = defaultVibrationStrength,
    this.vibrationSide = defaultVibrationSide,
    this.isConnected = false, // Defaults to disconnected on app start
  });

  /// Converts Firestore Map to Object. Missing fields and fields of the wrong
  /// type fall back to the defaults, so belts saved before these fields
  /// existed load with them.
  factory BeltCalib.fromMap(Map<String, dynamic> map) {
    final distance = map['warningDistanceCm'];
    final strength = map['vibrationStrength'];
    return BeltCalib(
      modelId: map['modelId'] is String ? map['modelId'] : 'unknown',
      warningDistanceCm:
          distance is num ? distance.round() : defaultWarningDistanceCm,
      vibrationStrength:
          strength is num ? strength.round() : defaultVibrationStrength,
      vibrationSide: BeltSide.fromFirestore(map['vibrationSide']),
      isConnected: false,
    );
  }

  /// Copy with the given values replaced; [isConnected] is kept.
  BeltCalib copyWith({
    int? warningDistanceCm,
    int? vibrationStrength,
    BeltSide? vibrationSide,
  }) {
    return BeltCalib(
      modelId: modelId,
      warningDistanceCm: warningDistanceCm ?? this.warningDistanceCm,
      vibrationStrength: vibrationStrength ?? this.vibrationStrength,
      vibrationSide: vibrationSide ?? this.vibrationSide,
      isConnected: isConnected,
    );
  }

  /// Converts Object to Map for Firestore.
  /// Note: isConnected and category are EXCLUDED from the map.
  Map<String, dynamic> toMap() => {
    'modelId': modelId,
    'warningDistanceCm': warningDistanceCm,
    'vibrationStrength': vibrationStrength,
    'vibrationSide': vibrationSide.firestoreValue,
  };
}

/// The devices of one user (or the guest): headphones and belts, each keyed by
/// BD_ADDR. Immutable; the `with…` / `without…` methods return a copy.
class DeviceData {
  final Map<String, HeadphoneCalib> headphones;
  final Map<String, BeltCalib> belts;

  const DeviceData({this.headphones = const {}, this.belts = const {}});

  /// Parses the `calibration` map (`{headphones: {...}, belts: {...}}`) of the
  /// Firestore document or of the local JSON. Anything that is not a map
  /// gives no devices; invalid entries are skipped (see [parseDeviceMap]).
  factory DeviceData.fromMap(Object? raw) {
    final map = raw is Map ? raw : const {};
    return DeviceData(
      headphones: parseDeviceMap(map['headphones'], HeadphoneCalib.fromMap),
      belts: parseDeviceMap(map['belts'], BeltCalib.fromMap),
    );
  }

  /// The same structure as the Firestore field `calibration`.
  Map<String, dynamic> toMap() => {
    'headphones': headphones.map((k, v) => MapEntry(k, v.toMap())),
    'belts': belts.map((k, v) => MapEntry(k, v.toMap())),
  };

  DeviceData withHeadphone(String key, HeadphoneCalib calib) =>
      DeviceData(headphones: {...headphones, key: calib}, belts: belts);

  DeviceData withoutHeadphone(String key) => DeviceData(
    headphones: Map.of(headphones)..remove(key),
    belts: belts,
  );

  DeviceData withBelt(String key, BeltCalib calib) =>
      DeviceData(headphones: headphones, belts: {...belts, key: calib});

  DeviceData withoutBelt(String key) => DeviceData(
    headphones: headphones,
    belts: Map.of(belts)..remove(key),
  );
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