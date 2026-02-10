import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// TODO: Add your firebase_options.dart import after running 'flutterfire configure'
// import 'firebase_options.dart';

void main() async {
  /// Ensures that widget binding is initialized before calling native code.
  /// This is required for Firebase initialization.
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize Firebase with the default options for the current platform.
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundPilot Application',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // As specified in pubspec.yaml
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Firebase is initialized!'),
        ),
      ),
    );
  }
}