// lib/features/auth/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../core/app_logger.dart';
import '../../core/services/device_storage_service.dart';

/// Service to handle Email/Password and Google Authentication.
///
/// Every sign-in/registration method returns `null` on failure, so the UI
/// cannot tell the reason apart (wrong password, no network, ...).
///
/// TODO(improve): Return the FirebaseAuthException code (e.g. a small result
/// type) so the screens can show specific messages instead of one generic
/// text like 'Login fehlgeschlagen.'.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Register ───────────────────────────────────────────────────────────────

  /// Creates an account with e-mail and password.
  ///
  /// The cloud function `createUserDoc` creates the Firestore document
  /// asynchronously. Returns the new user, or `null` if the registration failed.
  Future<UserModel?> registerWithEmail(String email, String password) async {
    try {
      logger.i("AuthService: Attempting Email registration");

      // NOTE: Only the e-mail address is trimmed; spaces are valid password
      // characters (same in loginWithEmail).
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      logger.d("AuthService: Email registration successful");

      // Take over the guest data (devices + calibration) into the user account.
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

  // ── Login ──────────────────────────────────────────────────────────────────

  /// Signs in with e-mail and password.
  ///
  /// Returns the signed-in user, or `null` if the login failed.
  Future<UserModel?> loginWithEmail(String email, String password) async {
    try {
      logger.i("AuthService: Attempting Email login");

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      logger.d("AuthService: Email login successful");

      // Copies locally saved guest calibration data to the user's own local
      // key (only if the user has no data yet — e.g. first login on a new
      // device). NOTE: This is a purely local copy in SharedPreferences.
      // Original intent of this comment: upload the locally saved calibration
      // data to Firestore, only if the user has no cloud data yet. That upload
      // does not exist yet.
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

  // ── Password reset ─────────────────────────────────────────────────────────

  /// Sends a password reset e-mail. Returns `true` if it was sent.
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      logger.i("AuthService: Password reset email sent");
      return true;
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Password reset failed [${e.code}]");
      return false;
    } catch (e) {
      logger.e("AuthService: Critical error during password reset", error: e);
      return false;
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Signs in with a Google account and links it to Firebase Auth.
  ///
  /// Returns `null` if the user aborted the dialog or the sign-in failed.
  ///
  /// NOTE: Unlike the e-mail methods this only has a generic catch, no
  /// separate handling of FirebaseAuthException.
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
      logger.d("AuthService: Google login successful");

      await DeviceStorageService.migrateGuestDataAfterLogin();

      return _mapFirebaseUser(result.user);
    } catch (e) {
      logger.e("AuthService: Critical error during Google Sign-In", error: e);
      return null;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  /// Signs out of Firebase and Google and clears the guest flag.
  Future<void> logout() async {
    // Clear the guest-session flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('continueAsGuestThisSession', false);

    await _auth.signOut();
    await _googleSignIn.signOut();

    logger.i("AuthService: User logged out");
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  /// Maps a Firebase [User] to a [UserModel] (without devices).
  /// Returns `null` if [user] is `null`.
  UserModel? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return UserModel(
      id: user.uid,
      displayName: user.displayName ?? UserModel.defaultDisplayName,
      email: user.email ?? '',
    );
  }
}