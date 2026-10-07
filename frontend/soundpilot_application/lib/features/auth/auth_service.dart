// lib/features/auth/auth_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_model.dart';
import '../../core/app_logger.dart';
import '../../core/services/guest_mode_service.dart';

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
  /// NOTE: `late`, so an AuthService (or a test double of it) can be created
  /// without Firebase; FirebaseAuth is only touched on first use.
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  /// NOTE: One shared instance, created on first use (static fields are
  /// lazy). In the browser the constructor already calls Google's
  /// `id.initialize()`, so one instance per AuthService logged "initialize()
  /// is called multiple times". The web never uses it (see
  /// [signInWithGoogle] and [logout]), so there it is never created.
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

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

      return await _resultFor(result.user);
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

      // NOTE: The locally saved guest devices are uploaded to the user's
      // Firestore document by FirestoreDeviceRepository once the document
      // exists, not here (devices already in the account win).

      return await _resultFor(result.user);
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Email login failed [${e.code}]");
      return AuthResult.failure(messageForCode(e.code));
    } catch (e) {
      logger.e("AuthService: Critical error during Email login", error: e);
      return AuthResult.failure(messageForCode(null));
    }
  }

  // ── Password reset ─────────────────────────────────────────────────────────

  /// German UI message after a password reset request that did not fail.
  ///
  /// NOTE: Deliberately does not claim that an e-mail was sent. With e-mail
  /// enumeration protection Firebase reports success for an address without
  /// an account too, and sends nothing.
  static const String passwordResetSentMessage =
      'Falls es ein Konto mit dieser E-Mail-Adresse gibt, haben wir dir eine '
      'E-Mail zum Zurücksetzen des Passworts geschickt. '
      'Bitte schau auch im Spam-Ordner nach.';

  /// The reset request that is still running, see [sendPasswordReset].
  Future<String?>? _pendingPasswordReset;

  /// Sends a password reset e-mail. Returns `null` if the request did not
  /// fail (the UI then shows [passwordResetSentMessage]), otherwise a German
  /// error message for the UI.
  ///
  /// NOTE: A second call while a request is still running returns that
  /// request instead of sending another e-mail (double tap). Firebase also
  /// sends the e-mail for an account that only uses Google; setting a
  /// password through the link adds e-mail/password to the same account.
  Future<String?> sendPasswordReset(String email) {
    return _pendingPasswordReset ??= _sendPasswordReset(email)
        .whenComplete(() => _pendingPasswordReset = null);
  }

  Future<String?> _sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      logger.i("AuthService: Password reset email requested");
      return null;
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Password reset failed [${e.code}]");
      return messageForResetCode(e.code);
    } catch (e) {
      logger.e("AuthService: Critical error during password reset", error: e);
      return messageForCode(null);
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Signs in with a Google account and links it to Firebase Auth.
  ///
  /// Returns [AuthResult.cancelled] if the user closed the dialog.
  ///
  /// NOTE: In the browser, Firebase Auth opens the Google popup itself
  /// ([FirebaseAuth.signInWithPopup]). google_sign_in_web's `signIn()` is
  /// deprecated there: it returns no reliable ID token and needs the People
  /// API for the profile. On Android/iOS the google_sign_in plugin is used.
  Future<AuthResult> signInWithGoogle() async {
    try {
      logger.i("AuthService: Starting Google Sign-In flow");

      final UserCredential result;
      if (kIsWeb) {
        result = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
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

        result = await _auth.signInWithCredential(credential);
      }
      logger.d("AuthService: Google login successful");

      return await _resultFor(result.user);
    } on FirebaseAuthException catch (e) {
      // Web only: the user closed the popup, or a second click replaced it.
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        logger.w("AuthService: Google Sign-In popup closed by user");
        return const AuthResult.cancelled();
      }

      logger.w("AuthService: Google Sign-In failed [${e.code}]");
      return AuthResult.failure(messageForCode(e.code));
    } on PlatformException catch (e) {
      // The plugin wraps every failure of the native Google side in a
      // PlatformException. The code plus the native status code in the message
      // is the only hint there is, so log both: 'sign_in_failed' together with
      // 'ApiException: 10' (DEVELOPER_ERROR) means the SHA-1 fingerprint of
      // the installed build is not registered in the Firebase project.
      logger.e(
        "AuthService: Google Sign-In failed natively "
        "[${e.code}] ${e.message}",
        error: e,
      );

      // iOS reports a closed dialog as an exception instead of a null account.
      if (e.code == 'sign_in_canceled') return const AuthResult.cancelled();

      return AuthResult.failure(messageForGoogleCode(e.code));
    } on MissingPluginException catch (e) {
      // No Google Sign-In implementation for this platform (e.g. Windows).
      logger.e(
        "AuthService: Google Sign-In is not available on this platform",
        error: e,
      );
      return AuthResult.failure(messageForGoogleCode(_missingPluginCode));
    } catch (e) {
      logger.e("AuthService: Critical error during Google Sign-In", error: e);
      return AuthResult.failure(messageForCode(null));
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  /// Signs out of Firebase and Google and ends guest mode, so AppEntryPoint
  /// shows the StartScreen.
  ///
  /// NOTE: Google Sign-In is only signed out if the user signed in with
  /// Google, and not on the web, where Firebase Auth did the Google sign-in
  /// itself; it throws on platforms where it is not configured (Windows). A
  /// failed Google sign-out is only logged, because the Firebase sign-out has
  /// already succeeded at that point.
  ///
  /// Afterwards the local Firestore cache is deleted on Android/iOS, so the
  /// user's devices do not stay on the phone ([_clearFirestoreCache]). Changes
  /// that have not reached the server yet are lost with it; ask
  /// [hasUnsavedChanges] first.
  Future<void> logout() async {
    await GuestModeService.set(false);

    // Read before the sign-out, currentUser is null afterwards.
    final usedGoogle = _auth.currentUser?.providerData
            .any((info) => info.providerId == 'google.com') ??
        false;

    await _auth.signOut();

    if (usedGoogle && !kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        logger.w("AuthService: Google sign-out failed", error: e);
      }
    }

    await _clearFirestoreCache();

    logger.i("AuthService: User logged out");
  }

  /// Whether changes of the signed-in user are still waiting to be sent to
  /// Firestore after waiting up to [wait] for them (e.g. offline).
  Future<bool> hasUnsavedChanges({
    Duration wait = const Duration(seconds: 5),
  }) {
    if (_auth.currentUser == null) return Future.value(false);
    return writesStillPending(
      FirebaseFirestore.instance.waitForPendingWrites(),
      wait,
    );
  }

  /// `true` if [pendingWrites] (from `waitForPendingWrites()`) has not
  /// completed within [wait].
  ///
  /// NOTE: An error also counts as pending: then it is unknown whether
  /// something would be lost, and asking once too often is cheaper than a
  /// lost calibration.
  static Future<bool> writesStillPending(
    Future<void> pendingWrites,
    Duration wait,
  ) async {
    try {
      await pendingWrites.timeout(wait);
      return false;
    } on TimeoutException {
      return true;
    } catch (e) {
      logger.w("AuthService: Checking pending writes failed", error: e);
      return true;
    }
  }

  /// Deletes the local Firestore cache (Android/iOS).
  ///
  /// NOTE: `clearPersistence()` only works on a terminated instance. On
  /// Android/iOS FlutterFire creates a new one on the next use, so the next
  /// sign-in works. The web plugin keeps the terminated one (every later call
  /// would fail until a reload), so the browser has no disk cache instead (see
  /// main.dart) and is skipped here. A failure is only logged: the sign-out
  /// itself has already happened.
  Future<void> _clearFirestoreCache() async {
    if (kIsWeb) return;
    try {
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
      logger.i("AuthService: Firestore cache cleared");
    } catch (e) {
      logger.w("AuthService: Clearing the Firestore cache failed", error: e);
    }
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
      case 'popup-blocked':
        return 'Das Google-Fenster konnte nicht geöffnet werden. '
            'Bitte erlaube Pop-ups für diese Seite oder melde dich mit '
            'E-Mail und Passwort an.';
      case 'too-many-requests':
        return 'Zu viele Versuche. '
            'Bitte warte kurz und versuche es dann noch einmal.';
      default:
        return 'Etwas ist schiefgelaufen. Bitte versuche es noch einmal.';
    }
  }

  /// German UI message for a failed password reset with [code], or `null` if
  /// the UI should treat it as sent.
  ///
  /// NOTE: 'user-not-found' only comes if e-mail enumeration protection is
  /// off. It is treated as sent, so the reset never reveals whether an address
  /// has an account, and because [messageForCode]'s "E-Mail oder Passwort ist
  /// falsch." makes no sense when no password was entered.
  static String? messageForResetCode(String? code) {
    if (code == 'user-not-found') return null;
    return messageForCode(code);
  }

  /// Own code for a platform without a Google Sign-In implementation; the
  /// plugin itself has none, because it throws a [MissingPluginException].
  static const String _missingPluginCode = 'missing-plugin';

  /// German UI message for a failure [code] of the google_sign_in plugin.
  ///
  /// Separate from [messageForCode]: these codes come from the plugin and the
  /// native Google side, not from Firebase Auth. Unknown codes fall back to the
  /// general message.
  ///
  /// NOTE: 'sign_in_failed' is what Android reports for the frequent setup
  /// error DEVELOPER_ERROR (ApiException: 10) — the SHA-1 fingerprint of the
  /// installed build is not registered in the Firebase project, so Google
  /// refuses to hand out an ID token. Every developer has to add the SHA-1 of
  /// their own debug keystore there once (see §3 of docs/PROJECT_CONTEXT.md).
  /// The message therefore names e-mail login as the way out instead of
  /// blaming the user.
  static String messageForGoogleCode(String? code) {
    switch (code) {
      case 'sign_in_failed':
        return 'Die Google-Anmeldung ist für diese App-Version nicht '
            'freigegeben. Bitte melde dich mit E-Mail und Passwort an.';
      case 'network_error':
        return messageForCode('network-request-failed');
      case _missingPluginCode:
        return 'Die Google-Anmeldung gibt es auf diesem Gerät nicht. '
            'Bitte melde dich mit E-Mail und Passwort an.';
      default:
        return messageForCode(null);
    }
  }

  /// Success result for [user] (and the end of guest mode), or a general
  /// failure if Firebase returned no user.
  Future<AuthResult> _resultFor(User? user) async {
    final model = _mapFirebaseUser(user);
    if (model == null) return AuthResult.failure(messageForCode(null));

    // A signed-in user is no guest, also not on the next app start.
    await GuestModeService.set(false);
    return AuthResult.success(model);
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