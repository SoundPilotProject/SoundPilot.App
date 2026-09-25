// lib/features/device/screens/device_screen.dart
//
// Main screen: list of earbuds and belts, add/remove devices, open their
// calibration/setup, login/register (guest) or logout.
//
// TODO(improve): This file has about 1,170 lines. Move the add-device dialog,
// `_DeviceCard`, `_LegendBox` and the buttons into their own files (e.g. under
// `features/device/widgets/`). The repeated `GoogleFonts.poppins(...)` styles
// should come from a shared TextTheme (see SoundPilotApp).

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

// ── Simulated Bluetooth device discovery ─────────────────────────────────────

/// Simulated Bluetooth device discovery.
///
/// Replace this list / function with a real BLE/bluetooth_classic scan result.
///
/// TODO(improve): Use `AudioDeviceService` (Android MethodChannel) or a
/// Bluetooth package to get real devices. The result should contain the
/// `BD_ADDR` as well as the name, so devices can be stored under real map keys
/// instead of `dummy_mac_<timestamp>`.
Future<List<String>> _scanForSystemHeadphones() async {
  // Simulate a ~1.5 s scan delay.
  await Future.delayed(const Duration(milliseconds: 1500));
  // TODO: replace with real platform scan, e.g. flutter_blue_plus or
  //       bluetooth_classic:  BluetoothClassic().getPairedDevices()
  return [
    'AirPods Pro',
    'Sony WH-1000XM5',
    'Bose QC45',
    'JBL Live 660NC',
    'Sennheiser HD 450BT',
  ];
}

