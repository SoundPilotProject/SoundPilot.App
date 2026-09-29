// lib/features/device/screens/device_screen.dart
//
// Main screen: list of earbuds and belts, add/remove devices, open their
// calibration/setup, login/register (guest) or logout.
//
// The add-device dialog, the device card and the legend live in
// `features/device/widgets/`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_model.dart';
import '../../auth/auth_service.dart';
import 'calibration.dart';
import 'belt_warning_distance_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../core/services/device_storage_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/register_screen.dart';
import '../widgets/add_device_dialog.dart';
import '../widgets/device_card.dart';
import '../widgets/device_type.dart';

/// Main screen after start-up (signed in or guest).
///
/// Shows the earbuds and belts stored locally (see [DeviceStorageService]).
/// Guests see 'Login' and 'Registrieren', signed-in users see 'Abmelden'.
/// Tapping a device opens its calibration ([CalibrationScreen]) or belt setup
/// ([BeltWarningDistanceScreen]).
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  /// We now use Maps, matching the UserModel and Storage Service.
  /// Key is the Bluetooth Address (MAC), Value is the Calibration object.
  Map<String, HeadphoneCalib> _earbuds = {};

  /// Belts, same structure as [_earbuds].
  Map<String, BeltCalib> _belts = {};

  /// True until the devices have been loaded from local storage.
  bool _isLoadingDevices = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  /// Loads the devices of the current user (or guest) from local storage.
  Future<void> _loadDevices() async {
    // Call the new method from the storage service
    final stored = await DeviceStorageService.loadUserCalibration();

    if (!mounted) return;

    setState(() {
      // Assign the maps directly from the result
      _earbuds = stored['headphones'] as Map<String, HeadphoneCalib>? ?? {};
      _belts = stored['belts'] as Map<String, BeltCalib>? ?? {};
      _isLoadingDevices = false;
    });
  }

  /// Saves both device maps to local storage.
  ///
  /// NOTE: The callers do not `await` this method, so a failed save is not
  /// noticed by the UI.
  ///
  /// NOTE: `isConnected` is not part of `toMap()`, so it is lost on the next
  /// load and every device shows as not connected again after a restart.
  Future<void> _persistDevices() async {
    // Call the new save method and pass the maps
    await DeviceStorageService.saveUserCalibration(
      headphones: _earbuds,
      belts: _belts,
    );
  }

  /// True if a Firebase user is signed in (otherwise: guest).
  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  // ── Logout ─────────────────────────────────────────────────────────────────

  /// Signs out; AppEntryPoint then shows the StartScreen.
  ///
  /// TODO(improve): The `Future.delayed(2 s)` only keeps the loading screen
  /// visible for a moment and slows the UI down on purpose (same in
  /// TestPage._finishExercise and BeltVibrationScreen._finishSetup;
  /// StartScreen._continueAsGuest no longer has it, see there).
  Future<void> _logout() async {
    // NOTE: The navigator is read before the logout, because this screen is
    // removed by AppEntryPoint during it and `context` is then no longer valid.
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(text: 'Wird abgemeldet...'),
      ),
    );

    // NOTE: `finally`, so the loading screen is closed even if the logout
    // throws; otherwise it stays open forever.
    try {
      await AuthService().logout();
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  // ── Remove ─────────────────────────────────────────────────────────────────

  /// Removes the device at position [index] of the given [type] and saves the
  /// list.
  ///
  /// TODO(improve): The device is found by its position in the map
  /// (`keys.elementAt(index)`). This only works as long as the iteration order
  /// stays stable. Pass the map key (BD_ADDR) instead of the index.
  void _removeDevice(DeviceType type, int index) {
    setState(() {
      if (type == DeviceType.earbuds) {
        final keyToRemove = _earbuds.keys.elementAt(index);
        _earbuds.remove(keyToRemove);
      } else {
        final keyToRemove = _belts.keys.elementAt(index);
        _belts.remove(keyToRemove);
      }
    });
    _persistDevices();
  }

  // ── Calibration / Setup ────────────────────────────────────────────────────

  /// Opens the [CalibrationScreen] for the earbud at position [index]; if it
  /// returns `true`, the earbud is marked as connected and saved.
  ///
  /// TODO(improve): Look the device up by its map key (BD_ADDR) instead of the
  /// index (see [_removeDevice]), and pass the key to the calibration screen.
  /// Today the calibration values are not tied to this earbud at all (see
  /// CalibrationScreen).
  Future<void> _openCalibrationForEarbud(int index) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );

    if (!mounted) return;
    if (result == true && index >= 0 && index < _earbuds.length) {
      setState(() {
        // Find the key by index to update the connected state
        final key = _earbuds.keys.elementAt(index);
        _earbuds[key]!.isConnected = true;
      });
      _persistDevices();
    }
  }

  /// Opens the belt setup ([BeltWarningDistanceScreen]) for the belt at
  /// position [index]; if it returns `true`, the belt is marked as connected
  /// and saved.
  ///
  /// TODO(improve): Same as [_openCalibrationForEarbud]: use the map key
  /// instead of the index. The setup screens do not return the entered values
  /// yet.
  Future<void> _openBeltSetup(int index) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BeltWarningDistanceScreen()),
    );

    if (!mounted) return;
    if (result == true && index >= 0 && index < _belts.length) {
      setState(() {
        // Find the key by index to update the connected state
        final key = _belts.keys.elementAt(index);
        _belts[key]!.isConnected = true;
      });
      _persistDevices();
    }
  }

  // ── Add device dialog ──────────────────────────────────────────────────────

  /// Shows the [AddDeviceDialog] and stores the chosen device, then opens the
  /// calibration (earbuds) or the setup (belts) right away.
  ///
  /// TODO(improve): `newIndex` is computed from the map length before the
  /// device is added. This relies on the new entry being last; use the new
  /// map key instead.
  Future<void> _openAddDeviceDialog() async {
    final result = await showDialog<AddDeviceResult>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const AddDeviceDialog(),
    );

    if (!mounted || result == null) return;

    // Generate a temporary unique ID since we don't have real MAC addresses yet
    // (TODO: real BD_ADDR from the Bluetooth scan, see scanForSystemDevices)
    final tempMacAddress = 'dummy_mac_${DateTime.now().millisecondsSinceEpoch}';

    if (result.type == DeviceType.earbuds) {
      final newIndex = _earbuds.length;
      setState(() {
        // Add to map using the new MAC address key
        _earbuds[tempMacAddress] = HeadphoneCalib(
          modelId: result.name,
          isConnected: false,
        );
      });
      _persistDevices();

      if (result.openCalibration) {
        await _openCalibrationForEarbud(newIndex);
      }
    } else {
      final newIndex = _belts.length;
      setState(() {
        // Add to map using the new MAC address key
        _belts[tempMacAddress] = BeltCalib(
          modelId: result.name,
          isConnected: false,
        );
      });
      _persistDevices();

      // NOTE: Belts open their setup here as well. The dialog used to ask for
      // this only for earbuds, so a newly added belt was never set up.
      if (result.openCalibration) {
        await _openBeltSetup(newIndex);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDevices) {
      return const LoadingScreen(text: 'Geräte werden geladen...');
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Always scrollable: with many devices or a large system font the
            // list is longer than the screen. The IntrinsicHeight keeps the
            // legend pinned to the bottom as long as everything fits.
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: IntrinsicHeight(child: _buildContent()),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Title, device lists and legend.
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopButtons(),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            'Geräte',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppColors.text(context),
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 18),
        ..._buildDeviceGroup(
          type: DeviceType.earbuds,
          count: _earbuds.length,
          nameAt: (i) => _earbuds.values.elementAt(i).modelId,
          isConnectedAt: (i) => _earbuds.values.elementAt(i).isConnected,
          onOpen: _openCalibrationForEarbud,
        ),
        const SizedBox(height: 18),
        ..._buildDeviceGroup(
          type: DeviceType.belt,
          count: _belts.length,
          nameAt: (i) => _belts.values.elementAt(i).modelId,
          isConnectedAt: (i) => _belts.values.elementAt(i).isConnected,
          onOpen: _openBeltSetup,
        ),
        const SizedBox(height: 20),
        const Spacer(),
        const LegendBox(),
      ],
    );
  }

  /// One group of the list: its heading and either the device cards or a hint
  /// that the group is still empty.
  List<Widget> _buildDeviceGroup({
    required DeviceType type,
    required int count,
    required String Function(int index) nameAt,
    required bool Function(int index) isConnectedAt,
    required Future<void> Function(int index) onOpen,
  }) {
    return [
      Semantics(
        header: true,
        child: Text(
          type.label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: AppColors.text(context),
            height: 1.2,
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (count == 0)
        Text(
          type.emptyList,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedText(context),
            height: 1.3,
          ),
        )
      else
        ...List.generate(count, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DeviceCard(
              name: nameAt(index),
              type: type,
              isConnected: isConnectedAt(index),
              onDelete: () => _removeDevice(type, index),
              onTap: () => onOpen(index),
            ),
          );
        }),
    ];
  }

  /// Top buttons: 'Abmelden' if signed in, otherwise 'Login' and
  /// 'Registrieren', always followed by the add button.
  ///
  /// At large system font sizes the buttons are stacked instead of placed side
  /// by side, because three labels do not fit across a phone. Stacked, the add
  /// button also gets its own visible label.
  Widget _buildTopButtons() {
    final stacked = MediaQuery.textScalerOf(context).scale(17) > 24;

    final authButtons = _isLoggedIn
        ? <({int flex, String text, VoidCallback onPressed})>[
            (flex: 7, text: 'Abmelden', onPressed: _logout),
          ]
        : <({int flex, String text, VoidCallback onPressed})>[
            (
              flex: 3,
              text: 'Login',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const LoginScreen(),
                  ),
                );
              },
            ),
            (
              flex: 4,
              text: 'Registrieren',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const RegisterScreen(),
                  ),
                );
              },
            ),
          ];

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final button in authButtons) ...[
            _TopActionButton(text: button.text, onPressed: button.onPressed),
            const SizedBox(height: 10),
          ],
          _TopActionButton(
            text: 'Gerät hinzufügen',
            icon: Icons.add,
            onPressed: _openAddDeviceDialog,
          ),
        ],
      );
    }

    // IntrinsicHeight instead of a bare CrossAxisAlignment.stretch: the row is
    // inside a scroll view, where stretching would ask for an infinite height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final button in authButtons) ...[
            Expanded(
              flex: button.flex,
              child: _TopActionButton(
                text: button.text,
                onPressed: button.onPressed,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 3,
            child: _IconSquareButton(
              icon: Icons.add,
              // Icon-only buttons are invisible to screen readers without a
              // label; the tooltip provides it.
              tooltip: 'Gerät hinzufügen',
              onPressed: _openAddDeviceDialog,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top row buttons ──────────────────────────────────────────────────────────

/// Large rounded text button for the top row ('Abmelden', 'Login', ...).
///
/// NOTE: The label may wrap to two lines instead of being scaled down, so it
/// keeps following the system font size.
class _TopActionButton extends StatelessWidget {
  final String text;

  /// Optional leading icon, used by the stacked 'Gerät hinzufügen' button.
  final IconData? icon;

  final VoidCallback onPressed;

  const _TopActionButton({
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = AppColors.onPrimary(context);

    final label = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: onPrimary,
      ),
    );

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary(context),
        foregroundColor: onPrimary,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        minimumSize: const Size(0, 72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      child: icon == null
          ? label
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: onPrimary),
                const SizedBox(width: 10),
                Flexible(child: label),
              ],
            ),
    );
  }
}

/// Square button with an icon (the '+' button next to the top actions).
class _IconSquareButton extends StatelessWidget {
  final IconData icon;

  /// Shown on long press and read out by screen readers as the button's name.
  final String tooltip;

  final VoidCallback onPressed;

  const _IconSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(context),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          minimumSize: const Size(0, 72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 34, color: AppColors.onPrimary(context)),
      ),
    );
  }
}
