import 'package:flutter/material.dart';

class AppColors {
  // Light Mode
  static const Color _backgroundLight = Color(0xFFE5E7EB);
  static const Color _primaryLight = Color(0xFF2F49B7);
  static const Color _textLight = Colors.black;
  static const Color _surfaceLight = Color(0xFFD1D5DB);
  static const Color _inputBorderLight = Color(0xFF4F596D);
  static const Color _mutedTextLight = Color(0xFF6B788C);
  static const Color _inactiveButtonLight = Color(0xFF7A8496);
  static const Color _legendBgLight = Color(0x66FFFFFF);
  static const Color _legendBorderLight = Color(0xFF9FA8B6);

  // Dark Mode
  static const Color _backgroundDark = Color(0xFF000000);
  static const Color _primaryDark = Color(0xFFF2E38A);
  static const Color _textDark = Colors.white;
  static const Color _surfaceDark = Color(0xFF1A1A1A);
  static const Color _inputBorderDark = Color(0xFFF2E38A);
  static const Color _mutedTextDark = Color(0xFFE6D98A);
  static const Color _inactiveButtonDark = Color(0xFF7A8496);
  static const Color _legendBgDark = Color(0xFF111111);
  static const Color _legendBorderDark = Color(0xFFF2E38A);

  static const Color connectedGreen = Color(0xFF18D64D);
  static const Color disconnectedRed = Color(0xFFFF3636);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? _backgroundDark : _backgroundLight;

  static Color primary(BuildContext context) =>
      isDark(context) ? _primaryDark : _primaryLight;

  static Color text(BuildContext context) =>
      isDark(context) ? _textDark : _textLight;

  static Color onPrimary(BuildContext context) =>
      isDark(context) ? Colors.black : Colors.white;

  static Color surface(BuildContext context) =>
      isDark(context) ? _surfaceDark : _surfaceLight;

  static Color inputBorder(BuildContext context) =>
      isDark(context) ? _inputBorderDark : _inputBorderLight;

  static Color mutedText(BuildContext context) =>
      isDark(context) ? _mutedTextDark : _mutedTextLight;

  static Color inactiveButton(BuildContext context) =>
      _inactiveButtonDark;

  static Color legendBackground(BuildContext context) =>
      isDark(context) ? _legendBgDark : _legendBgLight;

  static Color legendBorder(BuildContext context) =>
      isDark(context) ? _legendBorderDark : _legendBorderLight;
}