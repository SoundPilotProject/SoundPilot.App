// lib/features/device/screens/belt_warning_distance_screen.dart
//
// Belt setup, step 1: warning distance.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../widgets/belt_setup_fields.dart';
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
            AppTopBar(
              title: 'Warnentfernung',
              onBackPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Scrollable so the number keyboard cannot push the content
                  // into an overflow.
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 46,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const RecommendationCard(
                              text: 'Empfehlung\n200 – 500 cm',
                            ),
                            const SizedBox(height: 30),
                            Semantics(
                              header: true,
                              child: Text(
                                'Distanz in cm',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.text(context),
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            BeltNumberField(
                              controller: _distanceController,
                              label: 'Warnentfernung in Zentimetern',
                              suffix: 'cm',
                            ),
                            const SizedBox(height: 30),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: _goToNextScreen,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(context),
                                foregroundColor: AppColors.onPrimary(context),
                                elevation: 4,
                                minimumSize: const Size(double.infinity, 76),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(42),
                                ),
                              ),
                              child: Text(
                                'Weiter',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
