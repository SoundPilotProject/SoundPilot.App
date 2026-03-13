import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../device/screens/device_screen.dart';
import '../auth_service.dart';
import 'register_screen.dart';
import 'start_screen.dart';

class LoginScreen extends StatefulWidget {
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

  Future<void> _finishLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Bitte E-Mail und Passwort eingeben.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(
          text: 'Wird eingeloggt...',
        ),
      ),
    );

    final user = await _authService.loginWithEmail(email, password);

    if (!mounted) return;

    Navigator.pop(context);

    setState(() {
      _isLoading = false;
    });

    if (user == null) {
      _showMessage('Login fehlgeschlagen.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('continueAsGuestThisSession', false);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DeviceScreen()),
          (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
                        onTap: () async {
                          final email = _emailController.text.trim();

                          if (email.isEmpty) {
                            _showMessage('Bitte zuerst deine E-Mail eingeben.');
                            return;
                          }

                          final success =
                          await _authService.sendPasswordReset(email);

                          if (!mounted) return;

                          _showMessage(
                            success
                                ? 'Passwort-Reset wurde gesendet.'
                                : 'Reset fehlgeschlagen.',
                          );
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