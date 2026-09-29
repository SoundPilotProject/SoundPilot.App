// test/color_contrast_test.dart
//
// Enforces the WCAG 2.1 AA contrast requirement from docs/PROJECT_CONTEXT.md
// §1 on the palette in `core/theme/app_colors.dart`, in light and dark mode.
//
// Thresholds: 4.5:1 for normal text, 3:1 for large text, icons, borders and
// other non-text parts of a control (WCAG 1.4.3 and 1.4.11).
//
// If a colour change makes this fail, change the colour — do not lower the
// threshold. Accessibility is the core requirement of the project.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundpilot_application/core/theme/app_colors.dart';

/// Relative luminance of [color] as defined by WCAG 2.1.
double _luminance(Color color) {
  double channel(double component) {
    return component <= 0.03928
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Contrast ratio between [a] and [b], from 1.0 (equal) to 21.0 (black/white).
///
/// Both colours must be opaque; blend translucent ones with [_over] first.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Composites the possibly translucent [fg] over the opaque [bg].
Color _over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

/// Builds a BuildContext that carries the theme for [brightness].
Future<BuildContext> _contextFor(
  WidgetTester tester,
  Brightness brightness,
) async {
  late BuildContext captured;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Builder(builder: (context) {
      captured = context;
      return const SizedBox();
    }),
  ));
  return captured;
}

void main() {
  for (final brightness in Brightness.values) {
    group('Palette meets WCAG AA – $brightness', () {
      testWidgets('text colours reach 4.5:1', (tester) async {
        final context = await _contextFor(tester, brightness);

        final background = AppColors.background(context);
        final surface = AppColors.surface(context);
        final legendBg = _over(AppColors.legendBackground(context), background);

        void expectText(String what, Color fg, Color bg) {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$what ($brightness)',
          );
        }

        expectText('text on background', AppColors.text(context), background);
        expectText('text on surface', AppColors.text(context), surface);
        expectText('text on legend background',
            AppColors.text(context), legendBg);

        // mutedText is used on all three surfaces: hints in filled fields, the
        // info box in the add-device dialog and the empty device list.
        expectText('mutedText on background',
            AppColors.mutedText(context), background);
        expectText(
            'mutedText on surface', AppColors.mutedText(context), surface);
        expectText(
            'mutedText on legend background',
            AppColors.mutedText(context),
            legendBg);

        // primary is used as link/label text directly on the background.
        expectText(
            'primary as link text', AppColors.primary(context), background);

        expectText('onPrimary on primary',
            AppColors.onPrimary(context), AppColors.primary(context));

        // Disabled buttons are exempt from WCAG, but this app is built for
        // visually impaired users, so they have to be readable as well.
        expectText('white on inactive button',
            Colors.white, AppColors.inactiveButton(context));
        expectText('white on the active Stop button',
            Colors.white, AppColors.stopRed);
      });

      testWidgets('non-text parts reach 3:1', (tester) async {
        final context = await _contextFor(tester, brightness);

        final background = AppColors.background(context);
        final surface = AppColors.surface(context);
        final legendBg = _over(AppColors.legendBackground(context), background);

        void expectNonText(String what, Color fg, Color bg) {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(3.0),
            reason: '$what ($brightness)',
          );
        }

        expectNonText('input border on background',
            AppColors.inputBorder(context), background);
        expectNonText(
            'input border on surface', AppColors.inputBorder(context), surface);
        expectNonText(
            'focus ring on background', AppColors.primary(context), background);
        expectNonText('legend border on legend background',
            AppColors.legendBorder(context), legendBg);

        // The check/cross drawn inside the status dots.
        expectNonText(
            'icon inside the connected dot', Colors.white, AppColors.connectedGreen);
        expectNonText('icon inside the disconnected dot', Colors.white,
            AppColors.disconnectedRed);

        // The dots themselves do not contrast with the coloured device card
        // (red on the blue card is 1.5:1), which is why StatusDot draws a ring
        // in onPrimary on the card and in the text colour in the legend. Those
        // rings are what has to separate the dot from its background.
        expectNonText('dot ring on the device card',
            AppColors.onPrimary(context), AppColors.primary(context));
        expectNonText(
            'dot ring in the legend', AppColors.text(context), legendBg);
      });
    });
  }
}
