import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SoundPilotLogo extends StatelessWidget {
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