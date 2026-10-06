// lib/features/auth/screens/login_screen.dart
//
// E-mail/password login with password reset and a link to registration.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/auth_text_field.dart';
import '../../../core/widgets/google_sign_in_button.dart';
import '../auth_flow.dart';
import '../auth_service.dart';
import 'register_screen.dart';

/// Login screen with e-mail and password.
///
/// Also offers the password reset and a link to the [RegisterScreen].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// NOTE: `late` on purpose. AuthService reaches for `FirebaseAuth.instance`
  /// in its own field initialisers, so building it eagerly would tie merely
  /// showing this screen to an initialised Firebase.
  late final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the input and signs in with e-mail and password. [runSignIn]
  /// does the rest: loading screen, error message and closing this screen.
  ///
  /// TODO(improve): `_isLoading` (spinner in the button) is redundant because
  /// [runSignIn] pushes a full-screen LoadingScreen as well; use only one of
  /// them.
  Future<void> _finishLogin() async {
    final email = _emailController.text.trim();
    // NOTE: The password is not trimmed; spaces are valid password characters.
    final password = _passwordController.text;

    if (email.isEmpty || password.trim().isEmpty) {
      _showMessage('Bitte E-Mail und Passwort eingeben.');
      return;
    }

    setState(() => _isLoading = true);
    await runSignIn(
      context,
      loadingText: 'Wird eingeloggt...',
      signIn: () => _authService.loginWithEmail(email, password),
    );
    if (mounted) setState(() => _isLoading = false);
  }

  /// Signs in with a Google account.
  ///
  /// Needs nothing from the form: the account is picked in Google's own
  /// dialog. The Firestore document is created by the `createUserDoc` cloud
  /// function on the first sign-in, exactly as for an e-mail registration.
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    await runSignIn(
      context,
      loadingText: 'Mit Google anmelden...',
      signIn: () => _authService.signInWithGoogle(),
    );
    if (mounted) setState(() => _isLoading = false);
  }

  /// Sends a password reset e-mail to the address typed into the form.
  ///
  /// TODO(improve): Show the result in a dialog or as text on the screen that
  /// stays until the user closes it. A SnackBar disappears after a few seconds
  /// (time-limited, see the accessibility rules), and the result message is
  /// long.
  /// TODO(improve): Disable "Passwort vergessen?" and show progress while the
  /// request runs. AuthService ignores a second request meanwhile, but each
  /// tap still shows the message again.
  /// TODO(improve): Move the reset into its own short step ("Passwort
  /// zurücksetzen": one field, one button) instead of reusing the login
  /// form's e-mail field, for one main action per screen.
  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Bitte zuerst deine E-Mail eingeben.');
      return;
    }

    final error = await _authService.sendPasswordReset(email);

    if (!mounted) return;

    _showMessage(error ?? AuthService.passwordResetSentMessage);
  }

  /// Shows [message] in a SnackBar.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Back arrow: closes this screen and returns to the screen below
  /// (StartScreen or, for a guest, the DeviceScreen).
  void _handleBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);

    // NOTE: The system back button/gesture does the same as the back arrow.
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(title: 'Anmelden', onBackPressed: _handleBack),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Scrollable so the form stays reachable above the
                    // keyboard and at large system font sizes.
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 40,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'E-Mail und\nPasswort eingeben:',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              const _FieldLabel(text: 'E-Mail:'),
                              const SizedBox(height: 10),
                              AuthTextField(
                                controller: _emailController,
                                label: 'E-Mail',
                                hintText: 'E-Mail',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 22),
                              const _FieldLabel(text: 'Passwort:'),
                              const SizedBox(height: 10),
                              AuthTextField(
                                controller: _passwordController,
                                label: 'Passwort',
                                hintText: 'Passwort',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _finishLogin(),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Passwort anzeigen'
                                      : 'Passwort verbergen',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.mutedText(context),
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _sendPasswordReset,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Passwort vergessen?',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary(context),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Spacer(),
                              GoogleSignInButton(
                                onPressed:
                                    _isLoading ? null : _loginWithGoogle,
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _finishLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary(context),
                                  foregroundColor: AppColors.onPrimary(context),
                                  disabledBackgroundColor:
                                      AppColors.inactiveButton(context),
                                  elevation: 3,
                                  shadowColor:
                                      Colors.black.withValues(alpha: 0.20),
                                  minimumSize: const Size(double.infinity, 80),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 26,
                                        height: 26,
                                        child: CircularProgressIndicator(
                                          color: AppColors.onPrimary(context),
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : Text(
                                        'Anmelden',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 29,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.onPrimary(context),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Noch kein Konto?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 52),
                                ),
                                child: Text(
                                  'Registrieren',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bold caption above a text field ('E-Mail:', 'Passwort:').
///
/// The label is only decoration for sighted users; the field itself carries
/// the same text as its screen-reader label (see [AuthTextField.label]), so it
/// is hidden from the semantics tree to avoid a duplicate announcement.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: AppColors.text(context),
          height: 1.2,
        ),
      ),
    );
  }
}
