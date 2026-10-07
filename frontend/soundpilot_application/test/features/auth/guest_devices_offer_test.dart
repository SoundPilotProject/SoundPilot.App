// test/features/auth/guest_devices_offer_test.dart
//
// Tests the question after a sign-in on a phone with guest devices: take
// them over or delete them, and what happens if the take-over fails.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/core/services/device_storage_service.dart';
import 'package:soundpilot_application/features/auth/guest_devices_offer.dart';
import 'package:soundpilot_application/models/user_model.dart';

const _guest = DeviceStorageService.guestOwner;

final _guestDevices = DeviceData(
  headphones: {'aa': HeadphoneCalib(modelId: 'Pods')},
  belts: {'bb': BeltCalib(modelId: 'Gürtel 1')},
);

/// Shows a button that runs [offerGuestDevices] with [upload], like the
/// login screen after a successful sign-in.
Future<void> _pumpHost(WidgetTester tester, GuestDeviceUpload upload) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              offerGuestDevices(context, uid: 'user-1', upload: upload),
          child: const Text('signed in'),
        ),
      ),
    ),
  ));
}

/// Taps the host button and lets the dialog open.
Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.text('signed in'));
  await tester.pumpAndSettle();
}

Future<DeviceData> _storedGuestDevices() => DeviceStorageService.load(_guest);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('no guest devices: nothing is asked', (tester) async {
    var uploads = 0;
    await _pumpHost(tester, (_) async => uploads++);

    await _signIn(tester);

    expect(find.byType(GuestDevicesDialog), findsNothing);
    expect(uploads, 0);
  });

  testWidgets('"Geräte übernehmen" uploads them, then deletes them here',
      (tester) async {
    await DeviceStorageService.save(_guest, _guestDevices);
    final uploaded = <DeviceData>[];
    await _pumpHost(tester, (devices) async => uploaded.add(devices));

    await _signIn(tester);
    expect(find.text('Gast-Geräte übernehmen?'), findsOneWidget);
    expect(find.textContaining('2 Geräte gespeichert'), findsOneWidget);

    await tester.tap(find.text('Geräte übernehmen'));
    await tester.pumpAndSettle();

    expect(uploaded.single.headphones.keys, ['aa']);
    expect(uploaded.single.belts.keys, ['bb']);
    final left = await tester.runAsync(_storedGuestDevices);
    expect(left!.headphones, isEmpty);
    expect(left.belts, isEmpty);
  });

  testWidgets('"Geräte löschen" deletes them without uploading',
      (tester) async {
    await DeviceStorageService.save(_guest, _guestDevices);
    var uploads = 0;
    await _pumpHost(tester, (_) async => uploads++);

    await _signIn(tester);
    await tester.tap(find.text('Geräte löschen'));
    await tester.pumpAndSettle();

    expect(uploads, 0);
    final left = await tester.runAsync(_storedGuestDevices);
    expect(left!.headphones, isEmpty);
  });

  testWidgets('a failed take-over says so and keeps the devices here',
      (tester) async {
    await DeviceStorageService.save(_guest, _guestDevices);
    await _pumpHost(tester, (_) async => throw Exception('offline'));

    await _signIn(tester);
    await tester.tap(find.text('Geräte übernehmen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('konnten nicht übernommen werden'),
        findsOneWidget);
    expect(find.text('Geräte werden übernommen...'), findsNothing);
    final left = await tester.runAsync(_storedGuestDevices);
    expect(left!.headphones.keys, ['aa']);
  });

  testWidgets('a take-over that never finishes fails after the timeout',
      (tester) async {
    await DeviceStorageService.save(_guest, _guestDevices);
    // E.g. the cloud function never creates the user document.
    await _pumpHost(tester, (_) => Completer<void>().future);

    await _signIn(tester);
    await tester.tap(find.text('Geräte übernehmen'));
    // Dialog closing, then the loading screen opening (it spins forever, so
    // no pumpAndSettle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Geräte werden übernommen...'), findsOneWidget);

    await tester.pump(guestUploadTimeout + const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Geräte werden übernommen...'), findsNothing);
    expect(find.textContaining('konnten nicht übernommen werden'),
        findsOneWidget);
  });

  testWidgets('back and tapping outside do not close the question',
      (tester) async {
    await DeviceStorageService.save(_guest, _guestDevices);
    await _pumpHost(tester, (_) async {});

    await _signIn(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(GuestDevicesDialog), findsOneWidget);
  });

  testWidgets('one device is named in the singular', (tester) async {
    await DeviceStorageService.save(
      _guest,
      DeviceData(belts: {'bb': BeltCalib(modelId: 'Gürtel 1')}),
    );
    await _pumpHost(tester, (_) async {});

    await _signIn(tester);

    expect(find.textContaining('1 Gerät gespeichert'), findsOneWidget);
  });
}
