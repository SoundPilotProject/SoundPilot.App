// test/features/device/device_screen_test.dart
//
// Tests that the DeviceScreen shows what its repository delivers, writes
// single devices to it and tells the user when loading or saving fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/features/device/screens/device_screen.dart';
import 'package:soundpilot_application/models/user_model.dart';

import '../../helpers/fake_auth_service.dart';
import '../../helpers/fake_device_repository.dart';

final _devices = DeviceData(
  headphones: {'aa': HeadphoneCalib(modelId: 'Pods')},
  belts: {'bb': BeltCalib(modelId: 'Gürtel 1')},
);

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeDeviceRepository repository, {
  bool isSignedIn = true,
  FakeAuthService? authService,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: DeviceScreen(
      repository: repository,
      isSignedIn: isSignedIn,
      authService: authService,
    ),
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

  group('logout', () {
    testWidgets('without unsaved changes it logs out right away',
        (tester) async {
      final auth = FakeAuthService();
      final repository = FakeDeviceRepository();
      await _pumpScreen(tester, repository, authService: auth);
      repository.devices.add(_devices);
      await tester.pump();

      await tester.tap(find.text('Abmelden'));
      // The loading screen has an endless spinner: step through the 2 s
      // pause instead of pumpAndSettle.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('Nicht gespeicherte Änderungen'), findsNothing);
      expect(auth.logouts, 1);
      // The listener was stopped before the sign-out.
      expect(repository.devices.hasListener, isFalse);
    });

    testWidgets('with unsaved changes it asks, and can stay signed in',
        (tester) async {
      final auth = FakeAuthService(unsavedChanges: true);
      final repository = FakeDeviceRepository();
      await _pumpScreen(tester, repository, authService: auth);
      repository.devices.add(_devices);
      await tester.pump();

      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      expect(find.text('Nicht gespeicherte Änderungen'), findsOneWidget);

      await tester.tap(find.text('Angemeldet bleiben'));
      await tester.pumpAndSettle();

      expect(auth.logouts, 0);
      expect(find.text('Pods'), findsOneWidget);
      // Still listening: the list keeps following the repository.
      expect(repository.devices.hasListener, isTrue);
    });

    testWidgets('with unsaved changes "Trotzdem abmelden" logs out',
        (tester) async {
      final auth = FakeAuthService(unsavedChanges: true);
      final repository = FakeDeviceRepository();
      await _pumpScreen(tester, repository, authService: auth);
      repository.devices.add(_devices);
      await tester.pump();

      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trotzdem abmelden'));
      // The loading screen has an endless spinner: step through the 2 s
      // pause instead of pumpAndSettle.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(auth.logouts, 1);
    });
  });
}
