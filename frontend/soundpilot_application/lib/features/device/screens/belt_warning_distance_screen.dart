// lib/features/device/screens/belt_warning_distance_screen.dart
//
// Belt setup, step 1: warning distance.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'belt_vibration_screen.dart';

/// First step of the belt setup: the user enters the warning distance in cm
/// (recommended 200–500 cm, default 200), then continues to the
/// [BeltVibrationScreen].
///
/// Pops with `true` once the second step was finished.
///
/// TODO(improve): The entered distance is neither validated nor saved or passed
/// on to the next step. It should be checked (numeric, sensible range) and
/// stored with the belt entry.
class BeltWarningDistanceScreen extends StatefulWidget {
  const BeltWarningDistanceScreen({super.key});

  @override
  State<BeltWarningDistanceScreen> createState() =>
      _BeltWarningDistanceScreenState();
}

class _BeltWarningDistanceScreenState extends State<BeltWarningDistanceScreen> {
  final TextEditingController _distanceController =
  TextEditingController(text: '200');

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  /// Opens the [BeltVibrationScreen]; if that step was finished (`true`), this
  /// screen pops with `true` as well.
  Future<void> _goToNextScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const BeltVibrationScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onBackPressed: () {
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 34,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            // TODO(improve): `withOpacity` is deprecated, use
                            // `withValues(alpha: ...)` (see LoginScreen).
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'EMPFEHLUNG\n200-500 CM',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text(context),
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'DISTANZ IN CM',
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(context),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.inputBorder(context),
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: _distanceController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 20,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 78,
                      child: ElevatedButton(
                        onPressed: _goToNextScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          foregroundColor: AppColors.onPrimary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(42),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          'WEITER',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary(context),
                          ),
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

/// Blue top bar with a back arrow and the title 'WARNENTFERNUNG'.
///
/// TODO(improve): Duplicate of the other screens' top bars, see
/// `_LoginTopBar`.
class _TopBar extends StatelessWidget {
  final VoidCallback onBackPressed;

  const _TopBar({
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      width: double.infinity,
      color: AppColors.primary(context),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackPressed,
            splashRadius: 24,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.onPrimary(context),
              size: 36,
            ),
          ),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(-18, 0),
                child: Text(
                  'WARNENTFERNUNG',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}