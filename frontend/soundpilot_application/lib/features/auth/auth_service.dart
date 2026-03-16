// lib/features/auth/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../core/app_logger.dart';
import '../../core/services/device_storage_service.dart';

/// Service to handle Email/Password and Google Authentication.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Register ──────────────────────────────────────────────────────────────

  Future<UserModel?> registerWithEmail(String email, String password) async {
    try {
      logger.i("AuthService: Attempting Email registration for $email");

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      logger.d("AuthService: Email registration successful for ${result.user?.email}");

      // Gastdaten (Geräte + Kalibrierung) in das Benutzerkonto übernehmen
      await DeviceStorageService.migrateGuestDataAfterLogin();

      return _mapFirebaseUser(result.user);
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Email registration failed [${e.code}]");
      return null;
    } catch (e) {
      logger.e("AuthService: Critical error during Email registration", error: e);
      return null;
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<UserModel?> loginWithEmail(String email, String password) async {
    try {
      logger.i("AuthService: Attempting Email login for $email");

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      logger.d("AuthService: Email login successful for ${result.user?.email}");

      // Upload any locally saved calibration data to Firestore (only if
      // the user has no cloud data yet — e.g. first login on a new device)
      await DeviceStorageService.migrateGuestDataAfterLogin();

      return _mapFirebaseUser(result.user);
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Email login failed [${e.code}]");
      return null;
    } catch (e) {
      logger.e("AuthService: Critical error during Email login", error: e);
      return null;
    }
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      logger.i("AuthService: Password reset email sent to $email");
      return true;
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Password reset failed [${e.code}]");
      return false;
    } catch (e) {
      logger.e("AuthService: Critical error during password reset", error: e);
      return false;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<UserModel?> signInWithGoogle() async {
    try {
      logger.i("AuthService: Starting Google Sign-In flow");

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        logger.w("AuthService: Google Sign-In aborted by user");
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result =
      await _auth.signInWithCredential(credential);
      logger.d("AuthService: Google login successful for ${result.user?.email}");

      await DeviceStorageService.migrateGuestDataAfterLogin();

      return _mapFirebaseUser(result.user);
    } catch (e) {
      logger.e("AuthService: Critical error during Google Sign-In", error: e);
      return null;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Clear the guest-session flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('continueAsGuestThisSession', false);

    await _auth.signOut();
    await _googleSignIn.signOut();

    logger.i("AuthService: User logged out");
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  UserModel? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return UserModel(
      id: user.uid,
      username: user.displayName ?? 'No Name',
      email: user.email ?? '',
    );
  }
}