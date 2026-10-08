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
/// The light-mode colours are tuned for WCAG AA (4.5:1) on top of
/// [background]; see `docs/ACCESSIBILITY_AUDIT.md`.
///
/// NOTE: SoundPilotApp builds the ColorScheme and the TextTheme of both themes
/// from this palette, so Material widgets that are not styled by hand follow it
/// as well.
class AppColors {
  /// Only static members; the private constructor prevents instances.
  AppColors._();

  // ── Light mode ─────────────────────────────────────────────────────────────

  /// Soft pastel grey, deliberately not pure white: it lowers the glare for
  /// light-sensitive users and lets white input fields stand out.
  static const Color _backgroundLight = Color(0xFFE4E7EE);
  static const Color _primaryLight = Color(0xFF2F49B7);
  static const Color _textLight = Colors.black;
  static const Color _surfaceLight = Color(0xFFD1D5DB);
  static const Color _inputBorderLight = Color(0xFF4F596D);

  /// 6.0:1 on [_backgroundLight] and 5.0:1 on the darker [_surfaceLight], which
  /// is the binding case (hints inside filled fields and info boxes).
  static const Color _mutedTextLight = Color(0xFF4C5666);

  /// 4.5:1 with the white label on top.
  static const Color _inactiveButtonLight = Color(0xFF6E7787);
  static const Color _legendBgLight = Color(0x66FFFFFF);

  /// 3.7:1 on [_legendBgLight] (the previous 0xFF9FA8B6 only reached 2.1:1).
  static const Color _legendBorderLight = Color(0xFF737D8D);

  // ── Dark mode ──────────────────────────────────────────────────────────────
  static const Color _backgroundDark = Color(0xFF000000);
  static const Color _primaryDark = Color(0xFFF2E38A);
  static const Color _textDark = Colors.white;
  static const Color _surfaceDark = Color(0xFF1A1A1A);
  static const Color _inputBorderDark = Color(0xFFF2E38A);
  static const Color _mutedTextDark = Color(0xFFE6D98A);

  /// 4.8:1 with the white label on top (the previous 0xFF7A8496 reached 3.8:1).
  static const Color _inactiveButtonDark = Color(0xFF6B7382);
  static const Color _legendBgDark = Color(0xFF111111);
  static const Color _waveCardDark = Color(0xFF121212);
  static const Color _legendBorderDark = Color(0xFFF2E38A);

  // ── Status colours ─────────────────────────────────────────────────────────

  /// Dot colour of a connected device.
  ///
  /// NOTE: The dots are always paired with an icon and a text label, so the
  /// state is never conveyed by colour alone (see `DeviceCard`).
  ///
  /// Darker than the former 0xFF18D64D: the white check mark inside the dot
  /// only reached 1.95:1 on that green, now 4.2:1.
  static const Color connectedGreen = Color(0xFF0E8F34);

  /// Dot colour of a device that is not connected, and background of the
  /// active 'Stop' button in the TestPage.
  ///
  /// Darker than the former 0xFFFF3636 so the white cross inside the dot
  /// reaches 5.3:1 instead of 3.6:1.
  static const Color disconnectedRed = Color(0xFFD32020);

  /// Background of the 'Stop' button in the TestPage while it is active.
  static const Color stopRed = disconnectedRed;

  // ── Resolvers ──────────────────────────────────────────────────────────────
  //
  // The colours the theme needs exist twice: a `…Of(Brightness)` variant that
  // SoundPilotApp uses to build the ThemeData (there is no themed
  // BuildContext yet at that point) and the `…(BuildContext)` variant that the
  // widgets use.

  /// True if the current theme is the dark theme.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Screen background.
  static Color backgroundOf(Brightness brightness) =>
      brightness == Brightness.dark ? _backgroundDark : _backgroundLight;

  static Color background(BuildContext context) =>
      backgroundOf(Theme.of(context).brightness);

  /// Main accent colour (buttons, top bars, cards).
  static Color primaryOf(Brightness brightness) =>
      brightness == Brightness.dark ? _primaryDark : _primaryLight;

  static Color primary(BuildContext context) =>
      primaryOf(Theme.of(context).brightness);

  /// Default text colour.
  static Color textOf(Brightness brightness) =>
      brightness == Brightness.dark ? _textDark : _textLight;

  static Color text(BuildContext context) =>
      textOf(Theme.of(context).brightness);

  /// Text/icon colour on top of [primary].
  static Color onPrimaryOf(Brightness brightness) =>
      brightness == Brightness.dark ? Colors.black : Colors.white;

  static Color onPrimary(BuildContext context) =>
      onPrimaryOf(Theme.of(context).brightness);

  /// Background of cards and input surfaces.
  static Color surfaceOf(Brightness brightness) =>
      brightness == Brightness.dark ? _surfaceDark : _surfaceLight;

  static Color surface(BuildContext context) =>
      surfaceOf(Theme.of(context).brightness);

  /// Border colour of text fields and selectors.
  static Color inputBorder(BuildContext context) =>
      isDark(context) ? _inputBorderDark : _inputBorderLight;

  /// Secondary text (hints, placeholders, inactive labels).
  static Color mutedText(BuildContext context) =>
      isDark(context) ? _mutedTextDark : _mutedTextLight;

  /// Background of a disabled/inactive button.
  static Color inactiveButton(BuildContext context) =>
      isDark(context) ? _inactiveButtonDark : _inactiveButtonLight;

  /// Background of the legend box (semi-transparent white in light mode).
  static Color legendBackground(BuildContext context) =>
      isDark(context) ? _legendBgDark : _legendBgLight;

  /// Border of the legend box.
  static Color legendBorder(BuildContext context) =>
      isDark(context) ? _legendBorderDark : _legendBorderLight;

  /// Card colour of the waveform box in the TestPage (darker than [surface] in
  /// dark mode so the bars stay visible).
  static Color waveCard(BuildContext context) =>
      isDark(context) ? _waveCardDark : _surfaceLight;
}
