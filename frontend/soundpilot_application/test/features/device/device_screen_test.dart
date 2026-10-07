// test/features/device/device_screen_test.dart
//
// Tests that the DeviceScreen shows what its repository delivers, writes
// single devices to it and tells the user when loading or saving fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/features/device/screens/device_screen.dart';
import 'package:soundpilot_application/models/user_model.dart';

import '../../helpers/fake_device_repository.dart';

final _devices = DeviceData(
  headphones: {'aa': HeadphoneCalib(modelId: 'Pods')},
  belts: {'bb': BeltCalib(modelId: 'Gürtel 1')},
);

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeDeviceRepository repository, {
  bool isSignedIn = true,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: DeviceScreen(repository: repository, isSignedIn: isSignedIn),
  ));
}

void main() {
  testWidgets('shows a loading screen until the devices arrive',
      (tester) async {
    final repository = FakeDeviceRepository();
    await _pumpScreen(tester, repository);

    expect(find.text('Geräte werden geladen...'), findsOneWidget);

    repository.devices.add(_devices);
    await tester.pump();

    expect(find.text('Pods'), findsOneWidget);
    expect(find.text('Gürtel 1'), findsOneWidget);
  });

  testWidgets('follows every update of the repository', (tester) async {
    final repository = FakeDeviceRepository();
    await _pumpScreen(tester, repository);
    repository.devices.add(_devices);
    await tester.pump();

    // E.g. changed on another phone.
    repository.devices.add(_devices.withoutHeadphone('aa'));
    await tester.pump();

    expect(find.text('Pods'), findsNothing);
    expect(find.text('Gürtel 1'), findsOneWidget);
  });

  testWidgets('removing a device removes only that one in the repository',
      (tester) async {
    final repository = FakeDeviceRepository();
    await _pumpScreen(tester, repository);
    repository.devices.add(_devices);
    await tester.pump();

    await tester.tap(find.byTooltip('Gürtel 1 entfernen'));
    await tester.pump();

    expect(repository.writes, ['removeBelt bb']);
  });

  testWidgets('a failed save is reported with text', (tester) async {
    final repository = FakeDeviceRepository()..writeError = Exception('denied');
    await _pumpScreen(tester, repository);
    repository.devices.add(_devices);
    await tester.pump();

    await tester.tap(find.byTooltip('Pods entfernen'));
    await tester.pump();

    expect(
      find.textContaining('konnte nicht gespeichert werden'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load is reported instead of loading forever',
      (tester) async {
    final repository = FakeDeviceRepository();
    await _pumpScreen(tester, repository);

    repository.devices.addError(Exception('permission-denied'));
    await tester.pump();

    expect(find.text('Geräte werden geladen...'), findsNothing);
    expect(
      find.textContaining('konnten nicht geladen werden'),
      findsOneWidget,
    );
  });

  testWidgets('guests see login and registration, users the logout',
      (tester) async {
    final repository = FakeDeviceRepository();
    await _pumpScreen(tester, repository, isSignedIn: false);
    repository.devices.add(const DeviceData());
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Registrieren'), findsOneWidget);
    expect(find.text('Abmelden'), findsNothing);
  });

  testWidgets('the repository is released with the screen', (tester) async {
    final repository = FakeDeviceRepository();
    await _pumpScreen(tester, repository);

    await tester.pumpWidget(const SizedBox());

    expect(repository.disposed, isTrue);
  });

  testWidgets('a rebuild with a new repository keeps the first one',
      (tester) async {
    // AppEntryPoint builds a new repository on every rebuild.
    final first = FakeDeviceRepository();
    final second = FakeDeviceRepository();
    await _pumpScreen(tester, first);
    await _pumpScreen(tester, second);
    first.devices.add(_devices);
    await tester.pump();

    await tester.tap(find.byTooltip('Pods entfernen'));
    await tester.pumpWidget(const SizedBox());

    expect(first.writes, ['removeHeadphone aa']);
    expect(first.disposed, isTrue);
    expect(second.writes, isEmpty);
  });
}
