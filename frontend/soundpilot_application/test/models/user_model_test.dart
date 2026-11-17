// test/models/user_model_test.dart
//
// Tests for the defensive parsing and the Dart <-> Firestore field mapping of
// HeadphoneCalib, BeltCalib and UserModel.

import 'package:flutter_test/flutter_test.dart';
import 'package:soundpilot_application/models/user_model.dart';

void main() {
  // ── HeadphoneCalib ─────────────────────────────────────────────────────────

  group('HeadphoneCalib', () {
    test('maps volLeft/volRight to volumeLeft/volumeRight and back', () {
      final calib = HeadphoneCalib.fromMap(
        {'modelId': 'Pods', 'volLeft': 0.7, 'volRight': 0.3},
      );

      expect(calib.modelId, 'Pods');
      expect(calib.volumeLeft, 0.7);
      expect(calib.volumeRight, 0.3);
      expect(calib.toMap(), {'modelId': 'Pods', 'volLeft': 0.7, 'volRight': 0.3});
    });

    test('missing fields fall back to defaults', () {
      final calib = HeadphoneCalib.fromMap({});

      expect(calib.modelId, 'unknown');
      expect(calib.volumeLeft, 0.5);
      expect(calib.volumeRight, 0.5);
      expect(calib.isConnected, isFalse);
    });

    test('fields of the wrong type fall back to defaults', () {
      final calib = HeadphoneCalib.fromMap(
        {'modelId': 42, 'volLeft': 'loud', 'volRight': null},
      );

      expect(calib.modelId, 'unknown');
      expect(calib.volumeLeft, 0.5);
      expect(calib.volumeRight, 0.5);
    });

    test('int volumes are converted to double', () {
      final calib = HeadphoneCalib.fromMap({'volLeft': 1, 'volRight': 0});

      expect(calib.volumeLeft, 1.0);
      expect(calib.volumeRight, 0.0);
    });

    test('toMap does not write runtime fields', () {
      final map = HeadphoneCalib(modelId: 'Pods', isConnected: true).toMap();

      expect(map.keys, unorderedEquals(['modelId', 'volLeft', 'volRight']));
    });

    test('copyWith replaces only the given volumes and keeps isConnected', () {
      final calib = HeadphoneCalib(
        modelId: 'Pods',
        volumeLeft: 0.2,
        volumeRight: 0.8,
        isConnected: true,
      ).copyWith(volumeLeft: 0.6);

      expect(calib.modelId, 'Pods');
      expect(calib.volumeLeft, 0.6);
      expect(calib.volumeRight, 0.8);
      expect(calib.isConnected, isTrue);
    });
  });

  // ── BeltCalib ──────────────────────────────────────────────────────────────

  group('BeltCalib', () {
    const stored = {
      'modelId': 'Belt 1',
      'warningDistanceCm': 350,
      'vibrationStrength': 70,
      'vibrationSide': 'left',
    };

    test('reads all fields and writes them back', () {
      final calib = BeltCalib.fromMap(stored);

      expect(calib.modelId, 'Belt 1');
      expect(calib.warningDistanceCm, 350);
      expect(calib.vibrationStrength, 70);
      expect(calib.vibrationSide, BeltSide.left);
      expect(calib.toMap(), stored);
    });

    test('a belt saved with only modelId gets the defaults', () {
      final calib = BeltCalib.fromMap({'modelId': 'Belt 1'});

      expect(calib.modelId, 'Belt 1');
      expect(calib.warningDistanceCm, 200);
      expect(calib.vibrationStrength, 100);
      expect(calib.vibrationSide, BeltSide.front);
      expect(calib.isConnected, isFalse);
    });

    test('fields of the wrong type fall back to defaults', () {
      final calib = BeltCalib.fromMap({
        'modelId': true,
        'warningDistanceCm': 'far',
        'vibrationStrength': null,
        'vibrationSide': 'up',
      });

      expect(calib.modelId, 'unknown');
      expect(calib.warningDistanceCm, BeltCalib.defaultWarningDistanceCm);
      expect(calib.vibrationStrength, BeltCalib.defaultVibrationStrength);
      expect(calib.vibrationSide, BeltCalib.defaultVibrationSide);
    });

    test('double numbers are rounded to int', () {
      final calib = BeltCalib.fromMap(
        {'warningDistanceCm': 249.6, 'vibrationStrength': 80.0},
      );

      expect(calib.warningDistanceCm, 250);
      expect(calib.vibrationStrength, 80);
    });

    test('every side is stored as its own value', () {
      for (final side in BeltSide.values) {
        final map = BeltCalib(modelId: 'B', vibrationSide: side).toMap();
        expect(BeltCalib.fromMap(map).vibrationSide, side);
      }
      expect(
        BeltSide.values.map((s) => s.firestoreValue),
        ['left', 'front', 'right'],
      );
    });

    test('toMap does not write runtime fields', () {
      final map = BeltCalib(modelId: 'Belt', isConnected: true).toMap();

      expect(
        map.keys,
        unorderedEquals([
          'modelId',
          'warningDistanceCm',
          'vibrationStrength',
          'vibrationSide',
        ]),
      );
    });

    test('copyWith replaces only the given values and keeps isConnected', () {
      final calib = BeltCalib(
        modelId: 'Belt',
        warningDistanceCm: 300,
        vibrationStrength: 60,
        isConnected: true,
      ).copyWith(vibrationSide: BeltSide.right);

      expect(calib.modelId, 'Belt');
      expect(calib.warningDistanceCm, 300);
      expect(calib.vibrationStrength, 60);
      expect(calib.vibrationSide, BeltSide.right);
      expect(calib.isConnected, isTrue);
    });
  });

  // ── parseDeviceMap ─────────────────────────────────────────────────────────

  group('parseDeviceMap', () {
    test('skips invalid entries and keeps the valid ones', () {
      final parsed = parseDeviceMap(
        {
          'AA:BB': {'modelId': 'Pods'},
          'CC:DD': 'not a map',
          'EE:FF': null,
        },
        HeadphoneCalib.fromMap,
      );

      expect(parsed.keys, ['AA:BB']);
      expect(parsed['AA:BB']!.modelId, 'Pods');
    });

    test('a value that is not a map gives an empty map', () {
      expect(parseDeviceMap(null, BeltCalib.fromMap), isEmpty);
      expect(parseDeviceMap(['a', 'b'], BeltCalib.fromMap), isEmpty);
    });
  });

  // ── DeviceData ─────────────────────────────────────────────────────────────

  group('DeviceData', () {
    test('reads and writes the calibration map format', () {
      final map = {
        'headphones': {
          'aa': {'modelId': 'Pods', 'volLeft': 0.3, 'volRight': 0.7},
        },
        'belts': {
          'bb': {
            'modelId': 'Belt',
            'warningDistanceCm': 300,
            'vibrationStrength': 80,
            'vibrationSide': 'right',
          },
        },
      };

      expect(DeviceData.fromMap(map).toMap(), map);
    });

    test('anything that is not a map gives no devices', () {
      final data = DeviceData.fromMap('broken');

      expect(data.headphones, isEmpty);
      expect(data.belts, isEmpty);
    });

    test('with/without return a changed copy and keep the original', () {
      final original = DeviceData(belts: {'bb': BeltCalib(modelId: 'Belt')});

      final changed = original
          .withHeadphone('aa', HeadphoneCalib(modelId: 'Pods'))
          .withoutBelt('bb');

      expect(changed.headphones.keys, ['aa']);
      expect(changed.belts, isEmpty);
      expect(original.headphones, isEmpty);
      expect(original.belts.keys, ['bb']);
      expect(changed.withoutHeadphone('aa').headphones, isEmpty);
      expect(
        changed.withBelt('cc', BeltCalib(modelId: 'B2')).belts.keys,
        ['cc'],
      );
    });
  });

  // ── UserModel ──────────────────────────────────────────────────────────────

  group('UserModel.fromFirestore', () {
    test('reads the document created by createUserDoc', () {
      final user = UserModel.fromFirestore({
        'displayName': 'Anna',
        'email': 'anna@example.com',
        'schemaVersion': 1,
        'calibration': {
          'headphones': {
            'AA:BB': {'modelId': 'Pods', 'volLeft': 0.6, 'volRight': 0.4},
          },
          'belts': {
            'CC:DD': {'modelId': 'Belt 1'},
          },
        },
      }, 'uid-1');

      expect(user.id, 'uid-1');
      expect(user.displayName, 'Anna');
      expect(user.email, 'anna@example.com');
      expect(user.schemaVersion, 1);
      expect(user.headphones['AA:BB']!.volumeLeft, 0.6);
      expect(user.belts['CC:DD']!.modelId, 'Belt 1');
    });

    test('an empty document falls back to defaults', () {
      final user = UserModel.fromFirestore({}, 'uid-1');

      expect(user.displayName, UserModel.defaultDisplayName);
      expect(user.email, '');
      expect(user.schemaVersion, 0);
      expect(user.headphones, isEmpty);
      expect(user.belts, isEmpty);
    });

    test('does not throw on fields and entries of the wrong type', () {
      final user = UserModel.fromFirestore({
        'displayName': 7,
        'schemaVersion': 1.0,
        'calibration': {
          'headphones': {
            'AA:BB': {'modelId': 'Pods'},
            'CC:DD': 'broken',
          },
          'belts': 'broken',
        },
      }, 'uid-1');

      expect(user.displayName, UserModel.defaultDisplayName);
      expect(user.schemaVersion, 1);
      expect(user.headphones.keys, ['AA:BB']);
      expect(user.belts, isEmpty);
    });

    test('a calibration field that is not a map gives no devices', () {
      final user = UserModel.fromFirestore({'calibration': 'broken'}, 'uid-1');

      expect(user.headphones, isEmpty);
      expect(user.belts, isEmpty);
    });
  });

  // ── DeviceCategory ─────────────────────────────────────────────────────────

  test('DeviceCategory labels and model categories', () {
    expect(DeviceCategory.earbuds.label, 'Earbuds');
    expect(DeviceCategory.belt.label, 'Gürtel');
    expect(HeadphoneCalib.category, DeviceCategory.earbuds);
    expect(BeltCalib.category, DeviceCategory.belt);
  });
}
