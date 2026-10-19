// test/screen_reader_test.dart
//
// Guards what a screen reader is told. Two kinds of check:
//
// 1. Flutter's own accessibility guidelines over every screen and dialog in
//    both themes: every tappable element has a label, tap targets reach
//    48 dp (Android) resp. 44 dp (iOS), and text meets the contrast ratios.
// 2. Targeted semantics checks for the states that matter (selected side,
//    connection of a card, calibration value, named text fields), which no
//    guideline can see.
//
// The guidelines cannot judge reading order or whether a label makes sense;
// that still needs the device protocol in docs/SCREEN_READER_PLAN.md §3.2.
//
// NOTE: Several checks here exist because the semantics of a Material button
// do *not* merge with a wrapper around it: `ButtonStyleButton` wraps itself in
// `Semantics(container: true)`, so a `Tooltip` or a `Semantics` placed around
// an ElevatedButton lands on a node of its own and never reaches the node the
// screen reader focuses. Both bugs this file now guards against were exactly
// that mistake.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/core/services/audio_device_service.dart';
import 'package:soundpilot_application/core/widgets/loading_screen.dart';
import 'package:soundpilot_application/features/auth/guest_devices_offer.dart';
import 'package:soundpilot_application/features/auth/screens/login_screen.dart';
import 'package:soundpilot_application/features/auth/screens/password_reset_screen.dart';
import 'package:soundpilot_application/features/auth/screens/register_screen.dart';
import 'package:soundpilot_application/features/auth/screens/start_screen.dart';
import 'package:soundpilot_application/features/device/screens/belt_vibration_screen.dart';
import 'package:soundpilot_application/features/device/screens/belt_warning_distance_screen.dart';
import 'package:soundpilot_application/features/device/screens/calibration_screen.dart';
import 'package:soundpilot_application/features/device/screens/device_screen.dart';
import 'package:soundpilot_application/features/device/screens/test_page.dart';
import 'package:soundpilot_application/features/device/widgets/add_device_dialog.dart';
import 'package:soundpilot_application/features/device/widgets/belt_setup_fields.dart';
import 'package:soundpilot_application/features/device/widgets/device_type.dart';
import 'package:soundpilot_application/features/device/widgets/remove_device_dialog.dart';
import 'package:soundpilot_application/features/device/widgets/unsynced_logout_dialog.dart';
import 'package:soundpilot_application/main.dart';
import 'package:soundpilot_application/models/user_model.dart';

import 'helpers/fake_device_repository.dart';

/// Screen size of a small phone in logical pixels.
const Size _phone = Size(360, 720);

/// Connected headphones, as the native side reports them.
const List<HeadphoneDevice> _connected = [
  HeadphoneDevice(
    name: 'Pods',
    address: 'AA',
    isConnected: true,
    outputDeviceId: 1,
  ),
];

/// Wraps [child] in the app's own theme and locale (see
/// `accessibility_layout_test.dart`, which measures sizes the same way).
Widget _wrap(Widget child, Brightness brightness) {
  return MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    theme: SoundPilotApp.buildTheme(brightness),
    home: child,
  );
}

/// Runs [body] as a widget test with the semantics tree switched on, on a
/// phone-sized screen.
///
/// NOTE: The handle is disposed inside the test body, not in a tear-down:
/// Flutter checks for leaked semantics handles *before* the tear-downs run.
void _semanticsTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await body(tester);

    handle.dispose();
  });
}

/// Lets pending work and the short animations finish, and drops the exception
/// google_fonts raises.
///
/// NOTE 1: Deliberately not `pumpAndSettle`. The loading screen and the scan
/// button carry an endlessly repeating spinner, which makes `pumpAndSettle`
/// time out; a fixed pump is long enough for the 180 ms transitions of the
/// type selector and the scan list.
///
/// NOTE 2: The app's font is fetched at runtime, which no test can do, so
/// every `GoogleFonts.plusJakartaSans(...)` call in a screen ends in a failed
/// load. The other test files never see it because they only pump a frame or
/// two; here the awaits give the load time to fail inside the test. These
/// checks are about labels, states and sizes, for which the fallback font is
/// fine — but any *other* exception still fails the test.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  for (var i = 0; i < 10; i++) {
    final error = tester.takeException();
    if (error == null) return;
    if (!error.toString().contains('font')) throw error;
  }
}

/// Pumps [child] and lets it settle (see [_settle]).
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(_wrap(child, brightness));
  await _settle(tester);
}

