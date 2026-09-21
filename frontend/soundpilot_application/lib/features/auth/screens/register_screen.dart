// lib/features/auth/screens/register_screen.dart
//
// Registration form (name, e-mail, password, belt) that creates the account.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../device/screens/device_screen.dart';
import '../auth_service.dart';
import 'login_screen.dart';
import 'start_screen.dart';

/// Registration screen: creates an account with e-mail and password.
///
/// Also offers a link to the [LoginScreen].
class RegisterScreen extends StatefulWidget {
  /// Where the back arrow leads: `true` returns to the [DeviceScreen] (used
  /// when opened from there as a guest), `false` to the [StartScreen].
  final bool returnToDeviceOnBack;

  const RegisterScreen({
    super.key,
    this.returnToDeviceOnBack = false,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // NOTE: First name, last name and the belt selection are collected in the
  // form but not used yet: registerWithEmail() only receives e-mail and
  // password.
  // TODO(improve): Save them (e.g. as `displayName` of the user and as a belt
  // entry) or remove the fields from the form.
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  /// Answer to the 'Gürtel' (belt) question of the form: 'NEIN' or 'JA'.
  /// Not used yet, see the note at the name controllers.
  String _selectedBelt = 'NEIN';

  /// Options of the belt dropdown.
  final List<String> _beltOptions = ['NEIN', 'JA'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the input, registers the user and replaces the whole navigation
  /// stack with the [DeviceScreen]. A [LoadingScreen] is shown meanwhile.
  ///
  /// The minimum password length of 6 matches the Firebase Auth minimum.
  ///
  /// TODO(improve): Same points as LoginScreen._finishLogin: `setState` before
  /// the `mounted` check, redundant `_isLoading` next to the [LoadingScreen],
  /// and one generic error message for every failure.
  Future<void> _finishRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Bitte E-Mail und Passwort eingeben.');
      return;
    }

    if (password.length < 6) {
      _showMessage('Das Passwort muss mindestens 6 Zeichen haben.');
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
          text: 'Konto wird erstellt...',
        ),
      ),
    );

    final user = await _authService.registerWithEmail(email, password);

    if (!mounted) return;

    Navigator.pop(context);

    setState(() {
      _isLoading = false;
    });

    if (user == null) {
      _showMessage('Registrierung fehlgeschlagen.');
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
  /// [StartScreen], depending on [RegisterScreen.returnToDeviceOnBack].
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
    // back button/gesture completely (see LoginScreen).
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: SafeArea(
          child: Column(
            children: [
              _RegisterTopBar(onBackPressed: _handleBack),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 12, 30, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konto erstellen',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Vorname',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RegisterTextField(
                        controller: _firstNameController,
                        hintText: 'Vorname',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nachname',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RegisterTextField(
                        controller: _lastNameController,
                        hintText: 'Nachname',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'E-Mail',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RegisterTextField(
                        controller: _emailController,
                        hintText: 'E-Mail',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Passwort',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RegisterTextField(
                        controller: _passwordController,
                        hintText: 'Passwort',
                        icon: Icons.lock_outline,
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
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Gürtel',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _BeltDropdown(
                        value: _selectedBelt,
                        items: _beltOptions,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedBelt = value;
                          });
                        },
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _finishRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: AppColors.onPrimary(context),
                            elevation: 3,
                            // TODO(improve): `withOpacity` is deprecated, use
                            // `withValues(alpha: ...)` (see LoginScreen).
                            shadowColor: Colors.black.withOpacity(0.22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.onPrimary(context),
                              strokeWidth: 3,
                            ),
                          )
                              : Text(
                            'Registrieren',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onPrimary(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Bereits ein Konto?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoginScreen(
                                  returnToDeviceOnBack:
                                  widget.returnToDeviceOnBack,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'Hier anmelden',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary(context),
                            ),
                          ),
                        ),
                      ),
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

/// Blue top bar with a back arrow and the title 'Registrieren'.
///
/// TODO(improve): Duplicate of the other screens' top bars, see
/// `_LoginTopBar`.
class _RegisterTopBar extends StatelessWidget {
  final VoidCallback onBackPressed;

  const _RegisterTopBar({
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
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
              size: 34,
            ),
          ),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(-18, 0),
                child: Text(
                  'Registrieren',
                  style: GoogleFonts.poppins(
                    fontSize: 25,
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
/// TODO(improve): Almost the same field exists as `_LoginTextField`; share one
/// widget.
class _RegisterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _RegisterTextField({
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
      height: 56,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text(context),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedText(context),
          ),
          prefixIcon: Icon(
            icon,
            color: AppColors.mutedText(context),
            size: 27,
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppColors.background(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: AppColors.inputBorder(context),
              width: 2,
            ),
          ),
          // TODO(improve): Same as `enabledBorder`, so there is no focus
          // feedback (see _LoginTextField).
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: AppColors.inputBorder(context),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown with the answers ('NEIN' / 'JA') to the belt question of the form.
class _BeltDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _BeltDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.inputBorder(context),
          width: 2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.text(context),
            size: 26,
          ),
          dropdownColor: AppColors.background(context),
          borderRadius: BorderRadius.circular(16),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}