// lib/features/device/screens/belt_vibration_screen.dart
//
// Belt setup, step 2: vibration strength and side.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/haptic_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../models/user_model.dart';
import '../widgets/belt_setup_fields.dart';

/// Second step of the belt setup (after `BeltWarningDistanceScreen`): the user
/// enters the vibration strength in % (recommended 60–100 %, allowed
/// [BeltCalib.minVibrationStrength] to [BeltCalib.maxVibrationStrength]), can
/// feel it as a single pulse ('Vibration testen', see `_testVibration`) and
/// picks the motor ([BeltSide]: 'Links', 'Mitte' or 'Rechts').
///
/// Starts with the values of [belt]. Pops with [belt] and the entered values
/// when the setup is finished; going back pops with null.
///
/// NOTE: The heading above the side buttons used to read 'SUCHE GURT...'
/// although no search happens here; it now names what the buttons do.
class BeltVibrationScreen extends StatefulWidget {
  /// The belt with the values of the first step.
  final BeltCalib belt;

  const BeltVibrationScreen({super.key, required this.belt});

  @override
  State<BeltVibrationScreen> createState() => _BeltVibrationScreenState();
}

class _BeltVibrationScreenState extends State<BeltVibrationScreen> {
  late final TextEditingController _strengthController =
      TextEditingController(text: '${widget.belt.vibrationStrength}');

  /// Selected motor.
  late BeltSide _selectedSide = widget.belt.vibrationSide;

  /// Shown below the field while the typed strength is not allowed.
  String? _error;

  /// What the last 'Vibration testen' did, as text; null until it is used.
  String? _pulseNote;

  /// Names of the sides in the order of the buttons, used for the button
  /// labels and for the screen-reader announcement.
  static const Map<BeltSide, String> _sideNames = {
    BeltSide.left: 'Links',
    BeltSide.front: 'Mitte',
    BeltSide.right: 'Rechts',
  };

  @override
  void dispose() {
    _strengthController.dispose();
    super.dispose();
  }

  /// The typed strength if it is allowed; otherwise shows the error below the
  /// field and returns null.
  int? _checkedStrength() {
    final strength = parseBeltValue(
      _strengthController.text,
      min: BeltCalib.minVibrationStrength,
      max: BeltCalib.maxVibrationStrength,
    );
    if (strength == null) {
      setState(() {
        _error = beltValueError(
          min: BeltCalib.minVibrationStrength,
          max: BeltCalib.maxVibrationStrength,
          unit: '%',
        );
        _pulseNote = null;
      });
    }
    return strength;
  }

  /// Plays one reference pulse at the strength that is typed in — the basic
  /// belt test (see `docs/PROJECT_CONTEXT.md` §4).
  ///
  /// NOTE: It goes to the phone's own motor, because there is no belt to send
  /// it to yet (see [HapticEngine]). The strength is read from the field for
  /// this pulse only; it is stored with 'Abschließen'. It accepts the same
  /// range as 'Abschließen', so a strength that can be felt can also be kept.
  ///
  /// NOTE: The pulse is reported as text as well, not only felt: a user who
  /// cannot feel it has to be able to tell that the app did play one.
  Future<void> _testVibration() async {
    final value = _checkedStrength();
    if (value == null) return;

    setState(() => _pulseNote = 'Vibration mit $value % gespielt.');

    await HapticEngine.pulse(intensity: value / 100);
  }

  /// Checks the strength and pops with the finished belt.
  void _finishSetup() {
    final strength = _checkedStrength();
    if (strength == null) return;

    Navigator.pop(
      context,
      widget.belt.copyWith(
        vibrationStrength: strength,
        vibrationSide: _selectedSide,
      ),
    );
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
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      BeltFieldError(text: _error!),
                    ],
                    const SizedBox(height: 14),
                    // One pulse at the strength above, so it can be felt
                    // before it is kept. Below 'Abschließen' in weight: this
                    // is a try, not the way on.
                    ElevatedButton(
                      onPressed: _testVibration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface(context),
                        foregroundColor: AppColors.text(context),
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.15),
                        minimumSize: const Size(double.infinity, 64),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                          side: BorderSide(
                            color: AppColors.legendBorder(context),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.vibration_rounded,
                            size: 28,
                            color: AppColors.text(context),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Vibration testen',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pulseNote != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _pulseNote!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
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
                          if (side != BeltSide.left) const SizedBox(width: 12),
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
///
/// NOTE: The `selected` state sits on the button's *content*, not on a
/// [Semantics] around the button. `ElevatedButton` wraps itself in
/// `Semantics(container: true)`, so a wrapper around it becomes a separate
/// node: the state used to end up on a node without a name while the node the
/// screen reader focuses carried the name without the state — 'Mitte,
/// Schaltfläche', never 'ausgewählt'.
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

    return ElevatedButton(
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
      child: Semantics(
        selected: selected,
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
