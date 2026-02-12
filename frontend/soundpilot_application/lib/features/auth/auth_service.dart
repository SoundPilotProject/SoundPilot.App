import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_model.dart';
import '../../core/app_logger.dart';

/// Service to handle Email/Password and Google Authentication.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Sign in with Email and Password.
  Future<UserModel?> loginWithEmail(String email, String password) async {
    try {
      logger.i("AuthService: Attempting Email login for $email");
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return _mapFirebaseUser(result.user);
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Email login failed [${e.code}]");
      return null;
    }
  }

  /// Sign in with Google Account.
  Future<UserModel?> signInWithGoogle() async {
    try {
      logger.i("AuthService: Starting Google Sign-In flow");

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        logger.w("AuthService: Google Sign-In aborted by user");
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential result = await _auth.signInWithCredential(credential);
      logger.d("AuthService: Google login successful for ${result.user?.email}");

      return _mapFirebaseUser(result.user);
    } catch (e) {
      logger.e("AuthService: Critical error during Google Sign-In", error: e);
      return null;
    }
  }

  /// Helper to convert Firebase User to our custom UserModel.
  UserModel? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return UserModel(
      id: user.uid,
      username: user.displayName ?? 'No Name',
      email: user.email ?? '',
    );
  }

  /// Sign out from both Firebase and Google.
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    logger.i("AuthService: User logged out");
  }
}