// lib/main.dart
//
// App entry point: initializes Firebase, configures the Material themes and
// decides which screen is shown first (device list or start screen).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/auth/screens/start_screen.dart';
import 'features/device/screens/device_screen.dart';
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

/// Decides on start-up whether the [DeviceScreen] or the [StartScreen] is shown.
///
/// The [DeviceScreen] is shown if a Firebase user is already signed in or if
/// the guest flag `continueAsGuestThisSession` is set.
///
/// TODO(improve): Listen to `FirebaseAuth.instance.authStateChanges()` with a
/// StreamBuilder instead of reading `currentUser` once. The screen would then
/// stay in sync with sign-in/sign-out, and most of the manual navigation after
/// login and logout could go away. The guest flag could then also be replaced
/// (its name suggests a session flag, but it is read on the next app start).
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  /// True until the saved app state has been read.
  bool _isLoading = true;

  /// Result of the start-up check, see [_loadAppState].
  bool _shouldOpenDeviceScreen = false;

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  /// Reads the login state and the guest flag from SharedPreferences.
  ///
  /// The flag is set by the [StartScreen] when the user continues as guest and
  /// is reset here right after being read, so it only skips the
  /// [StartScreen] once.
  Future<void> _loadAppState() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isFirebaseLoggedIn = FirebaseAuth.instance.currentUser != null;
    final bool continueAsGuestThisSession =
        prefs.getBool('continueAsGuestThisSession') ?? false;

    _shouldOpenDeviceScreen =
        isFirebaseLoggedIn || continueAsGuestThisSession;

    if (continueAsGuestThisSession) {
      await prefs.setBool('continueAsGuestThisSession', false);
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen(
        text: 'Daten werden geladen...',
      );
    }

    return _shouldOpenDeviceScreen
        ? const DeviceScreen()
        : const StartScreen();
  }
}
