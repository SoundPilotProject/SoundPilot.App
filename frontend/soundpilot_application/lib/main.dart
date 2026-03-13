import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/auth/screens/start_screen.dart';
import 'features/device/screens/device_screen.dart';
import 'core/widgets/loading_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SoundPilotApp());
}

class SoundPilotApp extends StatelessWidget {
  const SoundPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SoundPilot',
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

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _isLoading = true;
  bool _shouldOpenDeviceScreen = false;

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

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