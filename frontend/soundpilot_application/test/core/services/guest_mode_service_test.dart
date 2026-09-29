// test/core/services/guest_mode_service_test.dart
//
// Tests that guest mode is stored and survives an app restart.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundpilot_application/core/services/guest_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guest mode is off without stored data', () async {
    SharedPreferences.setMockInitialValues({});

    await GuestModeService.load();

    expect(GuestModeService.active.value, isFalse);
  });

  test('set stores the value, load reads it back', () async {
    SharedPreferences.setMockInitialValues({});

    await GuestModeService.set(true);
    GuestModeService.active.value = false; // simulate an app restart
    await GuestModeService.load();

    expect(GuestModeService.active.value, isTrue);

    await GuestModeService.set(false);
    await GuestModeService.load();

    expect(GuestModeService.active.value, isFalse);
  });

  test('load removes the old read-once flag', () async {
    SharedPreferences.setMockInitialValues({'continueAsGuestThisSession': true});

    await GuestModeService.load();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('continueAsGuestThisSession'), isFalse);
    expect(GuestModeService.active.value, isFalse);
  });
}
