// lib/core/theme/app_colors.dart
//
// Central colour palette. Every colour is resolved through the current
// brightness (light/dark) of the BuildContext.

import 'package:flutter/material.dart';

/// Colour palette of the app for light and dark mode.
///
/// Usage: `AppColors.primary(context)`. The private constants hold the raw
/// values, the static methods pick the right one for the current theme.
///
/// TODO(improve): Some screens still hard-code colours (TestPage uses
/// `0xFFFF0000`, `0xFF121212` and `0xFFF2E38A`). Move them here so the whole
/// palette lives in one place.
///
/// TODO(improve): The class only has static members, so a private constructor
/// (`AppColors._()`) would prevent accidental instances. A ColorScheme or
/// ThemeExtension would let Material widgets use the palette as well (see
/// SoundPilotApp).
class AppColors {
  // ── Light mode ─────────────────────────────────────────────────────────────
  static const Color _backgroundLight = Color(0xFFE5E7EB);
  static const Color _primaryLight = Color(0xFF2F49B7);
  static const Color _textLight = Colors.black;
  static const Color _surfaceLight = Color(0xFFD1D5DB);
  static const Color _inputBorderLight = Color(0xFF4F596D);
  static const Color _mutedTextLight = Color(0xFF6B788C);
  static const Color _legendBgLight = Color(0x66FFFFFF);
  static const Color _legendBorderLight = Color(0xFF9FA8B6);

  // ── Dark mode ──────────────────────────────────────────────────────────────
  static const Color _backgroundDark = Color(0xFF000000);
  static const Color _primaryDark = Color(0xFFF2E38A);
  static const Color _textDark = Colors.white;
  static const Color _surfaceDark = Color(0xFF1A1A1A);
  static const Color _inputBorderDark = Color(0xFFF2E38A);
  static const Color _mutedTextDark = Color(0xFFE6D98A);
  static const Color _inactiveButtonDark = Color(0xFF7A8496);
  static const Color _legendBgDark = Color(0xFF111111);
  static const Color _legendBorderDark = Color(0xFFF2E38A);

  // ── Status colours (same in light and dark mode) ───────────────────────────

  /// Dot colour of a connected device.
  static const Color connectedGreen = Color(0xFF18D64D);

  /// Dot colour of a device that is not connected.
  static const Color disconnectedRed = Color(0xFFFF3636);

  // ── Resolvers ──────────────────────────────────────────────────────────────

  /// True if the current theme is the dark theme.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Screen background.
  static Color background(BuildContext context) =>
      isDark(context) ? _backgroundDark : _backgroundLight;

  /// Main accent colour (buttons, top bars, cards).
  static Color primary(BuildContext context) =>
      isDark(context) ? _primaryDark : _primaryLight;

  /// Default text colour.
  static Color text(BuildContext context) =>
      isDark(context) ? _textDark : _textLight;

  /// Text/icon colour on top of [primary].
  static Color onPrimary(BuildContext context) =>
      isDark(context) ? Colors.black : Colors.white;

  /// Background of cards and input surfaces.
  static Color surface(BuildContext context) =>
      isDark(context) ? _surfaceDark : _surfaceLight;

  /// Border colour of text fields and selectors.
  static Color inputBorder(BuildContext context) =>
      isDark(context) ? _inputBorderDark : _inputBorderLight;

  /// Secondary text (hints, placeholders, inactive labels).
  static Color mutedText(BuildContext context) =>
      isDark(context) ? _mutedTextDark : _mutedTextLight;

  /// Background of a disabled/inactive button.
  ///
  /// NOTE: Returns the same colour in light and dark mode, [context] is unused.
  /// TODO(improve): Add a light-mode value and switch on [isDark].
  static Color inactiveButton(BuildContext context) => _inactiveButtonDark;

  /// Background of the legend box (semi-transparent white in light mode).
  static Color legendBackground(BuildContext context) =>
      isDark(context) ? _legendBgDark : _legendBgLight;

  /// Border of the legend box.
  static Color legendBorder(BuildContext context) =>
      isDark(context) ? _legendBorderDark : _legendBorderLight;
}
