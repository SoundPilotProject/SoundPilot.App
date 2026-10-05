// lib/core/widgets/google_logo.dart
//
// The official four-colour Google "G", drawn as vector paths.

import 'package:flutter/material.dart';

/// The four brand colours of the Google logo.
///
/// Deliberately not in `AppColors`: they belong to a foreign brand and must
/// not change with the app theme, so they are not part of the app palette.
const Color _googleBlue = Color(0xFF4285F4);
const Color _googleGreen = Color(0xFF34A853);
const Color _googleYellow = Color(0xFFFBBC05);
const Color _googleRed = Color(0xFFEA4335);

/// The official Google "G" logo in its four brand colours.
///
/// Drawn with [CustomPaint] instead of an image asset, so it stays sharp at
/// every size and at every system font setting. The paths are Google's
/// official sign-in mark in an 18x18 coordinate space, scaled to [size].
///
/// NOTE: Decoration. Callers put it next to a text label that carries the
/// meaning, so the logo is excluded from the semantics tree here — a screen
/// reader must not announce it twice. Google's branding guidelines ask for the
/// logo on a white or very light surface, which is why [GoogleSignInButton]
/// puts it on a white circle in both themes.
class GoogleLogo extends StatelessWidget {
  /// Width and height of the logo in logical pixels.
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GoogleLogoPainter()),
      ),
    );
  }
}

/// Paints the Google "G" from its four official paths.
///
/// The paths are the ones of Google's sign-in mark, given in an 18x18 box and
/// scaled to the canvas. Each of the four arcs is one path:
/// blue (right side and the bar), green (bottom), yellow (left) and red (top).
class _GoogleLogoPainter extends CustomPainter {
  /// Side length of the coordinate space the paths are written in.
  static const double _viewBox = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    canvas.save();
    canvas.scale(scale, scale);

    _fill(canvas, _bluePath(), _googleBlue);
    _fill(canvas, _greenPath(), _googleGreen);
    _fill(canvas, _yellowPath(), _googleYellow);
    _fill(canvas, _redPath(), _googleRed);

    canvas.restore();
  }

  void _fill(Canvas canvas, Path path, Color color) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  /// Right side of the ring plus the horizontal bar.
  Path _bluePath() {
    return Path()
      ..moveTo(17.64, 9.2)
      ..relativeCubicTo(0, -0.637, -0.057, -1.251, -0.164, -1.84)
      ..lineTo(9, 7.36)
      ..relativeLineTo(0, 3.481)
      ..relativeLineTo(4.844, 0)
      ..relativeCubicTo(-0.209, 1.125, -0.843, 2.078, -1.796, 2.717)
      ..relativeLineTo(0, 2.258)
      ..relativeLineTo(2.908, 0)
      ..relativeCubicTo(1.702, -1.567, 2.684, -3.874, 2.684, -6.615)
      ..close();
  }

  /// Bottom of the ring.
  Path _greenPath() {
    return Path()
      ..moveTo(9, 18)
      ..relativeCubicTo(2.43, 0, 4.467, -0.806, 5.956, -2.18)
      ..lineTo(12.048, 13.56)
      ..relativeCubicTo(-0.806, 0.54, -1.836, 0.86, -3.048, 0.86)
      ..relativeCubicTo(-2.344, 0, -4.328, -1.584, -5.036, -3.711)
      ..lineTo(0.957, 10.709)
      ..relativeLineTo(0, 2.332)
      ..cubicTo(2.438, 15.983, 5.482, 18, 9, 18)
      ..close();
  }

  /// Left side of the ring.
  Path _yellowPath() {
    return Path()
      ..moveTo(3.964, 10.71)
      ..relativeCubicTo(-0.18, -0.54, -0.282, -1.117, -0.282, -1.71)
      // Smooth continuation of the curve above: the first control point is the
      // mirror of the previous one, so the two halves meet without a kink.
      ..relativeCubicTo(0, -0.593, 0.102, -1.17, 0.282, -1.71)
      ..lineTo(3.964, 4.958)
      ..lineTo(0.957, 4.958)
      ..cubicTo(0.347, 6.173, 0, 7.548, 0, 9)
      ..relativeCubicTo(0, 1.452, 0.348, 2.827, 0.957, 4.042)
      ..relativeLineTo(3.007, -2.332)
      ..close();
  }

  /// Top of the ring.
  Path _redPath() {
    return Path()
      ..moveTo(9, 3.58)
      ..relativeCubicTo(1.321, 0, 2.508, 0.454, 3.44, 1.345)
      ..relativeLineTo(2.582, -2.58)
      ..cubicTo(13.463, 0.891, 11.426, 0, 9, 0)
      ..cubicTo(5.482, 0, 2.438, 2.017, 0.957, 4.958)
      ..lineTo(3.964, 7.29)
      ..cubicTo(4.672, 5.163, 6.656, 3.58, 9, 3.58)
      ..close();
  }

  // The logo never changes, so a repaint is never needed.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
