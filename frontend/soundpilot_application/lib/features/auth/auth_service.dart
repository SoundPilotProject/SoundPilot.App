import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../core/app_logger.dart'; // Import our global logger

/// Service class to handle Firebase Authentication operations.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Signs in a user and logs the process using [logger].
  Future<UserModel?> login(String email, String password) async {
    try {
      logger.i("AuthService: Attempting login for $email");

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final User? firebaseUser = result.user;

      if (firebaseUser != null) {
        logger.d("AuthService: Login successful for UID: ${firebaseUser.uid}");
        return UserModel(
          id: firebaseUser.uid,
          username: firebaseUser.displayName ?? 'Unknown User',
          email: firebaseUser.email ?? '',
        );
      }
    } on FirebaseAuthException catch (e) {
      // Use logger.w (Warning) for expected Auth errors like wrong passwords
      logger.w("AuthService: Firebase Auth Exception [${e.code}]: ${e.message}");
    } catch (e) {
      // Use logger.e (Error) for unexpected system failures
      logger.e("AuthService: Unexpected error during login", error: e);
    }
    return null;
  }

  /// Registers a new user and logs success or failure.
  Future<UserModel?> register(String email, String password, String name) async {
    try {
      logger.i("AuthService: Starting registration for $email");

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final User? firebaseUser = result.user;

      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(name);
        logger.d("AuthService: User registered and display name set to $name");

        return UserModel(
          id: firebaseUser.uid,
          username: name,
          email: email,
        );
      }
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Registration failed [${e.code}]: ${e.message}");
    } catch (e) {
      logger.e("AuthService: Critical registration error", error: e);
    }
    return null;
  }
}