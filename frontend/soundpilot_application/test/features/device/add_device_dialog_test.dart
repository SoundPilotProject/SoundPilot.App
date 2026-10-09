// test/features/device/add_device_dialog_test.dart
//
// The headphone scan in the AddDeviceDialog with a fake scanner: found
// devices, already added ones, and the states Bluetooth off, permission
// missing, nothing found and error.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/features/device/widgets/add_device_dialog.dart';
import 'package:soundpilot_application/features/device/widgets/device_type.dart';

const _sony = ScannedDevice(
  name: 'Sony WH-1000XM5',
  address: 'AA:BB:CC:DD:EE:FF',
  isConnected: true,
);
const _bose = ScannedDevice(
  name: 'Bose QC45',
  address: '11:22:33:44:55:66',
  isConnected: false,
);

/// Opens the dialog with [scanner] and runs the headphone scan. Returns a
/// getter for the dialog's result.
Future<AddDeviceResult? Function()> _openAndScan(
  WidgetTester tester,
  ScanOutcome outcome, {
  Set<String> existingAddresses = const {},
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  AddDeviceResult? result;
  await tester.pumpWidget(MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<AddDeviceResult>(
              context: context,
              builder: (_) => AddDeviceDialog(
                scanner: (type) async => outcome,
                existingAddresses: existingAddresses,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kopfhörer suchen'));
  await tester.pumpAndSettle();
  return () => result;
}

// NOTE: The test font is much wider than Plus Jakarta Sans, so texts wrap
// more than on a phone and the settings buttons need scrolling into view.

void main() {
  final calls = <String>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.soundpilot/audio_devices'), (call) async {
      calls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.soundpilot/audio_devices'), null);
  });

  testWidgets('returns the address of the picked headphones', (tester) async {
    final result =
        await _openAndScan(tester, const ScanFound([_sony, _bose]));

    // The connection state is written out, not shown by colour alone.
    expect(find.text('Verbunden'), findsOneWidget);
    expect(find.text('Gekoppelt, nicht verbunden'), findsOneWidget);

    await tester.tap(find.text('Bose QC45'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();

    expect(result()!.type, DeviceType.earbuds);
    expect(result()!.name, 'Bose QC45');
    expect(result()!.address, '11:22:33:44:55:66');
  });

  testWidgets('already added headphones cannot be picked', (tester) async {
    final result = await _openAndScan(
      tester,
      const ScanFound([_sony]),
      existingAddresses: {'AA:BB:CC:DD:EE:FF'},
    );

    expect(find.text('Bereits hinzugefügt'), findsOneWidget);

    await tester.tap(find.text('Sony WH-1000XM5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();

    // Still open: the confirm button stayed disabled.
    expect(find.text('Gerät hinzufügen'), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('a typed-in name has no address', (tester) async {
    final result = await _openAndScan(tester, const ScanFound([]));

    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Meine Kopfhörer');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();

    expect(result()!.name, 'Meine Kopfhörer');
    expect(result()!.address, isNull);
  });

  testWidgets('Bluetooth off offers the Bluetooth settings', (tester) async {
    await _openAndScan(tester, const ScanBluetoothOff());

    expect(find.textContaining('Bluetooth ist ausgeschaltet'), findsOneWidget);
    await tester.ensureVisible(find.text('Bluetooth-Einstellungen öffnen'));
    await tester.tap(find.text('Bluetooth-Einstellungen öffnen'));
    await tester.pump();

    expect(calls, ['openBluetoothSettings']);
  });

  testWidgets('a denied permission asks to scan again, without a button',
      (tester) async {
    await _openAndScan(tester, const ScanPermissionMissing(permanently: false));

    expect(find.textContaining('„Geräte in der Nähe“'), findsOneWidget);
    expect(find.text('App-Einstellungen öffnen'), findsNothing);
  });

  testWidgets('a permanently denied permission offers the app settings',
      (tester) async {
    await _openAndScan(tester, const ScanPermissionMissing(permanently: true));

    expect(find.textContaining('ist abgelehnt'), findsOneWidget);
    await tester.ensureVisible(find.text('App-Einstellungen öffnen'));
    await tester.tap(find.text('App-Einstellungen öffnen'));
    await tester.pump();

    expect(calls, ['openAppSettings']);
  });

  testWidgets('no headphones found explains pairing', (tester) async {
    await _openAndScan(tester, const ScanFound([]));

    expect(find.textContaining('Kopple deine Kopfhörer'), findsOneWidget);
    expect(find.text('Bluetooth-Einstellungen öffnen'), findsOneWidget);
  });

  testWidgets('a failed scan says so', (tester) async {
    await _openAndScan(tester, const ScanFailed());

    expect(find.textContaining('hat nicht funktioniert'), findsOneWidget);
  });
}
