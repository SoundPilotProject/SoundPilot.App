// lib/features/device/screens/belt_vibration_screen.dart
//
// Belt setup, step 2: vibration strength and side.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../widgets/belt_setup_fields.dart';

/// Second step of the belt setup (after `BeltWarningDistanceScreen`): the user
/// enters the vibration strength in % (recommended 60–100 %) and picks a side
/// ('L', 'M' or 'R').
///
/// Pops with `true` when the setup is finished.
///
/// TODO(improve): The entered strength and the selected side are neither
/// validated nor saved. `_finishSetup` only pops `true`. The
/// strength should be checked (0–100) and stored with the belt entry.
///
/// NOTE: The heading above the side buttons used to read 'SUCHE GURT...'
/// although no search happens here; it now names what the buttons do.
class BeltVibrationScreen extends StatefulWidget {
  const BeltVibrationScreen({super.key});

  @override
  State<BeltVibrationScreen> createState() => _BeltVibrationScreenState();
}

class _BeltVibrationScreenState extends State<BeltVibrationScreen> {
  final TextEditingController _strengthController =
      TextEditingController(text: '100');

  /// Selected side: one of 'L', 'M' or 'R'.
  String _selectedSide = 'M';

  /// Long names of the sides, used for the button labels and for the
  /// screen-reader announcement.
  static const Map<String, String> _sideNames = {
    'L': 'Links',
    'M': 'Mitte',
    'R': 'Rechts',
  };

  @override
  void dispose() {
    _strengthController.dispose();
    super.dispose();
  }

  /// Pops back with `true` (setup done).
  void _finishSetup() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Vibrationen',
              onBackPressed: () => Navigator.pop(context),
            ),
            Expanded(
              // Scrollable: the side buttons plus the keyboard need more room
              // than a small phone offers.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const RecommendationCard(text: 'Empfehlung\n60 – 100 %'),
                    const SizedBox(height: 26),
                    Semantics(
                      header: true,
                      child: Text(
                        'Stärke in %',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text(context),
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    BeltNumberField(
                      controller: _strengthController,
                      label: 'Vibrationsstärke in Prozent',
                      suffix: '%',
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      child: Text(
                        'Seite der Vibration',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text(context),
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final side in _sideNames.keys) ...[
                          if (side != 'L') const SizedBox(width: 12),
                          Expanded(
                            child: _SideButton(
                              label: _sideNames[side]!,
                              selected: _selectedSide == side,
                              onTap: () {
                                setState(() {
                                  _selectedSide = side;
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 36),
                    ElevatedButton(
                      onPressed: _finishSetup,
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
                        'Abschließen',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimary(context),
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

/// Large toggle button for one side ('Links', 'Mitte' or 'Rechts').
///
/// The selected state is not shown by colour alone: the selected button also
/// carries a check mark and is announced as selected by screen readers.
class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        selected ? AppColors.primary(context) : AppColors.surface(context);
    final textColor =
        selected ? AppColors.onPrimary(context) : AppColors.text(context);

    return Semantics(
      selected: selected,
      button: true,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          minimumSize: const Size(0, 84),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: selected
                  ? AppColors.primary(context)
                  : AppColors.legendBorder(context),
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 24,
              color: textColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
