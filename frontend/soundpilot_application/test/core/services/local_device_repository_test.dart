// test/core/services/local_device_repository_test.dart
//
// Tests of LocalDeviceRepository (the guest's devices in SharedPreferences).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundpilot_application/core/services/device_repository.dart';
import 'package:soundpilot_application/core/services/device_storage_service.dart';
import 'package:soundpilot_application/models/user_model.dart';

/// Lets the stream deliver its events.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('delivers the stored devices first', () async {
    await DeviceStorageService.save(
      DeviceStorageService.guestOwner,
      DeviceData(belts: {'bb': BeltCalib(modelId: 'Belt')}),
    );

    final seen = <DeviceData>[];
    LocalDeviceRepository().watch().listen(seen.add);
    await _settle();

    expect(seen.single.belts.keys, ['bb']);
  });

  test('writes are delivered and survive a new repository', () async {
    final repository = LocalDeviceRepository();
    final seen = <DeviceData>[];
    repository.watch().listen(seen.add);
    await _settle();

    await repository.putHeadphone(
      'aa',
      HeadphoneCalib(modelId: 'Pods', volumeLeft: 0.3),
    );
    await repository.putBelt('bb', BeltCalib(modelId: 'Belt'));
    await repository.removeBelt('bb');
    await _settle();

    expect(seen.last.headphones['aa']!.volumeLeft, 0.3);
    expect(seen.last.belts, isEmpty);

    // A new repository (e.g. after an app restart) reads the same state.
    final reloaded = await LocalDeviceRepository().watch().first;
    expect(reloaded.headphones.keys, ['aa']);
    expect(reloaded.belts, isEmpty);
  });

  test('a write before the first load keeps the stored devices', () async {
    await DeviceStorageService.save(
      DeviceStorageService.guestOwner,
      DeviceData(belts: {'bb': BeltCalib(modelId: 'Belt')}),
    );

    final repository = LocalDeviceRepository();
    await repository.putHeadphone('aa', HeadphoneCalib(modelId: 'Pods'));

    final data = await repository.watch().first;
    expect(data.headphones.keys, ['aa']);
    expect(data.belts.keys, ['bb']);
  });
}
