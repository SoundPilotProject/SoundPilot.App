// test/core/services/guest_mode_service_test.dart
//
// Tests that guest mode is not stored (every app start shows the
// StartScreen), that what older app versions stored for a guest is cleared,
// and that ending guest mode forgets the guest's devices.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundpilot_application/core/services/device_repository.dart';
import 'package:soundpilot_application/core/services/device_storage_service.dart';
import 'package:soundpilot_application/core/services/guest_mode_service.dart';
import 'package:soundpilot_application/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(GuestDeviceRepository.clear);

  test('guest mode is off without stored data', () async {
    SharedPreferences.setMockInitialValues({});

    await GuestModeService.load();

    expect(GuestModeService.active.value, isFalse);
  });

  test('guest mode does not survive an app restart', () async {
    SharedPreferences.setMockInitialValues({});

    await GuestModeService.set(true);
    expect(GuestModeService.active.value, isTrue);

    GuestModeService.active.value = false; // simulate an app restart
    await GuestModeService.load();

    expect(GuestModeService.active.value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('guestMode'), isFalse);
  });

  test('load removes what older app versions stored for a guest', () async {
    SharedPreferences.setMockInitialValues({
      'guestMode': true,
      'continueAsGuestThisSession': true,
    });
    await DeviceStorageService.save(
      DeviceStorageService.guestOwner,
      DeviceData(belts: {'bb': BeltCalib(modelId: 'Belt')}),
    );
    await DeviceStorageService.save(
      'user-1',
      DeviceData(belts: {'cc': BeltCalib(modelId: 'Own Belt')}),
    );

    await GuestModeService.load();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('guestMode'), isFalse);
    expect(prefs.containsKey('continueAsGuestThisSession'), isFalse);
    expect(GuestModeService.active.value, isFalse);
    final guest =
        await DeviceStorageService.load(DeviceStorageService.guestOwner);
    expect(guest.belts, isEmpty);
    // The devices of a signed-in user from before the Firestore sync are
    // none of its business; FirestoreDeviceRepository uploads those.
    final user = await DeviceStorageService.load('user-1');
    expect(user.belts.keys, ['cc']);
  });

  test("end turns guest mode off and forgets the guest's devices", () async {
    SharedPreferences.setMockInitialValues({});
    await GuestModeService.set(true);
    await GuestDeviceRepository().putBelt('bb', BeltCalib(modelId: 'Belt'));

    await GuestModeService.end();

    expect(GuestModeService.active.value, isFalse);
    expect(GuestDeviceRepository.devices.belts, isEmpty);
  });
}
