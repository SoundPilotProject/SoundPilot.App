// lib/features/device/screens/calibration_screen.dart
//
// Left/right volume calibration of one earbud (two scroll wheels and a test
// tone on the earbud).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_logger.dart';
import '../../../core/services/audio_device_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../models/user_model.dart';
import '../headphone_connection.dart';
import '../volume_scale.dart';
import 'test_page.dart';

/// Screen where the user sets the left and right volume (1–100) of one earbud.
///
/// The wheels start at the volumes of [calib]. While the earbud is connected,
/// a test tone can be played on it; turning a wheel changes its side at once
/// ([wheelToGain]). The tone only starts on the user's request (a screen
/// reader speaks through the same headphones) and stops when the screen is
/// left, the app goes to the background or the earbud disconnects.
///
/// Before the [TestPage] opens, the chosen values are handed to [onSave] as a
/// copy of [calib]. The screen pops with `true` once the test exercise was
/// finished.
class CalibrationScreen extends StatefulWidget {
  /// The earbud being calibrated; its volumes are the starting values.
  final HeadphoneCalib calib;

  /// Map key of the earbud (its BD_ADDR), to find it among the connected
  /// headphones.
  final String address;

  /// Stores the new calibration of this earbud.
  final Future<void> Function(HeadphoneCalib calib) onSave;

  /// The connected headphones, again on every change; tests pass a fake.
  /// Defaults to [AudioDeviceService.headphoneChanges].
  final Stream<List<HeadphoneDevice>> Function() headphoneChanges;

  /// Whether the test tone exists here (only the Android app has it).
  /// Defaults to [AudioDeviceService.isSupported].
  final bool? toneSupported;

  const CalibrationScreen({
    super.key,
    required this.calib,
    required this.address,
    required this.onSave,
    this.headphoneChanges = AudioDeviceService.headphoneChanges,
    this.toneSupported,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with WidgetsBindingObserver {
  /// Currently selected volumes, starting at the earbud's saved values.
  late int _leftVolume;
  late int _rightVolume;

  late final bool _toneSupported =
      widget.toneSupported ?? AudioDeviceService.isSupported;

  /// Whether the earbud is connected; null without tone support.
  HeadphoneConnection? _connection;

  /// Whether the test tone is playing.
  bool _toneOn = false;

  /// Shown below the tone button if the tone could not be started.
  String? _toneError;

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
    WidgetsBinding.instance.addObserver(this);
    if (_toneSupported) {
      _connection = HeadphoneConnection(
        address: widget.address,
        changes: widget.headphoneChanges,
        onChanged: _onConnectionChanged,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connection?.dispose();
    if (_toneOn) unawaited(_stopToneQuietly());
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // NOTE: No tone in the background, where the user cannot stop it.
    if (state != AppLifecycleState.resumed && _toneOn) _stopTone();
  }

  // ── Test tone ──────────────────────────────────────────────────────────────

  /// If the earbud disconnected while the tone played, the native side has
  /// stopped the tone already; the button follows.
  void _onConnectionChanged() {
    setState(() {
      if (_connection?.connected == null) _toneOn = false;
    });
  }

  Future<void> _toggleTone() => _toneOn ? _stopTone() : _startTone();

  Future<void> _startTone() async {
    final headphone = _connection?.connected;
    if (headphone == null) return;

    setState(() => _toneError = null);
    try {
      await AudioDeviceService.playTestTone(
        leftGain: wheelToGain(_leftVolume),
        rightGain: wheelToGain(_rightVolume),
        outputDeviceId: headphone.outputDeviceId,
      );
      if (!mounted) {
        unawaited(_stopToneQuietly());
        return;
      }
      setState(() => _toneOn = true);
    } on PlatformException catch (e) {
      logger.e('CalibrationScreen: Test tone failed', error: e);
      if (!mounted) return;
      setState(() {
        _toneOn = false;
        _toneError = e.code == 'DEVICE_NOT_CONNECTED'
            ? 'Die Kopfhörer sind nicht mehr verbunden.'
            : 'Der Testton konnte nicht abgespielt werden. Bitte versuche es '
                'noch einmal.';
      });
    }
  }

  Future<void> _stopTone() async {
    setState(() => _toneOn = false);
    await _stopToneQuietly();
  }

  /// Stops the tone without touching the state (also used in [dispose]).
  Future<void> _stopToneQuietly() async {
    try {
      await AudioDeviceService.stopPlayback();
    } on PlatformException catch (e) {
      logger.e('CalibrationScreen: Stopping the test tone failed', error: e);
    }
  }

  /// Applies a wheel change to the playing tone.
  void _updateToneGain() {
    if (!_toneOn) return;
    unawaited(AudioDeviceService.setPlaybackGain(
      leftGain: wheelToGain(_leftVolume),
      rightGain: wheelToGain(_rightVolume),
    ).catchError((Object e) {
      logger.e('CalibrationScreen: Changing the test tone failed', error: e);
    }));
  }

  /// Saves the current values and opens the [TestPage]. If the test was
  /// finished (`true`), this screen pops with `true` as well.
  Future<void> _openTestPage() async {
    // The test page plays its own sound.
    if (_toneOn) await _stopTone();

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
          address: widget.address,
          headphoneChanges: widget.headphoneChanges,
          soundSupported: widget.toneSupported,
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
                    _ToneSection(
                      supported: _toneSupported,
                      connectionKnown: _connection?.known ?? false,
                      connected: _connection?.connected != null,
                      toneOn: _toneOn,
                      error: _toneError,
                      onToggle: _toggleTone,
                    ),
                    const SizedBox(height: 24),
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
                        _updateToneGain();
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
                        _updateToneGain();
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

// ── Test tone ────────────────────────────────────────────────────────────────

/// Explanation and the button that starts or stops the test tone, or why
/// there is none (not in the Android app, earbud not connected).
///
/// The state is written out and announced by screen readers, not shown by
/// the button colour alone.
class _ToneSection extends StatelessWidget {
  final bool supported;
  final bool connectionKnown;
  final bool connected;
  final bool toneOn;
  final String? error;
  final VoidCallback onToggle;

  const _ToneSection({
    required this.supported,
    required this.connectionKnown,
    required this.connected,
    required this.toneOn,
    required this.error,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (supported && !connectionKnown) return const SizedBox.shrink();

    final String text;
    if (!supported) {
      text = 'Den Testton gibt es nur in der Android-App.';
    } else if (!connected) {
      text = 'Verbinde zuerst deine Kopfhörer, dann kannst du den Testton '
          'hören.';
    } else if (toneOn) {
      text = 'Der Testton läuft. Stelle jede Seite so ein, dass du sie gut '
          'hörst.';
    } else {
      text = 'Spiele den Testton ab und stelle dann jede Seite so ein, dass '
          'du sie gut hörst.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
              height: 1.35,
            ),
          ),
        ),
        if (supported) ...[
          const SizedBox(height: 12),
          if (connected)
            _SecondaryButton(
              icon: toneOn ? Icons.stop_rounded : Icons.play_arrow_rounded,
              label: toneOn ? 'Testton stoppen' : 'Testton abspielen',
              onPressed: onToggle,
            )
          else
            const _SecondaryButton(
              icon: Icons.settings_rounded,
              label: 'Bluetooth-Einstellungen öffnen',
              onPressed: AudioDeviceService.openBluetoothSettings,
            ),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.text(context), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Outlined button below the main action's weight, with an icon.
class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary(context),
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: AppColors.primary(context), width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40),
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
