// lib/main.dart
//
// App entry point: initializes Firebase, configures the Material themes and
// decides which screen is shown first (device list or start screen).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/auth/screens/start_screen.dart';
import 'features/device/screens/device_screen.dart';
import 'core/app_locale.dart';
import 'core/app_logger.dart';
import 'core/services/device_repository.dart';
import 'core/services/firestore_device_repository.dart';
import 'core/services/guest_mode_service.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/loading_screen.dart';
import 'firebase_options.dart';

/// Initializes the Flutter bindings and Firebase, then starts the app.
Future<void> main() async {
  // Required because plugins are used before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // The platform-specific options are generated in firebase_options.dart.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firebase's own texts in German: the password reset e-mail (unless the
  // template is customised in the console), the reCAPTCHA and the Google
  // sign-in pages. Without it Firebase logs "Ignoring header
  // X-Firebase-Locale because its value was null".
  try {
    await FirebaseAuth.instance.setLanguageCode(appLocale.languageCode);
  } catch (e) {
    // Not worth stopping the start for; Firebase then uses its default.
    logger.w('main: Setting the Firebase language failed', error: e);
  }

  // NOTE: Android and iOS keep a Firestore cache on disk by default (devices
  // work offline); AuthService.logout deletes it. The browser keeps its cache
  // in memory only (the default there) on purpose: the web plugin cannot
  // delete a disk cache and keep working, see AuthService._clearFirestoreCache.

  // Clears the guest mode flag that earlier app versions stored, so such an
  // install does not start in guest mode (see GuestModeService).
  await GuestModeService.load();

  runApp(const SoundPilotApp());
}

/// Root widget: a Material 3 app with a light and a dark theme.
///
/// Both themes are built by [buildTheme] from [AppColors], so Material
/// widgets that are not styled by hand (SnackBar, Dialog, TabBar, ...) follow
/// the app palette as well.
class SoundPilotApp extends StatelessWidget {
  const SoundPilotApp({super.key});

  /// Builds the theme for the given [brightness] from the [AppColors] palette.
  ///
  /// Plus Jakarta Sans is applied here as the app-wide font, so every screen
  /// inherits it and no widget has to name a font family itself.
  ///
  /// NOTE: Public so the widget tests can render the screens with the theme
  /// the user really sees. They used to build a plain
  /// `ThemeData(brightness: ...)` instead, which measures sizes and contrast
  /// with Material's default colours and font, not with ours.
  static ThemeData buildTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final background = AppColors.backgroundOf(brightness);
    final primary = AppColors.primaryOf(brightness);
    final onPrimary = AppColors.onPrimaryOf(brightness);
    final text = AppColors.textOf(brightness);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        surface: background,
        onSurface: text,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
          .apply(bodyColor: text, displayColor: text),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceOf(brightness),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SoundPilot',
      // Fixed to German, independent of the device language (see app_locale).
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      // Follows the light/dark setting of the device.
      themeMode: ThemeMode.system,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const AppEntryPoint(),
    );
  }
}

/// Root screen: shows the [DeviceScreen] if a Firebase user is signed in or
/// guest mode is active, otherwise the [StartScreen].
///
/// It listens to `FirebaseAuth.instance.authStateChanges()` and to
/// [GuestModeService.active], so it switches by itself on sign-in, logout and
/// "Als Gast fortfahren". Screens pushed on top (login, register) only close
/// themselves after a successful sign-in.
class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen(
            text: 'Daten werden geladen...',
          );
        }

        // NOTE: The keys make sure a new DeviceScreen (and so a fresh load of
        // the devices) is created when switching between user and guest.
        final user = snapshot.data;
        // NOTE: Says which of the three screens is shown and why. "Signed in"
        // and "guest" both end on the DeviceScreen, which looks nearly the
        // same, so without this line a report of "it starts in guest mode"
        // cannot be told from a session that is simply still signed in.
        logger.d(
          'AppEntryPoint: ${user != null ? 'signed in' : 'signed out'}, '
          'guest mode = ${GuestModeService.active.value}',
        );
        if (user != null) {
          return DeviceScreen(
            key: ValueKey('user_${user.uid}'),
            repository: FirestoreDeviceRepository(uid: user.uid),
            isSignedIn: true,
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: GuestModeService.active,
          builder: (context, isGuest, _) => isGuest
              ? DeviceScreen(
                  key: const ValueKey('guest'),
                  repository: GuestDeviceRepository(),
                  isSignedIn: false,
                )
              : const StartScreen(),
        );
      },
    );
  }
}
