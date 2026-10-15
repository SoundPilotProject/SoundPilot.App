// test/core/services/guest_device_repository_test.dart
//
// Tests of GuestDeviceRepository: the guest's devices live in memory for one
// app run and nothing about them is written to the phone.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundpilot_application/core/services/device_repository.dart';
import 'package:soundpilot_application/core/services/device_storage_service.dart';
import 'package:soundpilot_application/models/user_model.dart';

/// Lets the stream deliver its events.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The state is static, so it outlives a single test.
    GuestDeviceRepository.clear();
  });

  test('a guest starts with no devices', () async {
    final seen = <DeviceData>[];
    GuestDeviceRepository().watch().listen(seen.add);
    await _settle();

    expect(seen.single.headphones, isEmpty);
    expect(seen.single.belts, isEmpty);
  });

  test('writes are delivered and seen by another instance', () async {
    final repository = GuestDeviceRepository();
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

    // AppEntryPoint builds a new instance on every rebuild; it shows the
    // same devices.
    expect(
      (await GuestDeviceRepository().watch().first).headphones.keys,
      ['aa'],
    );
  });

  test('nothing is written to the phone', () async {
    final repository = GuestDeviceRepository();
    await repository.putHeadphone('aa', HeadphoneCalib(modelId: 'Pods'));
    await repository.putBelt('bb', BeltCalib(modelId: 'Belt'));

    final stored =
        await DeviceStorageService.load(DeviceStorageService.guestOwner);
    expect(stored.headphones, isEmpty);
    expect(stored.belts, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });

  test('clear empties the devices and tells the watchers', () async {
    final repository = GuestDeviceRepository();
    final seen = <DeviceData>[];
    repository.watch().listen(seen.add);
    await repository.putHeadphone('aa', HeadphoneCalib(modelId: 'Pods'));
    await _settle();

    GuestDeviceRepository.clear();
    await _settle();

    expect(seen.last.headphones, isEmpty);
    expect(GuestDeviceRepository.devices.headphones, isEmpty);
  });
}
