// lib/features/device/screens/calibration_screen.dart
//
// Left/right volume calibration of one earbud (two scroll wheels).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../models/user_model.dart';
import 'test_page.dart';

/// Converts a stored volume (0.0–1.0, see [HeadphoneCalib]) to the wheel
/// value 1–100.
int volumeToWheel(double volume) => (volume * 100).round().clamp(1, 100);

/// Converts a wheel value 1–100 to the stored volume (0.01–1.0).
double wheelToVolume(int value) => value / 100;

/// Screen where the user sets the left and right volume (1–100) of one earbud.
///
/// The wheels start at the volumes of [calib]. Before the [TestPage] opens,
/// the chosen values are handed to [onSave] as a copy of [calib]. The screen
/// pops with `true` once the test exercise was finished.
class CalibrationScreen extends StatefulWidget {
  /// The earbud being calibrated; its volumes are the starting values.
  final HeadphoneCalib calib;

  /// Stores the new calibration of this earbud.
  final Future<void> Function(HeadphoneCalib calib) onSave;

  const CalibrationScreen({
    super.key,
    required this.calib,
    required this.onSave,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  /// Currently selected volumes, starting at the earbud's saved values.
  late int _leftVolume;
  late int _rightVolume;

  late final FixedExtentScrollController _leftController;
  late final FixedExtentScrollController _rightController;

  /// Selectable volumes 1..100 (wheel item index = value - 1).
  final List<int> _values = List.generate(100, (index) => index + 1);

  @override
  void initState() {
    super.initState();
    _leftVolume = volumeToWheel(widget.calib.volumeLeft);
    _rightVolume = volumeToWheel(widget.calib.volumeRight);
    _leftController =
        FixedExtentScrollController(initialItem: _leftVolume - 1);
    _rightController =
        FixedExtentScrollController(initialItem: _rightVolume - 1);
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
    // Save current values before opening the test page, so they are kept
    // even if the test is left without finishing it.
    await widget.onSave(widget.calib.copyWith(
      volumeLeft: wheelToVolume(_leftVolume),
      volumeRight: wheelToVolume(_rightVolume),
    ));

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
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Kalibrierung',
              onBackPressed: () => Navigator.pop(context),
            ),
            Expanded(
              // Scrollable: the two wheels plus the button need more room than
              // a small phone offers at large system font sizes.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VolumeSection(
                      title: 'Linke Seite',
                      semanticSide: 'Linke Seite',
                      selectedValue: _leftVolume,
                      values: _values,
                      controller: _leftController,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _leftVolume = _values[index];
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    _VolumeSection(
                      title: 'Rechte Seite',
                      semanticSide: 'Rechte Seite',
                      selectedValue: _rightVolume,
                      values: _values,
                      controller: _rightController,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _rightVolume = _values[index];
                        });
                      },
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _openTestPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        foregroundColor: AppColors.onPrimary(context),
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.18),
                        minimumSize: const Size(double.infinity, 76),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      child: Text(
                        'Test-Übung',
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

// ── Volume Picker ────────────────────────────────────────────────────────────

/// One side of the calibration: a heading and a scroll wheel for the volume.
///
/// The selected value is drawn transparent inside the wheel and shown in the
/// highlighted box that is stacked on top of it instead.
///
/// Accessibility note: the wheel is the only visible control, but it is wrapped
/// in a semantics node that exposes the current value plus an increase and a
/// decrease action. Screen readers therefore offer the standard
/// "swipe up / swipe down to adjust" gesture, which a bare
/// [ListWheelScrollView] does not provide.
class _VolumeSection extends StatelessWidget {
  /// Visible heading, e.g. 'Linke Seite'.
  final String title;

  /// Side name used in the screen-reader label.
  final String semanticSide;

  final int selectedValue;
  final List<int> values;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelectedItemChanged;

  const _VolumeSection({
    required this.title,
    required this.semanticSide,
    required this.selectedValue,
    required this.values,
    required this.controller,
    required this.onSelectedItemChanged,
  });

  /// Moves the wheel by [step] items; the wheel then reports the new value
  /// through [onSelectedItemChanged].
  ///
  /// Only reachable through the screen-reader actions, see the class docs.
  void _step(int step) {
    final target = (selectedValue - 1 + step).clamp(0, values.length - 1);
    if (target == selectedValue - 1) return;

    HapticFeedback.selectionClick();
    controller.animateToItem(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.text(context),
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Lautstärke',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedText(context),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: '$semanticSide, Lautstärke',
          value: '$selectedValue von 100',
          increasedValue: '${(selectedValue + 1).clamp(1, 100)} von 100',
          decreasedValue: '${(selectedValue - 1).clamp(1, 100)} von 100',
          onIncrease: () => _step(1),
          onDecrease: () => _step(-1),
          child: SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                  child: ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: 44,
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
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
                // Highlight box over the centre item. IgnorePointer keeps the
                // wheel draggable through it.
                IgnorePointer(
                  child: Container(
                    height: 72,
                    width: 190,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary(context),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      selectedValue.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
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
    );
  }
}
