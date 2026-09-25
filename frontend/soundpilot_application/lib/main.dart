// lib/main.dart
//
// App entry point: initializes Firebase, configures the Material themes and
// decides which screen is shown first (device list or start screen).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/auth/screens/start_screen.dart';
import 'features/device/screens/device_screen.dart';
import 'core/services/guest_mode_service.dart';
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
/// The themes only set the brightness. All actual colours come from
/// [AppColors], which switches on the current brightness.
///
/// TODO(improve): Define a ColorScheme and a TextTheme (GoogleFonts.poppins)
/// here. Material widgets that are not styled by hand (SnackBar, Dialog,
/// TabBar, ...) would then follow the app palette, and the
/// `GoogleFonts.poppins(...)` styles that are repeated in nearly every screen
/// could be replaced by theme text styles.
class SoundPilotApp extends StatelessWidget {
  const SoundPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SoundPilot',
      // Follows the light/dark setting of the device.
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
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