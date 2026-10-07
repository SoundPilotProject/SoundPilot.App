// test/accessibility_layout_test.dart
//
// Guards the accessibility requirement that no screen breaks at large system
// font sizes: every screen is rendered on a small phone (360x720) in light and
// dark mode at text scale 1.0, 1.6 and 2.0, and must not throw (an overflow
// reports itself as an exception in a test).
//
// The DeviceScreen is rendered with a fake repository (two devices per type),
// both signed in and as a guest; its dialog and cards are also checked on
// their own.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/app_locale.dart';
import 'package:soundpilot_application/core/widgets/auth_text_field.dart';
import 'package:soundpilot_application/core/widgets/google_logo.dart';
import 'package:soundpilot_application/core/widgets/loading_screen.dart';
import 'package:soundpilot_application/features/auth/auth_service.dart';
import 'package:soundpilot_application/features/auth/guest_devices_offer.dart';
import 'package:soundpilot_application/features/auth/screens/login_screen.dart';
import 'package:soundpilot_application/features/auth/screens/password_reset_screen.dart';
import 'package:soundpilot_application/features/auth/screens/register_screen.dart';
import 'package:soundpilot_application/features/auth/screens/start_screen.dart';
import 'package:soundpilot_application/features/device/screens/TestPage.dart';
import 'package:soundpilot_application/features/device/screens/belt_vibration_screen.dart';
import 'package:soundpilot_application/features/device/screens/belt_warning_distance_screen.dart';
import 'package:soundpilot_application/features/device/screens/calibration.dart';
import 'package:soundpilot_application/features/device/screens/device_screen.dart';
import 'package:soundpilot_application/features/device/widgets/add_device_dialog.dart';
import 'package:soundpilot_application/features/device/widgets/device_card.dart';
import 'package:soundpilot_application/features/device/widgets/device_type.dart';
import 'package:soundpilot_application/features/device/widgets/unsynced_logout_dialog.dart';
import 'package:soundpilot_application/models/user_model.dart';

import 'helpers/fake_device_repository.dart';

/// Screen size of a small phone in logical pixels.
const Size _phone = Size(360, 720);

/// Text scales to check: normal, large and the maximum Android offers.
const List<double> _textScales = [1.0, 1.6, 2.0];

/// Wraps [child] in a MaterialApp with the given [brightness] and text [scale].
///
/// Uses the app's German locale, so Flutter's built-in labels are measured in
/// the language the user sees.
Widget _wrap(Widget child, Brightness brightness, double scale) {
  return MaterialApp(
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  );
}

/// Runs [body] for every combination of brightness and text scale.
void _forEveryScale(
  String name,
  Future<void> Function(WidgetTester tester, Brightness b, double scale) body,
) {
  for (final brightness in Brightness.values) {
    for (final scale in _textScales) {
      testWidgets('$name – $brightness, Textskalierung $scale',
          (tester) async {
        tester.view.physicalSize = _phone;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await body(tester, brightness, scale);
      });
    }
  }
}

