// lib/features/auth/screens/register_screen.dart
//
// Registration form (name, e-mail, password, belt) that creates the account.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/auth_text_field.dart';
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

  /// NOTE: `late` on purpose. AuthService reaches for `FirebaseAuth.instance`
  /// in its own field initialisers, so building it eagerly would tie merely
  /// showing this screen to an initialised Firebase.
  late final AuthService _authService = AuthService();

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
    // NOTE: The password is not trimmed; spaces are valid password characters.
    final password = _passwordController.text;

    if (email.isEmpty || password.trim().isEmpty) {
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
    // `canPop: false` keeps the route, `onPopInvokedWithResult` routes the
    // system back button/gesture through the same handler as the arrow.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(title: 'Registrieren', onBackPressed: _handleBack),
              Expanded(
                // The form scrolls. It used to be squeezed onto one screen
                // instead, which forced small captions and short fields — the
                // opposite of what this app is for. Large, readable controls
                // win over a form that needs no scrolling; see §7 of
                // docs/PROJECT_CONTEXT.md.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: _buildForm(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The form: five labelled controls, the submit button and the link to the
  /// login.
  ///
  /// Nothing here has a fixed height and nothing caps the system font size.
  /// Every control grows with the text, and the scroll view takes care of the
  /// rest, so the form stays usable at any accessibility font setting.
  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Vorname'),
        const SizedBox(height: _captionGap),
        AuthTextField(
          controller: _firstNameController,
          label: 'Vorname',
          hintText: 'Vorname',
          icon: Icons.person_outline,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: _gapBetweenFields),

        const _FieldLabel('Nachname'),
        const SizedBox(height: _captionGap),
        AuthTextField(
          controller: _lastNameController,
          label: 'Nachname',
          hintText: 'Nachname',
          icon: Icons.person_outline,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: _gapBetweenFields),

        const _FieldLabel('E-Mail'),
        const SizedBox(height: _captionGap),
        AuthTextField(
          controller: _emailController,
          label: 'E-Mail',
          hintText: 'E-Mail',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: _gapBetweenFields),

        const _FieldLabel('Passwort'),
        const SizedBox(height: _captionGap),
        AuthTextField(
          controller: _passwordController,
          // The caption only says 'Passwort'; the rule lives in the placeholder,
          // and in the screen-reader label so it survives once the field has
          // content.
          label: 'Passwort, muss 6 Zeichen enthalten',
          hintText: 'Passwort muss 6 Zeichen enthalten',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _finishRegister(),
          suffixIcon: IconButton(
            tooltip:
                _obscurePassword ? 'Passwort anzeigen' : 'Passwort verbergen',
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
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: _gapBetweenFields),

        const _FieldLabel('Gürtel'),
        const SizedBox(height: _captionGap),
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

        const SizedBox(height: _gapBeforeSubmit),
        ElevatedButton(
          onPressed: _isLoading ? null : _finishRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary(context),
            foregroundColor: AppColors.onPrimary(context),
            disabledBackgroundColor: AppColors.inactiveButton(context),
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            minimumSize: const Size(double.infinity, _submitHeight),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.onPrimary(context),
                    strokeWidth: 3,
                  ),
                )
              : Text(
                  'Registrieren',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary(context),
                  ),
                ),
        ),
        const SizedBox(height: _gapBeforeLabel),
        // Plain label: not a control, so it stays in the normal text colour and
        // does not react to taps.
        Text(
          'Bereits ein Konto?',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: _labelFontSize,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 4),
        // Only this part is the control, so it carries the accent colour.
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LoginScreen(
                  returnToDeviceOnBack: widget.returnToDeviceOnBack,
                ),
              ),
            );
          },
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, _linkHeight),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          child: Text(
            'Hier anmelden',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bold caption above a form control.
///
/// Hidden from the semantics tree: the control below carries the same text as
/// its own (invisible) screen-reader label, and announcing it twice is noise.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: _captionFontSize,
          fontWeight: FontWeight.w800,
          color: AppColors.text(context),
          height: 1.25,
        ),
      ),
    );
  }
}

// ── Layout constants of the registration form ────────────────────────────────
//
// Sizes are generous on purpose: this app is built for people with impaired
// vision, so the controls have to be large and the captions easy to read. The
// form scrolls, so nothing has to be traded away for that.

/// Gap between one control and the caption of the next.
const double _gapBetweenFields = 22;

/// Gap between a caption and the control it labels.
const double _captionGap = 8;

/// Font size of the black caption above a control.
const double _captionFontSize = 23;

const double _gapBeforeSubmit = 32;
const double _gapBeforeLabel = 18;
const double _submitHeight = 78;
const double _linkHeight = 56;
const double _labelFontSize = 20;

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
    final textStyle = GoogleFonts.poppins(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      color: AppColors.text(context),
    );

    return Semantics(
      label: 'Gürtel vorhanden',
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.inputBorder(context),
            width: 2.2,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.text(context),
              size: 34,
            ),
            dropdownColor: AppColors.background(context),
            borderRadius: BorderRadius.circular(16),
            style: textStyle,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: textStyle),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
