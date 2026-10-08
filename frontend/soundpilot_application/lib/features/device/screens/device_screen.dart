// lib/features/device/screens/device_screen.dart
//
// Main screen: list of earbuds and belts, add/remove devices, open their
// calibration/setup, login/register (guest) or logout.
//
// The add-device dialog, the device card and the legend live in
// `features/device/widgets/`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_model.dart';
import '../../auth/auth_service.dart';
import 'calibration_screen.dart';
import 'belt_warning_distance_screen.dart';
import '../../../core/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../core/services/device_repository.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/register_screen.dart';
import '../widgets/add_device_dialog.dart';
import '../widgets/device_card.dart';
import '../widgets/device_type.dart';
import '../widgets/unsynced_logout_dialog.dart';

/// Main screen after start-up (signed in or guest).
///
/// Shows the earbuds and belts of [repository] (Firestore for a signed-in
/// user, local for a guest) and stays in sync with it. Guests see 'Login' and
/// 'Registrieren', signed-in users see 'Abmelden'. Tapping a device opens its
/// calibration ([CalibrationScreen]) or belt setup
/// ([BeltWarningDistanceScreen]).
class DeviceScreen extends StatefulWidget {
  /// Where the devices are read and written.
  ///
  /// NOTE: Only the repository of the first build is used (in `initState`);
  /// AppEntryPoint gives every user its own key, so a new user gets a new
  /// screen.
  final DeviceRepository repository;

  /// Whether a Firebase user is signed in (otherwise: guest).
  final bool isSignedIn;

  /// Used for the logout; tests pass a double. Defaults to [AuthService].
  final AuthService? authService;

  const DeviceScreen({
    super.key,
    required this.repository,
    required this.isSignedIn,
    this.authService,
  });

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  /// We now use Maps, matching the UserModel and Storage Service.
  /// Key is the Bluetooth Address (MAC), Value is the Calibration object.
  Map<String, HeadphoneCalib> _earbuds = {};

  /// Belts, same structure as [_earbuds].
  Map<String, BeltCalib> _belts = {};

  /// Keys of the devices that count as connected in this session.
  ///
  /// NOTE: Runtime only, like `isConnected` in the model; kept here because
  /// every update from the repository brings new objects, all not connected.
  final Set<String> _connected = {};

  /// True until the repository has delivered the devices for the first time.
  bool _isLoadingDevices = true;

  /// Set if the devices could not be loaded.
  bool _loadFailed = false;

  /// The repository of the first build (see [DeviceScreen.repository]).
  late final DeviceRepository _repository = widget.repository;

  StreamSubscription<DeviceData>? _devices;