void main() {
  group('Screens render without overflow', () {
    final screens = <String, Widget Function()>{
      'StartScreen': () => const StartScreen(),
      'LoadingScreen': () => const LoadingScreen(text: 'Wird geladen...'),
      'LoginScreen': () => const LoginScreen(),
      'RegisterScreen': () => const RegisterScreen(),
      'PasswordResetScreen': () =>
          const PasswordResetScreen(initialEmail: 'max@example.com'),
      'BeltWarningDistanceScreen': () => const BeltWarningDistanceScreen(),
      'BeltVibrationScreen': () => const BeltVibrationScreen(),
      'TestPage': () => const TestPage(leftVolume: 40, rightVolume: 80),
      'UnsyncedLogoutDialog': () => const UnsyncedLogoutDialog(),
      'GuestDevicesDialog': () => const GuestDevicesDialog(count: 2),
      'CalibrationScreen': () => CalibrationScreen(
            calib: HeadphoneCalib(modelId: 'Pods'),
            onSave: (_) async {},
          ),
    };

    for (final entry in screens.entries) {
      _forEveryScale(entry.key, (tester, brightness, scale) async {
        await tester.pumpWidget(_wrap(entry.value(), brightness, scale));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }

    for (final isSignedIn in [true, false]) {
      _forEveryScale('DeviceScreen (angemeldet: $isSignedIn)',
          (tester, brightness, scale) async {
        final repository = FakeDeviceRepository();
        await tester.pumpWidget(_wrap(
          DeviceScreen(repository: repository, isSignedIn: isSignedIn),
          brightness,
          scale,
        ));
        repository.devices.add(DeviceData(
          headphones: {
            'aa': HeadphoneCalib(modelId: 'Kopfhörer mit langem Namen'),
            'cc': HeadphoneCalib(modelId: 'Pods'),
          },
          belts: {
            'bb': BeltCalib(modelId: 'Gürtel 1'),
            'dd': BeltCalib(modelId: 'Gürtel 2'),
          },
        ));
        await tester.pump();

        expect(find.text('Pods'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('TestPage waveform', () {
    testWidgets('stands still while nothing is playing', (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        const TestPage(leftVolume: 40, rightVolume: 80),
        Brightness.light,
        1.0,
      ));

      // pumpAndSettle waits for all animations to finish and times out if one
      // repeats forever. It passing is the proof that the waveform animation
      // is not running while the playback is stopped.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });
  });

  group('Both auth screens offer the Google sign-in', () {
    // Screen, label of its Google button, label of its primary button. The
    // Google button sits above the primary one on both screens.
    final cases = <String, List<String>>{
      'LoginScreen': ['Mit Google anmelden', 'Anmelden'],
      'RegisterScreen': ['Mit Google registrieren', 'Registrieren'],
    };

    for (final entry in cases.entries) {
      final isLogin = entry.key == 'LoginScreen';
      final googleLabel = entry.value[0];
      final primaryLabel = entry.value[1];

      _forEveryScale('${entry.key}: Button über "$primaryLabel"',
          (tester, brightness, scale) async {
        await tester.pumpWidget(_wrap(
          isLogin ? const LoginScreen() : const RegisterScreen(),
          brightness,
          scale,
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);

        // Both labels are also the title of the top bar, so the buttons are
        // found through their type.
        final googleButton =
            find.widgetWithText(OutlinedButton, googleLabel);
        final primaryButton =
            find.widgetWithText(ElevatedButton, primaryLabel);
        expect(googleButton, findsOneWidget);
        expect(primaryButton, findsOneWidget);

        // The team asked for it above the primary button.
        expect(
          tester.getCenter(googleButton).dy,
          lessThan(tester.getCenter(primaryButton).dy),
          reason: 'the Google button belongs above "$primaryLabel"',
        );

        // Large enough to hit, at every font size.
        expect(
          tester.getSize(googleButton).height,
          greaterThanOrEqualTo(48.0),
          reason: 'tap target of the Google button (scale $scale)',
        );

        // The logo is decoration: the label has to carry the meaning, so the
        // logo must not add anything to the semantics tree.
        expect(find.byType(GoogleLogo), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(GoogleLogo),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
          reason: 'the Google logo must stay out of the semantics tree',
        );
      });
    }
  });

  group('PasswordResetScreen', () {
    _forEveryScale('Ergebnis bleibt sichtbar', (tester, brightness, scale) async {
      final requested = <String>[];
      await tester.pumpWidget(_wrap(
        PasswordResetScreen(
          initialEmail: 'max@example.com',
          sendReset: (email) async {
            requested.add(email);
            return null;
          },
        ),
        brightness,
        scale,
      ));
      await tester.pump();

      // Pre-filled from the login screen.
      expect(find.text('max@example.com'), findsOneWidget);

      // At large text scales the button is below the fold; the screen scrolls.
      final sendButton = find.widgetWithText(ElevatedButton, 'Link senden');
      await tester.ensureVisible(sendButton);
      await tester.pumpAndSettle();
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(requested, ['max@example.com']);
      // The result is text on the screen, with an icon, and stays there.
      expect(find.text(AuthService.passwordResetSentMessage), findsOneWidget);
      expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text(AuthService.passwordResetSentMessage), findsOneWidget);

      // After success the one action is going back.
      expect(find.widgetWithText(ElevatedButton, 'Zurück zur Anmeldung'),
          findsOneWidget);
      expect(
        tester
            .getSize(find.widgetWithText(ElevatedButton, 'Zurück zur Anmeldung'))
            .height,
        greaterThanOrEqualTo(48.0),
      );
    });

    testWidgets('empty address gives a message and sends nothing',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(
        PasswordResetScreen(sendReset: (_) async {
          calls++;
          return null;
        }),
        Brightness.light,
        1.0,
      ));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Link senden'));
      await tester.pump();

      expect(calls, 0);
      expect(find.text('Bitte gib deine E-Mail-Adresse ein.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows the error and keeps the address editable',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PasswordResetScreen(
          initialEmail: 'max@',
          sendReset: (_) async => AuthService.messageForCode('invalid-email'),
        ),
        Brightness.dark,
        1.0,
      ));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Link senden'));
      await tester.pumpAndSettle();

      final error = AuthService.messageForCode('invalid-email');
      expect(find.text(error), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Link senden'), findsOneWidget);

      // Correcting the address clears the old result.
      await tester.enterText(find.byType(TextField), 'max@example.com');
      await tester.pump();
      expect(find.text(error), findsNothing);
    });

    testWidgets('is disabled while sending and sends only once',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(
        PasswordResetScreen(
          initialEmail: 'max@example.com',
          sendReset: (_) async {
            calls++;
            await Future<void>.delayed(const Duration(seconds: 1));
            return null;
          },
        ),
        Brightness.light,
        1.0,
      ));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Link senden'));
      await tester.pump();
      expect(find.text('Wird gesendet...'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text(AuthService.passwordResetSentMessage), findsOneWidget);
    });

    testWidgets('a changed address after success offers sending again',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PasswordResetScreen(
          initialEmail: 'max@example.com',
          sendReset: (_) async => null,
        ),
        Brightness.light,
        1.0,
      ));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Link senden'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Zurück zur Anmeldung'),
          findsOneWidget);

      await tester.enterText(find.byType(TextField), 'anna@example.com');
      await tester.pump();
      expect(find.text(AuthService.passwordResetSentMessage), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Link senden'), findsOneWidget);
    });

    testWidgets('"Passwort vergessen?" opens it with the typed address',
        (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const LoginScreen(), Brightness.light, 1.0));
      await tester.enterText(find.byType(TextField).first, ' max@example.com ');
      await tester.tap(find.text('Passwort vergessen?'));
      await tester.pumpAndSettle();

      expect(find.byType(PasswordResetScreen), findsOneWidget);
      expect(
        tester.widget<PasswordResetScreen>(find.byType(PasswordResetScreen))
            .initialEmail,
        'max@example.com',
      );

      // Back returns to the login form.
      await tester.tap(find.byTooltip('Zurück'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordResetScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('RegisterScreen stays large and readable', () {
    // The form used to be squeezed onto one screen, which forced 16 px
    // captions and 58 px fields. Readability wins over "no scrolling": the
    // screen scrolls, and these bounds keep anyone from shrinking it again to
    // buy space.
    _forEveryScale('Größe der Felder und Beschriftungen',
        (tester, brightness, scale) async {
      await tester.pumpWidget(_wrap(const RegisterScreen(), brightness, scale));
      await tester.pump();

      expect(tester.takeException(), isNull);

      // Every field has a caption above it and a placeholder inside it, so
      // each of these words is on screen more than once.
      for (final caption in ['Vorname', 'Nachname', 'E-Mail', 'Gürtel']) {
        expect(find.text(caption), findsWidgets, reason: 'caption $caption');
      }
      // The password field is the exception: the caption is short and the rule
      // lives in the placeholder.
      expect(find.text('Passwort'), findsWidgets);
      expect(
        find.text('Passwort muss 6 Zeichen enthalten'),
        findsWidgets,
        reason: 'the length rule belongs in the password placeholder',
      );

      // 'Bereits ein Konto?' is a plain label, 'Hier anmelden' the control.
      expect(find.text('Bereits ein Konto?'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Bereits ein Konto?'),
          matching: find.byType(TextButton),
        ),
        findsNothing,
        reason: 'the label must not be tappable',
      );

      // Captions: readable size, and they follow the system font setting
      // instead of being capped.
      final caption = tester.renderObject<RenderParagraph>(
        find.text('Vorname').first,
      );
      final captionSize = caption.text.style!.fontSize!;
      expect(
        captionSize,
        greaterThanOrEqualTo(22.0),
        reason: 'the black caption must stay large',
      );
      expect(
        caption.textScaler.scale(captionSize),
        greaterThanOrEqualTo(captionSize * scale - 0.5),
        reason: 'the caption must follow the system font size, not be clamped',
      );

      // Fields: comfortably tall. The height is content padding plus the
      // scaled text, so it grows with the font setting but not proportionally
      // — measured 72 px at scale 1.0, 90 px at 1.6 and 103 px at 2.0.
      final fieldHeight =
          tester.getSize(find.byType(AuthTextField).first).height;
      expect(
        fieldHeight,
        greaterThanOrEqualTo(72.0),
        reason: 'fields must stay large (scale $scale)',
      );
    });
  });

  group('Device list widgets render without overflow', () {
    _forEveryScale('DeviceCard und LegendBox', (tester, brightness, scale) async {
      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DeviceCard(
                  name: 'Sennheiser HD 450BT',
                  type: DeviceType.earbuds,
                  isConnected: true,
                  onDelete: () {},
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                DeviceCard(
                  name: 'SoundPilot Belt 1',
                  type: DeviceType.belt,
                  isConnected: false,
                  onDelete: () {},
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                const LegendBox(),
              ],
            ),
          ),
        ),
        brightness,
        scale,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The delete button needs a label; it is icon-only.
      expect(find.byTooltip('SoundPilot Belt 1 entfernen'), findsOneWidget);
    });
  });

  group('AddDeviceDialog follows the selected device type', () {
    _forEveryScale('Earbuds und Gürtel', (tester, brightness, scale) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(body: AddDeviceDialog()),
        brightness,
        scale,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Earbuds is the default type.
      expect(find.text('Kopfhörer suchen'), findsOneWidget);

      // Switching to belts has to change every label.
      await tester.tap(find.text('Gürtel'));
      await tester.pumpAndSettle();
      expect(find.text('Gürtel suchen'), findsOneWidget);
      expect(find.text('Kopfhörer suchen'), findsNothing);
      expect(find.textContaining('Tippe auf „Gürtel suchen“'), findsOneWidget);

      // The scan has to return belts, not headphones.
      await tester.tap(find.text('Gürtel suchen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.text('SoundPilot Belt 1'), findsOneWidget);
      expect(find.text('AirPods Pro'), findsNothing);

      // The manual tab has to talk about belts as well.
      await tester.tap(find.text('Manuell'));
      await tester.pumpAndSettle();
      expect(find.text('Name des Gürtels:'), findsOneWidget);
      expect(
        find.text('Nach dem Hinzufügen wird die Einrichtung gestartet.'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('AddDeviceResult', () {
    testWidgets('a belt also requests its setup', (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      AddDeviceResult? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<AddDeviceResult>(
                  context: context,
                  builder: (_) => const AddDeviceDialog(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gürtel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manuell'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mein Gürtel');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.type, DeviceType.belt);
      expect(result!.name, 'Mein Gürtel');
      // Belts used to come back with `false` here, so their setup never opened.
      expect(result!.openCalibration, isTrue);
    });
  });
}
