import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_model.dart';
import '../../core/app_logger.dart';

/// Service handles authentication processes including Email/Password and Google Sign-In.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Registers a new user with email and password.
  /// This automatically triggers the 'createUserDoc' Cloud Function upon success.
  Future<UserModel?> signUpWithEmail(String email, String password) async {
    try {
      logger.i("AuthService: Initiating registration for $email");
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      return _mapFirebaseUser(result.user);
    } on FirebaseAuthException catch (e) {
      logger.e("AuthService: Registration failed [${e.code}] - ${e.message}");
      rethrow;
    }
  }

  /// Authenticates an existing user with email and password.
  Future<UserModel?> loginWithEmail(String email, String password) async {
    try {
      logger.i("AuthService: Attempting login for $email");
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return _mapFirebaseUser(result.user);
    } on FirebaseAuthException catch (e) {
      logger.w("AuthService: Login failed [${e.code}]");
      rethrow;
    }
  }

  /// Handles Google Sign-In flow.
  /// Acts as both registration (first-time) and login for returning users.
  Future<UserModel?> signInWithGoogle() async {
    try {
      logger.i("AuthService: Starting Google Sign-In flow");

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        logger.w("AuthService: Google Sign-In cancelled by user");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      logger.d("AuthService: Google authentication successful for ${result.user?.email}");

      return _mapFirebaseUser(result.user);
    } catch (e) {
      logger.e("AuthService: Critical error during Google Sign-In", error: e);
      rethrow;
    }
  }

  /// Maps Firebase User object to the application's internal UserModel.
  UserModel? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return UserModel(
      id: user.uid,
      username: user.displayName ?? 'No Name',
      email: user.email ?? '',
    );
  }

  /// Signs out the user from both Firebase and Google sessions.
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    logger.i("AuthService: User session terminated");
  }
}