// ── Device screen ────────────────────────────────────────────────────────────

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

  /// Signs out and reloads the (now guest) devices.
  ///
  /// TODO(improve): The `Future.delayed(2 s)` only keeps the loading screen
  /// visible for a moment and slows the UI down on purpose (same in
  /// TestPage._finishExercise and BeltVibrationScreen._finishSetup;
  /// StartScreen._continueAsGuest no longer has it, see there).
  Future<void> _logout() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(text: 'Wird abgemeldet...'),
      ),
    );

    await AuthService().logout();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.pop(context);

    // Reload devices for the new (guest) state
    setState(() {
      _isLoadingDevices = true;
      _earbuds = {};
      _belts = {};
    });
    await _loadDevices();
  }

  // ── Remove ─────────────────────────────────────────────────────────────────

  /// Removes the device at position [index] of the given [category]
  /// ('Earbuds', otherwise belts) and saves the list.
  ///
  /// TODO(improve): The device is found by its position in the map
  /// (`keys.elementAt(index)`). This only works as long as the iteration order
  /// stays stable. Pass the map key (BD_ADDR) instead of the index, and use an
  /// enum instead of the category strings 'Earbuds' / 'Gürtel'.
  void _removeDevice(String category, int index) {
    setState(() {
      if (category == 'Earbuds') {
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

  /// Shows the add-device dialog and stores the chosen device. The calibration
  /// is opened right away if the dialog asks for it (`openCalibration`, which
  /// the dialog currently sets only for earbuds).
  ///
  /// TODO(improve): `newIndex` is computed from the map length before the
  /// device is added. This relies on the new entry being last; use the new
  /// map key instead.
  Future<void> _openAddDeviceDialog() async {
    final result = await showDialog<_AddDeviceResult>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const _AddDeviceDialog(),
    );

    if (!mounted || result == null) return;

    // Generate a temporary unique ID since we don't have real MAC addresses yet
    // (TODO: real BD_ADDR from the Bluetooth scan, see _scanForSystemHeadphones)
    final tempMacAddress = 'dummy_mac_${DateTime.now().millisecondsSinceEpoch}';

    if (result.type == 'Earbuds') {
      final newIndex = _earbuds.length;
      setState(() {
        // Add to map using the new MAC address key
        _earbuds[tempMacAddress] = HeadphoneCalib(
          modelId: result.name,
          isConnected: false,
        );
      });
      _persistDevices();

      // Immediately open calibration for the newly added earbud.
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

      if (result.openCalibration) {
        await _openBeltSetup(newIndex);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDevices) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary(context),
          ),
        ),
      );
    }

    final totalDevices = _earbuds.length + _belts.length;
    final shouldScroll = totalDevices > 4;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          child: shouldScroll
              ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _buildContent(scrollable: true),
          )
              : _buildContent(scrollable: false),
        ),
      ),
    );
  }

  /// Title, device lists and legend. With more than 4 devices the content is
  /// scrollable ([scrollable]) and uses slightly larger text; otherwise the
  /// legend is pushed to the bottom with a Spacer.
  Widget _buildContent({required bool scrollable}) {
    final double titleSize = scrollable ? 38 : 34;
    final double subtitleSize = scrollable ? 24 : 22;
    final double spacing = scrollable ? 12.0 : 10.0;

    final children = [
      _buildTopButtons(),
      SizedBox(height: scrollable ? 20 : 16),
      Text(
        'Geräte',
        style: GoogleFonts.poppins(
          fontSize: titleSize,
          fontWeight: FontWeight.w900,
          color: AppColors.text(context),
          height: 1.0,
        ),
      ),
      SizedBox(height: scrollable ? 16 : 12),
      Text(
        'Earbuds',
        style: GoogleFonts.poppins(
          fontSize: subtitleSize,
          fontWeight: FontWeight.w900,
          color: AppColors.text(context),
          height: 1.0,
        ),
      ),
      SizedBox(height: spacing),
      // Iterate through the Map values for Earbuds
      ...List.generate(
        _earbuds.length,
            (index) {
          final device = _earbuds.values.elementAt(index);
          return Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: _DeviceCard(
              name: device.modelId, // Updated from .name to .modelId
              isConnected: device.isConnected,
              onDelete: () => _removeDevice('Earbuds', index),
              onTap: () => _openCalibrationForEarbud(index),
            ),
          );
        },
      ),
      SizedBox(height: spacing),
      Text(
        'Gürtel',
        style: GoogleFonts.poppins(
          fontSize: subtitleSize,
          fontWeight: FontWeight.w900,
          color: AppColors.text(context),
          height: 1.0,
        ),
      ),
      SizedBox(height: spacing),
      // Iterate through the Map values for Belts
      ...List.generate(
        _belts.length,
            (index) {
          final device = _belts.values.elementAt(index);
          return Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: _DeviceCard(
              name: device.modelId, // Updated from .name to .modelId
              isConnected: device.isConnected,
              onDelete: () => _removeDevice('Gürtel', index),
              onTap: () => _openBeltSetup(index),
            ),
          );
        },
      ),
    ];

    if (scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
          const SizedBox(height: 18),
          const _LegendBox(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...children,
        const Spacer(),
        const _LegendBox(),
      ],
    );
  }

  /// Top button row: 'Abmelden' + add button if signed in, otherwise 'Login',
  /// 'Registrieren' + add button.
  Widget _buildTopButtons() {
    if (_isLoggedIn) {
      return Row(
        children: [
          Expanded(
            flex: 7,
            child: _TopActionButton(text: 'Abmelden', onPressed: _logout),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: _IconSquareButton(
              backgroundColor: AppColors.primary(context),
              icon: Icons.add,
              iconColor: AppColors.onPrimary(context),
              onPressed: _openAddDeviceDialog,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _TopActionButton(
            text: 'Login',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(returnToDeviceOnBack: true),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: _TopActionButton(
            text: 'Registrieren',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterScreen(returnToDeviceOnBack: true),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _IconSquareButton(
            backgroundColor: AppColors.primary(context),
            icon: Icons.add,
            iconColor: AppColors.onPrimary(context),
            onPressed: _openAddDeviceDialog,
          ),
        ),
      ],
    );
  }
}

// ── Add-Device Dialog (two tabs: system scan | manual) ───────────────────────

/// Result of the add-device dialog.
class _AddDeviceResult {
  /// Device type: 'Earbuds' or 'Gürtel'.
  final String type;

  /// Device name (typed in or chosen from the scan).
  final String name;

  /// Whether the calibration/setup should start right after adding.
  final bool openCalibration;

  const _AddDeviceResult({
    required this.type,
    required this.name,
    this.openCalibration = false,
  });
}

/// Dialog to add a device: choose the type, then either pick a device from the
/// (currently simulated) system scan or type a name manually.
///
/// Pops with an [_AddDeviceResult], or `null` if cancelled.
class _AddDeviceDialog extends StatefulWidget {
  const _AddDeviceDialog();

  @override
  State<_AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<_AddDeviceDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Shared state
  String _selectedType = 'Earbuds';

  // Manual-entry tab state
  final TextEditingController _nameController = TextEditingController();

  // System-scan tab state
  bool _isScanning = false;
  List<String> _scannedDevices = [];
  String? _selectedScannedDevice;
  bool _scanDone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Runs the (simulated) scan and shows the found devices.
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scannedDevices = [];
      _selectedScannedDevice = null;
      _scanDone = false;
    });

    final devices = await _scanForSystemHeadphones();

    if (!mounted) return;
    setState(() {
      _scannedDevices = devices;
      _isScanning = false;
      _scanDone = true;
    });
  }

  /// Confirms the manually typed name (ignored if empty).
  void _confirmManual() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(_AddDeviceResult(
      type: _selectedType,
      name: name,
      openCalibration: _selectedType == 'Earbuds',
    ));
  }

  /// Confirms the device selected in the scan list (ignored if none).
  void _confirmScanned() {
    if (_selectedScannedDevice == null) return;

    Navigator.of(context).pop(_AddDeviceResult(
      type: _selectedType,
      name: _selectedScannedDevice!,
      openCalibration: _selectedType == 'Earbuds',
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Gerät hinzufügen',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.text(context),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 18),

            // Device type selector
            _TypeSelector(
              selectedType: _selectedType,
              onChanged: (t) => setState(() => _selectedType = t),
            ),
            const SizedBox(height: 16),

            // Tabs
            _buildTabBar(),
            const SizedBox(height: 12),

            // Tab content
            SizedBox(
              height: 260,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScanTab(),
                  _buildManualTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary(context),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelColor: AppColors.onPrimary(context),
        unselectedLabelColor: AppColors.mutedText(context),
        tabs: const [
          Tab(text: 'System-Geräte'),
          Tab(text: 'Manuell'),
        ],
      ),
    );
  }

  // ── System-Scan Tab ────────────────────────────────────────────────────────

  Widget _buildScanTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isScanning ? null : _startScan,
            icon: _isScanning
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.onPrimary(context),
              ),
            )
                : Icon(
              Icons.bluetooth_searching_rounded,
              color: AppColors.onPrimary(context),
              size: 22,
            ),
            label: Text(
              _isScanning ? 'Suche läuft...' : 'Kopfhörer suchen',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.onPrimary(context),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Results list or placeholder
        Expanded(
          child: _isScanning
              ? const Center(child: SizedBox.shrink())
              : !_scanDone
              ? Center(
            child: Text(
              'Tippe auf „Kopfhörer suchen"\num angeschlossene Geräte\nzu finden.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText(context),
              ),
            ),
          )
              : _scannedDevices.isEmpty
              ? Center(
            child: Text(
              'Keine Geräte gefunden.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText(context),
              ),
            ),
          )
              : ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _scannedDevices.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final name = _scannedDevices[i];
              final selected = _selectedScannedDevice == name;
              return GestureDetector(
                onTap: () => setState(
                        () => _selectedScannedDevice = name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary(context)
                        : AppColors.surface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary(context)
                          : AppColors.inputBorder(context),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        size: 22,
                        color: selected
                            ? AppColors.onPrimary(context)
                            : AppColors.mutedText(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.onPrimary(context)
                                : AppColors.text(context),
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 22,
                          color: AppColors.onPrimary(context),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Confirm / cancel row
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                'Abbrechen',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary(context),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedScannedDevice != null
                    ? _confirmScanned
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  disabledBackgroundColor:
                  AppColors.inactiveButton(context),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Text(
                  'Hinzufügen',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Manual Tab ─────────────────────────────────────────────────────────────

  Widget _buildManualTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gerätename:',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 62,
          child: TextField(
            controller: _nameController,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
            decoration: InputDecoration(
              hintText: 'z. B. Meine Kopfhörer',
              hintStyle: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText(context),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.inputBorder(context),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.primary(context),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        if (_selectedType == 'Earbuds') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.primary(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nach dem Hinzufügen wird\ndie Kalibrierung gestartet.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                'Abbrechen',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary(context),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _confirmManual,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Text(
                  'Hinzufügen',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Device-type toggle (Earbuds / Gürtel) ────────────────────────────────────

/// Two-button toggle to choose the device type ('Earbuds' or 'Gürtel').
class _TypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onChanged;

  const _TypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['Earbuds', 'Gürtel'].map((type) {
        final selected = selectedType == type;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type == 'Earbuds' ? 6 : 0,
              left: type == 'Gürtel' ? 6 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary(context)
                      : AppColors.surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary(context)
                        : AppColors.inputBorder(context),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  type,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? AppColors.onPrimary(context)
                        : AppColors.mutedText(context),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared reusable widgets ──────────────────────────────────────────────────

/// Large rounded text button for the top row ('Abmelden', 'Login', ...).
class _TopActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _TopActionButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(context),
          foregroundColor: AppColors.onPrimary(context),
          elevation: 4,
          // TODO(improve): `withOpacity` is deprecated, use
          // `withValues(alpha: ...)` (applies to all withOpacity calls in
          // this file).
          shadowColor: Colors.black.withOpacity(0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimary(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Square button with an icon (the '+' button next to the top actions).
class _IconSquareButton extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _IconSquareButton({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 34, color: iconColor),
      ),
    );
  }
}

/// Card for one device: name, connection dot (green/red) and a delete icon.
/// Tapping the card calls [onTap] (calibration/setup).
class _DeviceCard extends StatelessWidget {
  final String name;

  /// Green dot if `true`, red dot otherwise (see [_LegendBox]).
  final bool isConnected;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _DeviceCard({
    required this.name,
    required this.isConnected,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 74,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.onPrimary(context),
              ),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.connectedGreen
                  : AppColors.disconnectedRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close_rounded,
              color: AppColors.onPrimary(context),
              size: 32,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Legend that explains the green/red connection dots of the [_DeviceCard]s.
class _LegendBox extends StatelessWidget {
  const _LegendBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.legendBackground(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.legendBorder(context), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.connectedGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Verbunden',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.disconnectedRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Nicht verbunden',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}