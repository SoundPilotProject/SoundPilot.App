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

  // Read before the first frame, so a guest does not see the StartScreen
  // flash up.
  await GuestModeService.load();

  runApp(const SoundPilotApp());
}

/// Root widget: a Material 3 app with a light and a dark theme.
///
/// Both themes are built by [_buildTheme] from [AppColors], so Material
/// widgets that are not styled by hand (SnackBar, Dialog, TabBar, ...) follow
/// the app palette as well.
class SoundPilotApp extends StatelessWidget {
  const SoundPilotApp({super.key});

  /// Builds the theme for the given [brightness] from the [AppColors] palette.
  ///
  /// Plus Jakarta Sans is applied here as the app-wide font, so every screen
  /// inherits it and no widget has to name a font family itself.
  static ThemeData _buildTheme(Brightness brightness) {
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
      // Follows the light/dark setting of the device.
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
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
        if (user != null) {
          return DeviceScreen(key: ValueKey('user_${user.uid}'));
        }

        return ValueListenableBuilder<bool>(
          valueListenable: GuestModeService.active,
          builder: (context, isGuest, _) => isGuest
              ? const DeviceScreen(key: ValueKey('guest'))
              : const StartScreen(),
        );
      },
    );
  }
}
