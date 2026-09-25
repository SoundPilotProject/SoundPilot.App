// lib/features/auth/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../core/app_logger.dart';
import '../../core/services/device_storage_service.dart';

/// Result of a sign-in or registration.
///
/// On success [user] is set. On failure [errorMessage] holds a German text for
/// the UI. Both are `null` if the user cancelled (Google dialog closed); the
/// UI then shows nothing.
class AuthResult {
  final UserModel? user;
  final String? errorMessage;

  const AuthResult.success(UserModel this.user) : errorMessage = null;
  const AuthResult.failure(String this.errorMessage) : user = null;
  const AuthResult.cancelled()
      : user = null,
        errorMessage = null;

  bool get isSuccess => user != null;
}

/// Service to handle Email/Password and Google Authentication.
///
/// The sign-in/registration methods return an [AuthResult]. Errors are
/// translated into short German messages by [messageForCode], so the screens
/// can tell the user what went wrong (wrong password, no network, ...).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Register ───────────────────────────────────────────────────────────────

  /// Creates an account with e-mail and password.
  ///
  /// The cloud function `createUserDoc` creates the Firestore document
  /// asynchronously.
  Future<AuthResult> registerWithEmail(String email, String password) async {
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

      return _resultFor(result.user);
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Email registration failed [${e.code}]");
      return AuthResult.failure(messageForCode(e.code));
    } catch (e) {
      logger.e("AuthService: Critical error during Email registration", error: e);
      return AuthResult.failure(messageForCode(null));
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  /// Signs in with e-mail and password.
  Future<AuthResult> loginWithEmail(String email, String password) async {
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

      return _resultFor(result.user);
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Email login failed [${e.code}]");
      return AuthResult.failure(messageForCode(e.code));
    } catch (e) {
      logger.e("AuthService: Critical error during Email login", error: e);
      return AuthResult.failure(messageForCode(null));
    }
  }

  // ── Password reset ─────────────────────────────────────────────────────────

  /// Sends a password reset e-mail. Returns `null` if it was sent, otherwise
  /// a German error message for the UI.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      logger.i("AuthService: Password reset email sent");
      return null;
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Password reset failed [${e.code}]");
      return messageForCode(e.code);
    } catch (e) {
      logger.e("AuthService: Critical error during password reset", error: e);
      return messageForCode(null);
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Signs in with a Google account and links it to Firebase Auth.
  ///
  /// Returns [AuthResult.cancelled] if the user closed the dialog.
  Future<AuthResult> signInWithGoogle() async {
    try {
      logger.i("AuthService: Starting Google Sign-In flow");

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        logger.w("AuthService: Google Sign-In aborted by user");
        return const AuthResult.cancelled();
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

      return _resultFor(result.user);
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Google Sign-In failed [${e.code}]");
      return AuthResult.failure(messageForCode(e.code));
    } catch (e) {
      logger.e("AuthService: Critical error during Google Sign-In", error: e);
      return AuthResult.failure(messageForCode(null));
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

  /// German UI message for a FirebaseAuthException [code]. Unknown codes and
  /// `null` (not a FirebaseAuthException) give a general message.
  ///
  /// NOTE: With e-mail enumeration protection (default for new Firebase
  /// projects) a wrong password and an unknown e-mail both give
  /// `invalid-credential`, so the message cannot say which one it was.
  static String messageForCode(String? code) {
    switch (code) {
      case 'invalid-email':
        return 'Die E-Mail-Adresse ist ungültig. Bitte prüfe die Schreibweise.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'E-Mail oder Passwort ist falsch.';
      case 'email-already-in-use':
        return 'Mit dieser E-Mail-Adresse gibt es schon ein Konto. '
            'Bitte melde dich an.';
      case 'weak-password':
        return 'Das Passwort ist zu schwach. Es braucht mindestens 6 Zeichen.';
      case 'user-disabled':
        return 'Dieses Konto ist gesperrt.';
      case 'account-exists-with-different-credential':
        return 'Mit dieser E-Mail-Adresse gibt es schon ein Konto. '
            'Bitte melde dich mit E-Mail und Passwort an.';
      case 'network-request-failed':
        return 'Keine Internetverbindung. '
            'Bitte prüfe deine Verbindung und versuche es noch einmal.';
      case 'too-many-requests':
        return 'Zu viele Versuche. '
            'Bitte warte kurz und versuche es dann noch einmal.';
      default:
        return 'Etwas ist schiefgelaufen. Bitte versuche es noch einmal.';
    }
  }

  /// Success result for [user], or a general failure if Firebase returned no
  /// user.
  AuthResult _resultFor(User? user) {
    final model = _mapFirebaseUser(user);
    return model != null
        ? AuthResult.success(model)
        : AuthResult.failure(messageForCode(null));
  }

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