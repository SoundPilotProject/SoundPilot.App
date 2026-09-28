// lib/core/widgets/auth_text_field.dart
//
// Shared rounded text field of the login and registration forms.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Rounded text field with a leading [icon] and an optional [suffixIcon]
/// (used for the password visibility toggle).
///
/// Replaces the former `_LoginTextField` / `_RegisterTextField` duplicates.
///
/// Accessibility notes:
/// - [label] is passed to the field as its screen-reader label, so TalkBack and
///   VoiceOver announce what has to be typed in.
/// - The field has no fixed height. Its height follows the content padding and
///   the system font size, so large text is never clipped.
/// - A focused field gets a thicker border in the accent colour, which is the
///   focus feedback the two old fields were missing.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;

  /// Screen-reader label of the field (e.g. 'E-Mail').
  final String label;

  /// Placeholder shown while the field is empty.
  final String hintText;

  /// Icon in front of the input.
  final IconData icon;

  /// Optional trailing widget, e.g. the password visibility toggle.
  final Widget? suffixIcon;

  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// If `true`, [label] is drawn inside the field and floats up once the field
  /// has content, instead of being invisible.
  ///
  /// Use this where the screen has no room for a separate caption above the
  /// field (the registration form, which must fit on one screen). The caller
  /// then must not render its own caption, or the label is announced twice.
  final bool showLabel;

  /// Smaller vertical padding, for forms that have to fit on one screen.
  final bool compact;

  /// Set this when the field's height comes from outside — e.g. because the
  /// caller wraps it in an [Expanded] to share out the available height, as the
  /// registration form does.
  ///
  /// It only shrinks the vertical content padding: with the height fixed from
  /// outside, a large padding has nothing left to give at big system font sizes
  /// and the decoration overflows inside the box.
  final bool stretch;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.showLabel = false,
    this.compact = false,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    final fontSize = compact ? 18.0 : 21.0;
    final mutedText = AppColors.mutedText(context);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: AppColors.text(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        // Without [showLabel] the visible caption sits above the field, so the
        // label is only needed by screen readers and stays hidden.
        floatingLabelBehavior:
            showLabel ? FloatingLabelBehavior.auto : FloatingLabelBehavior.never,
        // Only show the placeholder where it is not competing with a visible
        // label inside the field.
        hintText: showLabel ? null : hintText,
        // NOTE: The placeholder and the label inside the box stay at w600 on
        // purpose, while the typed text above is bold. That is what separates
        // "not filled in yet" from "this is your input" at a glance. Everything
        // else in the app is bold; do not make these two bold as well.
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: mutedText,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: mutedText,
        ),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: AppColors.primary(context),
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: compact ? 12 : 14, right: 10),
          child: Icon(icon, color: mutedText, size: compact ? 26 : 30),
        ),
        prefixIconConstraints: BoxConstraints(
          minWidth: compact ? 50 : 56,
          minHeight: compact ? 48 : 56,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.background(context),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: stretch
              ? 6
              : compact
                  ? 14
                  : 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: AppColors.inputBorder(context),
            width: 2.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: AppColors.primary(context),
            width: 3.5,
          ),
        ),
      ),
    );
  }
}
