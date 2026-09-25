// lib/features/auth/screens/login_screen.dart
//
// E-mail/password login with password reset and a link to registration.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../device/screens/device_screen.dart';
import '../auth_service.dart';
import 'register_screen.dart';
import 'start_screen.dart';

/// Login screen with e-mail and password.
///
/// Also offers the password reset and a link to the [RegisterScreen].
class LoginScreen extends StatefulWidget {
  /// Where the back arrow leads: `true` returns to the [DeviceScreen] (used
  /// when opened from there as a guest), `false` to the [StartScreen].
  final bool returnToDeviceOnBack;

  const LoginScreen({
    super.key,
    this.returnToDeviceOnBack = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the input, signs in and replaces the whole navigation stack with
  /// the [DeviceScreen]. A [LoadingScreen] is shown while the login runs.
  ///
  /// TODO(improve): `setState` is called before the `mounted` check. The check
  /// belongs before the `setState`. (Same in RegisterScreen._finishRegister.)
  ///
  /// TODO(improve): `_isLoading` (spinner in the button) is redundant because
  /// a full-screen [LoadingScreen] is pushed as well; use only one of them.
  Future<void> _finishLogin() async {
    final email = _emailController.text.trim();
    // NOTE: The password is not trimmed; spaces are valid password characters.
    final password = _passwordController.text;

    if (email.isEmpty || password.trim().isEmpty) {
      _showMessage('Bitte E-Mail und Passwort eingeben.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (!mounted) return;

    // Loading route on top of this screen; it is popped again below.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(
          text: 'Wird eingeloggt...',
        ),
      ),
    );

    final result = await _authService.loginWithEmail(email, password);

    if (!mounted) return;

    Navigator.pop(context);

    setState(() {
      _isLoading = false;
    });

    if (!result.isSuccess) {
      _showMessage(result.errorMessage ?? 'Login fehlgeschlagen.');
      return;
    }

    // A signed-in user must not be treated as a guest on the next start.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('continueAsGuestThisSession', false);

    if (!mounted) return;

    // Remove all previous routes so back cannot return to the auth screens.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DeviceScreen()),
          (route) => false,
    );
  }

  /// Shows [message] in a SnackBar.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Back arrow: replaces this screen with the [DeviceScreen] or the
  /// [StartScreen], depending on [LoginScreen.returnToDeviceOnBack].
  void _handleBack() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => widget.returnToDeviceOnBack
            ? const DeviceScreen()
            : const StartScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TODO(improve): `canPop: false` without a callback disables the system
    // back button/gesture completely; only the arrow in the top bar works. Add
    // `onPopInvokedWithResult` that calls `_handleBack()` (same in
    // RegisterScreen).
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: SafeArea(
          child: Column(
            children: [
              _LoginTopBar(onBackPressed: _handleBack),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(34, 28, 34, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'E-Mail und\nPasswort eingeben:',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text(context),
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        'E-Mail:',
                        style: GoogleFonts.poppins(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text(context),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LoginTextField(
                        controller: _emailController,
                        hintText: 'E-Mail',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Passwort:',
                        style: GoogleFonts.poppins(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text(context),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LoginTextField(
                        controller: _passwordController,
                        hintText: 'Passwort',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
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
                            size: 29,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      GestureDetector(
                        // Sends a password reset e-mail to the address typed above.
                        onTap: () async {
                          final email = _emailController.text.trim();

                          if (email.isEmpty) {
                            _showMessage('Bitte zuerst deine E-Mail eingeben.');
                            return;
                          }

                          final error =
                          await _authService.sendPasswordReset(email);

                          if (!mounted) return;

                          _showMessage(error ?? 'Passwort-Reset wurde gesendet.');
                        },
                        child: Text(
                          'Passwort vergessen?',
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary(context),
                            height: 1.0,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 88,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _finishLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: AppColors.onPrimary(context),
                            elevation: 3,
                            // TODO(improve): `withOpacity` is deprecated, use
                            // `withValues(alpha: ...)` (applies to all
                            // withOpacity calls in the app).
                            shadowColor: Colors.black.withOpacity(0.20),
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
                            style: GoogleFonts.poppins(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onPrimary(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'Noch kein Konto?',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text(context),
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                  returnToDeviceOnBack:
                                  widget.returnToDeviceOnBack,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'Registrieren',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary(context),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blue top bar with a back arrow and the title 'Anmelden'.
///
/// TODO(improve): Nearly identical top bars exist in RegisterScreen,
/// CalibrationScreen, TestPage, BeltVibrationScreen and
/// BeltWarningDistanceScreen (only title, height and font size differ).
/// Replace them by one shared `AppTopBar` widget in `core/widgets/`.
class _LoginTopBar extends StatelessWidget {
  final VoidCallback onBackPressed;

  const _LoginTopBar({
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95,
      width: double.infinity,
      color: AppColors.primary(context),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackPressed,
            splashRadius: 24,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.onPrimary(context),
              size: 36,
            ),
          ),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(-18, 0),
                child: Text(
                  'Anmelden',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded text field with a leading icon and an optional trailing icon (used
/// for the password visibility toggle).
///
/// TODO(improve): Almost the same field exists as `_RegisterTextField`; share
/// one widget.
class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _LoginTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.text(context),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedText(context),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              icon,
              color: AppColors.mutedText(context),
              size: 34,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 58,
            minHeight: 58,
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppColors.background(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 24),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(
              color: AppColors.inputBorder(context),
              width: 2.2,
            ),
          ),
          // TODO(improve): Same colour and width as `enabledBorder`, so a
          // focused field looks the same as an unfocused one. Use a different
          // colour/width for focus feedback (same in _RegisterTextField).
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(
              color: AppColors.inputBorder(context),
              width: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}