/// The [DeviceScreen] with two devices, one of each type.
Future<FakeDeviceRepository> _pumpDeviceScreen(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Stream<List<HeadphoneDevice>>? headphones,
}) async {
  final repository = FakeDeviceRepository();
  await _pump(
    tester,
    DeviceScreen(
      repository: repository,
      isSignedIn: true,
      headphoneChanges: () => headphones ?? const Stream.empty(),
    ),
    brightness: brightness,
  );
  repository.devices.add(DeviceData(
    headphones: {'AA': HeadphoneCalib(modelId: 'Pods')},
    belts: {'bb': BeltCalib(modelId: 'Gürtel 1')},
  ));
  await _settle(tester);
  return repository;
}

void main() {
  // NOTE: Without this google_fonts tries to download Plus Jakarta Sans at
  // runtime. In a test every HTTP request fails, and the failure surfaces as
  // an exception in whichever test is running. The fallback font is enough
  // here: these checks are about labels and sizes, not about glyph shapes.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Flutter accessibility guidelines', () {
    final screens = <String, Widget Function()>{
      'StartScreen': () => const StartScreen(),
      'LoadingScreen': () => const LoadingScreen(text: 'Wird geladen...'),
      'LoginScreen': () => const LoginScreen(),
      'RegisterScreen': () => const RegisterScreen(),
      'PasswordResetScreen': () => const PasswordResetScreen(
            initialEmail: 'max@example.com',
          ),
      'BeltWarningDistanceScreen': () => const BeltWarningDistanceScreen(),
      'BeltVibrationScreen': () => const BeltVibrationScreen(),
      'CalibrationScreen': () => CalibrationScreen(
            calib: HeadphoneCalib(modelId: 'Pods'),
            address: 'AA',
            onSave: (_) async {},
            headphoneChanges: () => Stream.value(_connected),
            toneSupported: true,
          ),
      'TestPage': () => TestPage(
            leftVolume: 40,
            rightVolume: 80,
            address: 'AA',
            headphoneChanges: () => Stream.value(_connected),
            soundSupported: true,
          ),
      'GuestDevicesDialog': () => const GuestDevicesDialog(count: 2),
      'UnsyncedLogoutDialog': () => const UnsyncedLogoutDialog(),
      'RemoveDeviceDialog': () => const RemoveDeviceDialog(name: 'Pods'),
      'AddDeviceDialog': () => const Scaffold(body: AddDeviceDialog()),
    };

    /// Runs the guidelines on whatever [tester] currently shows.
    ///
    /// NOTE: Without `textContrastGuideline` on purpose. That one renders the
    /// screen to an image, and the await inside it lets google_fonts' attempt
    /// to load Plus Jakarta Sans fail inside the test (the font is fetched at
    /// runtime, which no test can do). The palette is measured instead in
    /// `color_contrast_test.dart`, including the blending of the translucent
    /// surfaces.
    Future<void> expectGuidelines(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    }

    for (final brightness in Brightness.values) {
      for (final entry in screens.entries) {
        _semanticsTest('${entry.key} – $brightness', (tester) async {
          await _pump(tester, entry.value(), brightness: brightness);
          await expectGuidelines(tester);
        });
      }

      _semanticsTest('DeviceScreen – $brightness', (tester) async {
        await _pumpDeviceScreen(tester, brightness: brightness);
        await expectGuidelines(tester);
      });
    }
  });

  group('DeviceScreen', () {
    _semanticsTest('the add button carries its name on the node that is tapped',
        (tester) async {
      await _pumpDeviceScreen(tester);

      // NOTE: The node of the button itself, not of the Tooltip around it.
      // The label used to sit on the outer node and the guideline above
      // failed, because a screen reader focuses this one.
      expect(
        tester.getSemantics(find.widgetWithIcon(ElevatedButton, Icons.add)),
        isSemantics(
          label: 'Gerät hinzufügen',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });

    _semanticsTest('a card names its type, its state and what a tap does',
        (tester) async {
      await _pumpDeviceScreen(tester);

      expect(
        tester.getSemantics(find.text('Pods')),
        isSemantics(
          label: 'Kopfhörer, Pods, nicht verbunden',
          onTapHint: 'Kalibrierung öffnen',
          isButton: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Gürtel 1')),
        isSemantics(
          label: 'Gürtel, Gürtel 1, nicht verbunden',
          onTapHint: 'Einrichtung öffnen',
        ),
      );
    });

    _semanticsTest('a connection change is announced and shown as text',
        (tester) async {
      // sync: the event arrives at add(), so one pump() rebuilds the cards.
      final headphones = StreamController<List<HeadphoneDevice>>(sync: true);
      addTearDown(headphones.close);
      await _pumpDeviceScreen(tester, headphones: headphones.stream);

      // The first list is only the state at the start.
      headphones.add(_connected);
      await _settle(tester);
      headphones.add(const []);
      await _settle(tester);

      // Spoken where the platform supports announcements...
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Pods ist jetzt getrennt'),
      );
      // ...and always on the screen, which is how it reaches a screen reader
      // on Android, where announcements are deprecated.
      expect(find.text('Pods ist jetzt getrennt'), findsOneWidget);
    });
  });

  group('BeltVibrationScreen', () {
    _semanticsTest('the selected side is announced on the focused node',
        (tester) async {
      await _pump(tester, const BeltVibrationScreen());

      // 'Mitte' is the default. Label and state have to be on the same node:
      // they used to sit on two different ones, so the selection was silent.
      expect(
        tester.getSemantics(find.text('Mitte')),
        isSemantics(label: 'Mitte', isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.text('Links')),
        isSemantics(label: 'Links', isSelected: false, isButton: true),
      );

      await tester.tap(find.text('Links'));
      await _settle(tester);

      expect(
        tester.getSemantics(find.text('Links')),
        isSemantics(label: 'Links', isSelected: true),
      );
    });

    _semanticsTest('the pre-filled strength field has a name', (tester) async {
      await _pump(tester, const BeltVibrationScreen());

      expect(
        tester.getSemantics(find.byType(BeltNumberField)),
        isSemantics(
          label: 'Vibrationsstärke in Prozent',
          value: '100',
          isTextField: true,
        ),
      );
    });
  });

  _semanticsTest('the pre-filled distance field has a name', (tester) async {
    await _pump(tester, const BeltWarningDistanceScreen());

    // A field that is pre-filled when it is first built used to be announced
    // as a nameless text box: an invisible `labelText` only reaches the
    // semantics tree while the field is empty.
    expect(
      tester.getSemantics(find.byType(BeltNumberField)),
      isSemantics(
        label: 'Warnentfernung in Zentimetern',
        value: '200',
        isTextField: true,
      ),
    );
  });

  group('AuthTextField', () {
    _semanticsTest('keeps its name when it is pre-filled', (tester) async {
      await _pump(
        tester,
        const PasswordResetScreen(initialEmail: 'max@example.com'),
      );

      expect(
        tester.getSemantics(find.byType(TextField)),
        isSemantics(
          label: 'E-Mail',
          value: 'max@example.com',
          isTextField: true,
        ),
      );
    });

    _semanticsTest('keeps its name while the user types', (tester) async {
      await _pump(tester, const LoginScreen());

      await tester.enterText(find.byType(TextField).first, 'max@example.com');
      await _settle(tester);

      expect(
        tester.getSemantics(find.byType(TextField).first),
        isSemantics(label: 'E-Mail', value: 'max@example.com'),
      );
    });
  });

  group('AddDeviceDialog', () {
    _semanticsTest('the end of the scan is announced with the number found',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: AddDeviceDialog(
            scanner: (type) async => const ScanFound([
              ScannedDevice(name: 'Pods', address: 'AA', isConnected: true),
              ScannedDevice(name: 'Bose', address: 'BB', isConnected: false),
            ]),
          ),
        ),
      );

      await tester.tap(find.text('Kopfhörer suchen'));
      await _settle(tester);

      expect(
        tester.getSemantics(find.byType(ListView)),
        isSemantics(
          label: '2 Geräte gefunden. Wähle ein Gerät aus.',
          isLiveRegion: true,
        ),
      );
    });

    _semanticsTest('the manual field keeps its name once it has text',
        (tester) async {
      await _pump(tester, const Scaffold(body: AddDeviceDialog()));

      await tester.tap(find.text('Manuell'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Meine Kopfhörer');
      await _settle(tester);

      expect(
        tester.getSemantics(find.byType(TextField)),
        isSemantics(
          label: 'Name der Kopfhörer',
          value: 'Meine Kopfhörer',
          isTextField: true,
        ),
      );
    });

    _semanticsTest('the selected type is announced as selected', (tester) async {
      await _pump(tester, const Scaffold(body: AddDeviceDialog()));

      expect(
        tester.getSemantics(find.text('Earbuds')),
        isSemantics(label: 'Earbuds', isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.text('Gürtel')),
        isSemantics(label: 'Gürtel', isSelected: false),
      );
    });
  });

  _semanticsTest('the calibration wheel reports its value only once',
      (tester) async {
    await _pump(
      tester,
      CalibrationScreen(
        calib: HeadphoneCalib(modelId: 'Pods', volumeLeft: 0.4),
        address: 'AA',
        onSave: (_) async {},
        headphoneChanges: () => Stream.value(_connected),
        toneSupported: true,
      ),
    );

    // The number inside the highlight box is excluded from the semantics
    // tree, so it is not read out on top of the value.
    expect(
      tester.getSemantics(find.text('Linke Seite')),
      isSemantics(label: 'Linke Seite', isHeader: true),
    );
    final wheel = tester.getSemantics(
      find.bySemanticsLabel('Linke Seite, Lautstärke'),
    );
    expect(
      wheel,
      isSemantics(
        label: 'Linke Seite, Lautstärke',
        value: '40 von 100',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
  });
}
