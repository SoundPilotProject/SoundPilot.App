// lib/features/device/screens/belt_vibration_screen.dart
//
// Belt setup, step 2: vibration strength and side.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';

/// Second step of the belt setup (after [BeltWarningDistanceScreen]): the user
/// enters the vibration strength in % (recommended 60–100 %) and picks a side
/// ('L', 'M' or 'R').
///
/// Pops with `true` when the setup is finished.
///
/// TODO(improve): The entered strength and the selected side are neither
/// validated nor saved. `_finishSetup` only waits and pops `true`. The
/// strength should be checked (0–100) and stored with the belt entry.
///
/// TODO(improve): The label 'SUCHE GURT...' is static text, no search is
/// started here. Either connect it to a real belt search or change the text.
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

  @override
  void dispose() {
    _strengthController.dispose();
    super.dispose();
  }

  /// Shows a short loading screen and pops back with `true` (setup done).
  ///
  /// TODO(improve): The `Future.delayed(2 s)` only keeps the loading screen
  /// visible for a moment and slows the UI down on purpose (see
  /// StartScreen._continueAsGuest).
  Future<void> _finishSetup() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(
          text: 'Gürtel wird eingerichtet...',
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pop(context);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: 'VIBRATIONEN',
              onBackPressed: () {
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
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
                        'EMPFEHLUNG\n60-100 %',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text(context),
                          height: 1.08,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'STÄRKE IN %',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(context),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 82,
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.inputBorder(context),
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: _strengthController,
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
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 46),
                    Text(
                      'SUCHE GURT...',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(context),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _SideButton(
                            label: 'L',
                            selected: _selectedSide == 'L',
                            onTap: () {
                              setState(() {
                                _selectedSide = 'L';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _SideButton(
                            label: 'M',
                            selected: _selectedSide == 'M',
                            onTap: () {
                              setState(() {
                                _selectedSide = 'M';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _SideButton(
                            label: 'R',
                            selected: _selectedSide == 'R',
                            onTap: () {
                              setState(() {
                                _selectedSide = 'R';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 78,
                      child: ElevatedButton(
                        onPressed: _finishSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          foregroundColor: AppColors.onPrimary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(42),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          'ABSCHLIESSEN',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
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

/// Blue top bar with a back arrow and a [title].
///
/// TODO(improve): Duplicate of the other screens' top bars, see
/// `_LoginTopBar`. (This one already takes the title as a parameter, so it is
/// a good base for the shared widget.)
class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBackPressed;

  const _TopBar({
    required this.title,
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
                  title,
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

/// Large toggle button for one side ('L', 'M' or 'R'); highlighted if
/// [selected].
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

    return SizedBox(
      height: 92,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
            side: BorderSide(
              color: selected
                  ? AppColors.primary(context)
                  : AppColors.legendBorder(context),
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
    );
  }
}