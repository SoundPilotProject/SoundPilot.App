// lib/features/device/screens/belt_warning_distance_screen.dart
//
// Belt setup, step 1: warning distance.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../models/user_model.dart';
import '../widgets/belt_setup_fields.dart';
import 'belt_vibration_screen.dart';

/// First step of the belt setup: the user enters the warning distance in cm
/// (recommended 200–500 cm, allowed [BeltCalib.minWarningDistanceCm] to
/// [BeltCalib.maxWarningDistanceCm]), then continues to the
/// [BeltVibrationScreen].
///
/// Starts with the values of [belt]. Pops with the edited [BeltCalib] once the
/// second step was finished; going back pops with null, so nothing is saved.
class BeltWarningDistanceScreen extends StatefulWidget {
  /// The belt as it is stored.
  final BeltCalib belt;

  const BeltWarningDistanceScreen({super.key, required this.belt});

  @override
  State<BeltWarningDistanceScreen> createState() =>
      _BeltWarningDistanceScreenState();
}

class _BeltWarningDistanceScreenState extends State<BeltWarningDistanceScreen> {
  late final TextEditingController _distanceController =
      TextEditingController(text: '${widget.belt.warningDistanceCm}');

  /// Shown below the field while the typed distance is not allowed.
  String? _error;

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  /// Checks the distance and opens the [BeltVibrationScreen] with it; if that
  /// step was finished, this screen pops with its result as well.
  Future<void> _goToNextScreen() async {
    final distance = parseBeltValue(
      _distanceController.text,
      min: BeltCalib.minWarningDistanceCm,
      max: BeltCalib.maxWarningDistanceCm,
    );
    if (distance == null) {
      setState(() {
        _error = beltValueError(
          min: BeltCalib.minWarningDistanceCm,
          max: BeltCalib.maxWarningDistanceCm,
          unit: 'cm',
        );
      });
      return;
    }

    final result = await Navigator.push<BeltCalib>(
      context,
      MaterialPageRoute(
        builder: (_) => BeltVibrationScreen(
          belt: widget.belt.copyWith(warningDistanceCm: distance),
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      Navigator.pop(context, result);
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
                              onChanged: (_) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              BeltFieldError(text: _error!),
                            ],
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