  @override
  void initState() {
    super.initState();
    _devices = _repository.watch().listen(
      (data) {
        setState(() {
          _earbuds = data.headphones;
          _belts = data.belts;
          _isLoadingDevices = false;
          _loadFailed = false;
        });
      },
      onError: (Object e) {
        logger.e('DeviceScreen: Loading the devices failed', error: e);
        setState(() {
          _isLoadingDevices = false;
          _loadFailed = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _devices?.cancel();
    _repository.dispose();
    super.dispose();
  }

  /// Starts a write without waiting for it, and tells the user if it fails.
  ///
  /// NOTE: Not awaited on purpose: offline, a Firestore write only completes
  /// once it reached the server, but the list already shows it (see
  /// FirestoreDeviceRepository).
  void _save(Future<void> write) {
    write.catchError((Object e) {
      logger.e('DeviceScreen: Saving failed', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Die Änderung konnte nicht gespeichert werden. '
                  'Bitte versuche es später noch einmal.',
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  /// Signs out; AppEntryPoint then shows the StartScreen.
  ///
  /// The logout deletes the local Firestore cache, and with it changes that
  /// have not reached the server yet (offline). If there are any, the user is
  /// asked first ([UnsyncedLogoutDialog]) and can stay signed in.
  Future<void> _logout() async {
    final auth = widget.authService ?? AuthService();

    // NOTE: The navigator is read before the logout, because this screen is
    // removed by AppEntryPoint during it and `context` is then no longer valid.
    final navigator = Navigator.of(context);
    void showLoading() => navigator.push(
          MaterialPageRoute(
            builder: (_) => const LoadingScreen(text: 'Wird abgemeldet...'),
          ),
        );

    showLoading();
    // NOTE: `finally`, so the loading screen is closed even if the logout
    // throws; otherwise it stays open forever.
    try {
      if (await auth.hasUnsavedChanges()) {
        navigator.pop();
        if (!mounted) return;
        final logOutAnyway = await showDialog<bool>(
          context: context,
          builder: (_) => const UnsyncedLogoutDialog(),
        );
        if (logOutAnyway != true) return;
        showLoading();
      }

      // NOTE: Stop listening before the sign-out, so the listener gets no
      // permission-denied and the list does not flash an error meanwhile. Not
      // awaited: the Firestore listener is removed at once, and the returned
      // future never completes under the fake clock of widget tests.
      unawaited(_devices?.cancel());
      _devices = null;

      await auth.logout();
    } finally {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  // ── Remove ─────────────────────────────────────────────────────────────────

  /// Removes the device with the map key [key] (BD_ADDR) of the given [type].
  void _removeDevice(DeviceType type, String key) {
    _connected.remove(key);
    _save(type == DeviceType.earbuds
        ? _repository.removeHeadphone(key)
        : _repository.removeBelt(key));
  }

  // ── Calibration / Setup ────────────────────────────────────────────────────

  /// Opens the [CalibrationScreen] for the earbud [calib] with the map key
  /// [key]. The screen saves its volumes into this earbud; if it returns
  /// `true`, the earbud is also marked as connected.
  ///
  /// NOTE: [calib] is passed in instead of read from [_earbuds], because a
  /// newly added earbud is only in the list once the repository reports it.
  Future<void> _openCalibrationForEarbud(
    String key,
    HeadphoneCalib calib,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CalibrationScreen(
          calib: calib,
          onSave: (updated) async =>
              _save(_repository.putHeadphone(key, updated)),
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      setState(() => _connected.add(key));
    }
  }

  /// Opens the belt setup ([BeltWarningDistanceScreen]) for the belt with the
  /// map key [key]; if it returns `true`, the belt is marked as connected.
  ///
  /// TODO(improve): The setup screens do not return the entered values yet.
  Future<void> _openBeltSetup(String key) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BeltWarningDistanceScreen()),
    );

    if (!mounted) return;
    if (result == true) {
      setState(() => _connected.add(key));
    }
  }

  // ── Add device dialog ──────────────────────────────────────────────────────

  /// Shows the [AddDeviceDialog] and stores the chosen device, then opens the
  /// calibration (earbuds) or the setup (belts) right away.
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
      final calib = HeadphoneCalib(modelId: result.name);
      _save(_repository.putHeadphone(tempMacAddress, calib));

      if (result.openCalibration) {
        await _openCalibrationForEarbud(tempMacAddress, calib);
      }
    } else {
      _save(_repository.putBelt(
        tempMacAddress,
        BeltCalib(modelId: result.name),
      ));

      // NOTE: Belts open their setup here as well. The dialog used to ask for
      // this only for earbuds, so a newly added belt was never set up.
      if (result.openCalibration) {
        await _openBeltSetup(tempMacAddress);
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
        if (_loadFailed) ...[
          _buildLoadError(),
          const SizedBox(height: 18),
        ],
        ..._buildDeviceGroup(
          type: DeviceType.earbuds,
          devices: {
            for (final e in _earbuds.entries)
              e.key: (name: e.value.modelId, isConnected: _connected.contains(e.key)),
          },
          onOpen: (key) => _openCalibrationForEarbud(key, _earbuds[key]!),
        ),
        const SizedBox(height: 18),
        ..._buildDeviceGroup(
          type: DeviceType.belt,
          devices: {
            for (final e in _belts.entries)
              e.key: (name: e.value.modelId, isConnected: _connected.contains(e.key)),
          },
          onOpen: _openBeltSetup,
        ),
        const SizedBox(height: 20),
        const Spacer(),
        const LegendBox(),
      ],
    );
  }

  /// Message shown above the (empty) lists if the devices could not be
  /// loaded; icon and text, not colour alone.
  Widget _buildLoadError() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: AppColors.text(context), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Deine Geräte konnten nicht geladen werden. '
            'Bitte starte die App später noch einmal.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  /// One group of the list: its heading and either the device cards or a hint
  /// that the group is still empty.
  ///
  /// [devices] maps each device key (BD_ADDR) to what its card shows.
  List<Widget> _buildDeviceGroup({
    required DeviceType type,
    required Map<String, ({String name, bool isConnected})> devices,
    required Future<void> Function(String key) onOpen,
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
      if (devices.isEmpty)
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
        for (final MapEntry(:key, :value) in devices.entries)
          Padding(
            key: ValueKey(key),
            padding: const EdgeInsets.only(bottom: 10),
            child: DeviceCard(
              name: value.name,
              type: type,
              isConnected: value.isConnected,
              onDelete: () => _removeDevice(type, key),
              onTap: () => onOpen(key),
            ),
          ),
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

    final authButtons = widget.isSignedIn
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
