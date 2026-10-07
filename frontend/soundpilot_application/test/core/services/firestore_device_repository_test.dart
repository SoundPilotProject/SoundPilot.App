// test/core/services/firestore_device_repository_test.dart
//
// Tests of FirestoreDeviceRepository against an in-memory Firestore: reading
// through the snapshot listener, one write per device, waiting for a document
// the cloud function creates late, and the one-off upload of local devices.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundpilot_application/core/services/device_storage_service.dart';
import 'package:soundpilot_application/core/services/firestore_device_repository.dart';
import 'package:soundpilot_application/models/user_model.dart';

const _uid = 'user-1';

/// The user document as `createUserDoc` writes it, with [calibration].
Map<String, dynamic> _userDoc(Map<String, dynamic> calibration) => {
  'uid': _uid,
  'displayName': 'Max',
  'schemaVersion': 1,
  'calibration': calibration,
};

/// Lets the snapshot listener and the writes run.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreDeviceRepository repository;
  late List<DeviceData> seen;

  Future<Map<String, dynamic>?> calibration() async =>
      (await db.collection('users').doc(_uid).get()).data()?['calibration']
          as Map<String, dynamic>?;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    repository = FirestoreDeviceRepository(uid: _uid, firestore: db);
    seen = [];
  });

  /// Creates the user document, then starts listening.
  Future<void> startWith(Map<String, dynamic> calibration) async {
    await db.collection('users').doc(_uid).set(_userDoc(calibration));
    repository.watch().listen(seen.add);
    await _settle();
  }

  test('delivers the devices of the user document', () async {
    await startWith({
      'headphones': {'aa': {'modelId': 'Pods', 'volLeft': 0.3, 'volRight': 0.7}},
      'belts': {'bb': {'modelId': 'Belt'}},
    });

    expect(seen.last.headphones['aa']!.volumeLeft, 0.3);
    expect(seen.last.belts['bb']!.modelId, 'Belt');
  });

  test('a write changes only its own device', () async {
    await startWith({
      'headphones': {
        'aa': {'modelId': 'Pods', 'volLeft': 0.3, 'volRight': 0.7},
        'cc': {'modelId': 'Other', 'volLeft': 0.1, 'volRight': 0.2},
      },
      'belts': <String, dynamic>{},
    });

    await repository.putHeadphone(
      'aa',
      HeadphoneCalib(modelId: 'Pods', volumeLeft: 0.9, volumeRight: 0.8),
    );
    await _settle();

    final stored = await calibration();
    expect(stored!['headphones']['aa'],
        {'modelId': 'Pods', 'volLeft': 0.9, 'volRight': 0.8});
    expect(stored['headphones']['cc'],
        {'modelId': 'Other', 'volLeft': 0.1, 'volRight': 0.2});
    expect(seen.last.headphones['aa']!.volumeLeft, 0.9);
  });

  test('removing a device deletes only that device', () async {
    await startWith({
      'headphones': {'aa': {'modelId': 'Pods'}},
      'belts': {'bb': {'modelId': 'Belt'}, 'dd': {'modelId': 'Belt 2'}},
    });

    await repository.removeBelt('bb');
    await _settle();

    final stored = await calibration();
    expect((stored!['belts'] as Map).keys, ['dd']);
    expect((stored['headphones'] as Map).keys, ['aa']);
    expect(seen.last.belts.keys, ['dd']);
  });

  test('a write waits until the cloud function created the document',
      () async {
    // Right after registration: the document does not exist yet.
    repository.watch().listen(seen.add);
    var written = false;
    final write = repository
        .putBelt('bb', BeltCalib(modelId: 'Belt'))
        .then((_) => written = true);
    await _settle();
    expect(written, isFalse);

    // The cloud function writes the default document.
    await db.collection('users').doc(_uid).set(
        _userDoc({'headphones': <String, dynamic>{}, 'belts': <String, dynamic>{}}));
    await write;

    expect((await calibration())!['belts']['bb'], {'modelId': 'Belt'});
  });

  test('uploads local devices once, keeps the account ones, clears local',
      () async {
    await DeviceStorageService.save(
      DeviceStorageService.guestOwner,
      DeviceData(headphones: {
        'aa': HeadphoneCalib(modelId: 'Guest Pods', volumeLeft: 0.1),
        'ee': HeadphoneCalib(modelId: 'New Pods', volumeLeft: 0.4),
      }),
    );
    await DeviceStorageService.save(
      _uid,
      DeviceData(belts: {'bb': BeltCalib(modelId: 'Old Belt')}),
    );

    await startWith({
      'headphones': {'aa': {'modelId': 'Cloud Pods', 'volLeft': 0.9}},
      'belts': <String, dynamic>{},
    });
    await _settle();

    final stored = await calibration();
    // Already in the account: the cloud version wins.
    expect(stored!['headphones']['aa']['modelId'], 'Cloud Pods');
    // Only local before: uploaded.
    expect(stored['headphones']['ee']['volLeft'], 0.4);
    expect(stored['belts']['bb'], {'modelId': 'Old Belt'});
    // And removed locally, so the next account on this phone does not get it.
    final guest = await DeviceStorageService.load(DeviceStorageService.guestOwner);
    final user = await DeviceStorageService.load(_uid);
    expect(guest.headphones, isEmpty);
    expect(user.belts, isEmpty);
  });
}
