// lib/features/auth/screens/password_reset_screen.dart
//
// Own step for the password reset: one e-mail field, one button, and a result
// that stays on screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/auth_text_field.dart';
import '../auth_service.dart';

/// Screen that sends a password reset e-mail.
///
/// Opened by "Passwort vergessen?" on the LoginScreen, which passes the
/// address already typed there as [initialEmail].
///
/// Accessibility notes:
/// - One main action: the button sends the link; after a successful request
///   it turns into "Zurück zur Anmeldung".
/// - The result is text on the screen, not a SnackBar, so it stays until the
///   user leaves or changes the address (no time limit). It carries an icon
///   besides the text and is a live region, so screen readers announce it.
/// - While the request runs, the button is disabled and says so in text.
class PasswordResetScreen extends StatefulWidget {
  /// Address to pre-fill, usually what was typed on the login screen.
  final String initialEmail;

  /// Sends the reset e-mail and returns `null` or a German error message, like
  /// [AuthService.sendPasswordReset]. Defaults to that method.
  ///
  /// NOTE: Only meant for tests, so the screen can be pumped without Firebase.
  final Future<String?> Function(String email)? sendReset;

  const PasswordResetScreen({
    super.key,
    this.initialEmail = '',
    this.sendReset,
  });

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

/// Outcome of the last request, shown below the field.
enum _ResetStatus { none, sent, error }

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);

  /// NOTE: `late` on purpose, as on the LoginScreen: building AuthService
  /// touches `FirebaseAuth.instance`.
  late final AuthService _authService = AuthService();

  bool _isSending = false;
  _ResetStatus _status = _ResetStatus.none;
  String _message = '';

  /// The address the last successful request went to.
  String? _sentTo;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  /// A changed address makes the old result wrong, so it is cleared and the
  /// button offers to send again.
  void _onEmailChanged() {
    if (_status == _ResetStatus.none) return;
    if (_status == _ResetStatus.sent &&
        _emailController.text.trim() == _sentTo) {
      return;
    }
    setState(() {
      _status = _ResetStatus.none;
      _message = '';
      _sentTo = null;
    });
  }

  /// Validates the address and requests the reset e-mail.
  Future<void> _send() async {
    if (_isSending) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _status = _ResetStatus.error;
        _message = 'Bitte gib deine E-Mail-Adresse ein.';
      });
      return;
    }

    setState(() => _isSending = true);

    final send = widget.sendReset ?? _authService.sendPasswordReset;
    final error = await send(email);

    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (error == null) {
        _status = _ResetStatus.sent;
        _message = AuthService.passwordResetSentMessage;
        _sentTo = email;
      } else {
        _status = _ResetStatus.error;
        _message = error;
      }
    });
  }

  /// Closes this screen and returns to the LoginScreen.
  void _handleBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final sent = _status == _ResetStatus.sent;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(title: 'Passwort zurücksetzen', onBackPressed: _handleBack),
            Expanded(
              // Scrollable so the form stays reachable above the keyboard and
              // at large system font sizes.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Passwort vergessen?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Gib deine E-Mail-Adresse ein. Wir schicken dir einen '
                      'Link, mit dem du ein neues Passwort festlegen kannst.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ExcludeSemantics(
                      child: Text(
                        'E-Mail:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AuthTextField(
                      controller: _emailController,
                      label: 'E-Mail',
                      hintText: 'E-Mail',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                    if (_status != _ResetStatus.none) ...[
                      const SizedBox(height: 20),
                      _StatusBox(sent: sent, message: _message),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isSending
                          ? null
                          : sent
                              ? _handleBack
                              : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        foregroundColor: AppColors.onPrimary(context),
                        disabledBackgroundColor:
                            AppColors.inactiveButton(context),
                        disabledForegroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: Colors.black.withValues(alpha: 0.20),
                        minimumSize: const Size(double.infinity, 80),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: _isSending
                          ? const _SendingLabel()
                          : Text(
                              sent ? 'Zurück zur Anmeldung' : 'Link senden',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onPrimary(context),
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
    );
  }
}

/// Result of the last request: icon plus text, so the state is not carried
/// by colour alone. A live region, so screen readers read it out when it
/// appears or changes.
class _StatusBox extends StatelessWidget {
  final bool sent;
  final String message;

  const _StatusBox({required this.sent, required this.message});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.inputBorder(context), width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The text says everything; the icon is a second visual cue.
            ExcludeSemantics(
              child: Icon(
                sent ? Icons.mark_email_read_outlined : Icons.error_outline,
                color: textColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Button content while the request runs: "Wird gesendet..." with a spinner,
/// or without it if the system asks for reduced animations.
class _SendingLabel extends StatelessWidget {
  const _SendingLabel();

  @override
  Widget build(BuildContext context) {
    // White on the inactive button is the pair the contrast test measures.
    const color = Colors.white;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!reduceMotion) ...[
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(color: color, strokeWidth: 3),
          ),
          const SizedBox(width: 14),
        ],
        Flexible(
          child: Text(
            'Wird gesendet...',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
