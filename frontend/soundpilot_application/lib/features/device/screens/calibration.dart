// lib/features/device/screens/calibration.dart
//
// Left/right volume calibration for an earbud (two scroll wheels).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../core/services/calibration_service.dart';
import 'TestPage.dart';

/// Screen where the user sets the left and right volume (1–100) of an earbud.
///
/// The values are saved through [CalibrationService] and passed to the
/// [TestPage]. The screen pops with `true` once the test exercise was finished.
///
/// TODO(improve): The volumes are not tied to a device. The screen takes no
/// device key and only returns `true`, so `HeadphoneCalib.volumeLeft` /
/// `volumeRight` are never set and every earbud shares one calibration (stored
/// per user in [CalibrationService]). Pass the device key (BD_ADDR) in and
/// save the values per device (e.g. `calibration.headphones.<BD_ADDR>.volLeft`).
///
/// TODO(improve): Rename the file to `calibration_screen.dart` so it matches
/// the class name (same for `TestPage.dart` -> `test_page.dart`).
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  /// Currently selected volumes (default 50, replaced by the saved values).
  int _leftVolume = 50;
  int _rightVolume = 50;

  /// True until the saved calibration has been loaded.
  bool _isLoading = true;

  late FixedExtentScrollController _leftController;
  late FixedExtentScrollController _rightController;

  /// Selectable volumes 1..100 (wheel item index = value - 1).
  final List<int> _values = List.generate(100, (index) => index + 1);

  @override
  void initState() {
    super.initState();
    // Temporary controllers — replaced after data loads
    _leftController = FixedExtentScrollController(initialItem: 49);
    _rightController = FixedExtentScrollController(initialItem: 49);
    _loadSavedCalibration();
  }

  /// Loads the saved values and rebuilds the wheel controllers with them as
  /// the initial item.
  Future<void> _loadSavedCalibration() async {
    final data = await CalibrationService.load();

    if (!mounted) return;

    // Dispose old controllers before replacing them
    _leftController.dispose();
    _rightController.dispose();

    setState(() {
      _leftVolume = data.leftVolume;
      _rightVolume = data.rightVolume;
      _leftController =
          FixedExtentScrollController(initialItem: data.leftVolume - 1);
      _rightController =
          FixedExtentScrollController(initialItem: data.rightVolume - 1);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  /// Saves the current values and opens the [TestPage]. If the test was
  /// finished (`true`), this screen pops with `true` as well.
  Future<void> _openTestPage() async {
    // Save current values before opening the test page so TestPage
    // can read them.
    await CalibrationService.save(
      CalibrationData(leftVolume: _leftVolume, rightVolume: _rightVolume),
    );

    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TestPage(
          leftVolume: _leftVolume,
          rightVolume: _rightVolume,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen(text: 'Kalibrierung wird geladen...');
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _CalibrationTopBar(
              onBackPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linke Seite:',
                      style: GoogleFonts.poppins(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(context),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _VolumeSection(
                        label: 'Lautstärke:',
                        selectedValue: _leftVolume,
                        values: _values,
                        controller: _leftController,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _leftVolume = _values[index];
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Rechte Seite:',
                      style: GoogleFonts.poppins(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(context),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _VolumeSection(
                        label: 'Lautstärke:',
                        selectedValue: _rightVolume,
                        values: _values,
                        controller: _rightController,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _rightVolume = _values[index];
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 82,
                      child: ElevatedButton(
                        onPressed: _openTestPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          foregroundColor: AppColors.onPrimary(context),
                          elevation: 4,
                          // TODO(improve): `withOpacity` is deprecated, use
                          // `withValues(alpha: ...)` (see LoginScreen).
                          shadowColor: Colors.black.withOpacity(0.18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: Text(
                          'Test-Übung',
                          style: GoogleFonts.poppins(
                            fontSize: 27,
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

// ── Top Bar ──────────────────────────────────────────────────────────────────

/// Blue top bar with a back arrow and the title 'Kalibrierung'.
///
/// TODO(improve): Duplicate of the other screens' top bars, see
/// `_LoginTopBar`.
class _CalibrationTopBar extends StatelessWidget {
  final VoidCallback onBackPressed;

  const _CalibrationTopBar({required this.onBackPressed});

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
                  'Kalibrierung',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
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

// ── Volume Picker ────────────────────────────────────────────────────────────

/// One row of the screen: a [label] and a scroll wheel for the volume.
///
/// The selected value is drawn transparent inside the wheel and shown in the
/// highlighted box that is stacked on top of it instead.
class _VolumeSection extends StatelessWidget {
  final String label;
  final int selectedValue;
  final List<int> values;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelectedItemChanged;

  const _VolumeSection({
    required this.label,
    required this.selectedValue,
    required this.values,
    required this.controller,
    required this.onSelectedItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.text(context),
              height: 1.0,
            ),
          ),
        ),
        SizedBox(
          width: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: SizedBox(
                  width: 176,
                  height: 190,
                  child: ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: 38,
                    diameterRatio: 10,
                    perspective: 0.003,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: onSelectedItemChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: values.length,
                      builder: (context, index) {
                        final value = values[index];
                        final bool isSelected = value == selectedValue;
                        return Center(
                          child: Text(
                            value.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.transparent
                                  : AppColors.mutedText(context),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 7,
                child: Container(
                  width: 176,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary(context),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    selectedValue.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onPrimary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}