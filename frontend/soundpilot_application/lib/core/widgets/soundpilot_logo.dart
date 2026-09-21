// lib/core/widgets/soundpilot_logo.dart
//
// The SoundPilot logo, switched by theme brightness.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// SoundPilot logo image with the given [width].
///
/// Uses the dark or light logo asset depending on the current theme. Both
/// assets are declared in pubspec.yaml.
class SoundPilotLogo extends StatelessWidget {
  /// Width of the image in logical pixels; the height follows the aspect ratio.
  final double width;

  const SoundPilotLogo({
    super.key,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Image.asset(
      isDark
          ? "assets/images/SoundPilotLogoDark.png"
          : "assets/images/SoundPilotLogoLight.png",
      width: width,
      fit: BoxFit.contain,
    );
  }
}
