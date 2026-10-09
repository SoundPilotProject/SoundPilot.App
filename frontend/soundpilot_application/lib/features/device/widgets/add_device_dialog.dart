// lib/features/device/widgets/add_device_dialog.dart
//
// Dialog to add an earbud or a belt (system scan or manual name).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/audio_device_service.dart';
import '../../../core/theme/app_colors.dart';
import 'device_type.dart';

/// Result of the [AddDeviceDialog].
class AddDeviceResult {
  /// Type of the chosen device.
  final DeviceType type;

  /// Device name (typed in or chosen from the scan).
  final String name;

  /// Bluetooth address (BD_ADDR) from the scan; null for a typed-in name or a
  /// device without a known address (the caller then makes a temporary key).
  final String? address;

  /// Whether the calibration/setup should start right after adding.
  final bool openCalibration;

  const AddDeviceResult({
    required this.type,
    required this.name,
    this.address,
    this.openCalibration = false,
  });
}

/// Dialog to add a device: choose the type, then either pick a device from the
/// system scan ([scanForDevices]: real headphones on Android, simulated belts)
/// or type a name manually.
///
/// Every label follows the selected [DeviceType], so choosing 'Gürtel' really
/// offers a belt search instead of the headphone texts.
///
/// Pops with an [AddDeviceResult], or `null` if cancelled.
class AddDeviceDialog extends StatefulWidget {
  /// The scan; tests pass a fake. Defaults to [scanForDevices].
  final DeviceScanner scanner;

  /// Addresses of the devices that are already in the list. Found devices
  /// with one of them are shown as already added and cannot be picked, so
  /// adding them again cannot overwrite their calibration.
  final Set<String> existingAddresses;

  const AddDeviceDialog({
    super.key,
    this.scanner = scanForDevices,
    this.existingAddresses = const {},
  });

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Shared state
  DeviceType _selectedType = DeviceType.earbuds;

  // Manual-entry tab state
  final TextEditingController _nameController = TextEditingController();

  // System-scan tab state
  bool _isScanning = false;

  /// Result of the last scan; null before the first scan.
  ScanOutcome? _outcome;
  ScannedDevice? _selectedScannedDevice;

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

  /// Switches the device type and drops the scan result, which belonged to the
  /// previous type.
  void _selectType(DeviceType type) {
    if (type == _selectedType) return;

    setState(() {
      _selectedType = type;
      _outcome = null;
      _selectedScannedDevice = null;
    });
  }

  /// Runs the scan for the selected type and shows the result.
  Future<void> _startScan() async {
    final type = _selectedType;

    setState(() {
      _isScanning = true;
      _outcome = null;
      _selectedScannedDevice = null;
    });

    final outcome = await widget.scanner(type);

    if (!mounted) return;
    // The user may have switched the type while the scan was running.
    if (type != _selectedType) {
      setState(() => _isScanning = false);
      return;
    }

    setState(() {
      _outcome = outcome;
      _isScanning = false;
    });
  }

  /// Whether [device] is already in the device list.
  bool _isAlreadyAdded(ScannedDevice device) =>
      device.address != null &&
      widget.existingAddresses.contains(device.address);

  /// Confirms the manually typed name (ignored if empty).
  ///
  /// NOTE: `openCalibration` is true for both types. Belts used to skip it, so
  /// adding a belt ended without its setup.
  void _confirmManual() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(AddDeviceResult(
      type: _selectedType,
      name: name,
      openCalibration: true,
    ));
  }

  /// Confirms the device selected in the scan list (ignored if none).
  void _confirmScanned() {
    if (_selectedScannedDevice == null) return;

    Navigator.of(context).pop(AddDeviceResult(
      type: _selectedType,
      name: _selectedScannedDevice!.name,
      address: _selectedScannedDevice!.address,
      openCalibration: true,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Bounded height for the TabBarView, which cannot size itself. It follows
    // the screen so the dialog does not overflow on small phones.
    final tabHeight = (screenHeight * 0.44).clamp(260.0, 420.0);

    return Dialog(
      backgroundColor: AppColors.background(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Gerät hinzufügen',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text(context),
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _TypeSelector(
                selectedType: _selectedType,
                onChanged: _selectType,
              ),
              const SizedBox(height: 14),

              _buildTabBar(),
              const SizedBox(height: 12),

              SizedBox(
                height: tabHeight,
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
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
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
        labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        labelColor: AppColors.onPrimary(context),
        unselectedLabelColor: AppColors.mutedText(context),
        tabs: const [
          Tab(text: 'Suchen'),
          Tab(text: 'Manuell'),
        ],
      ),
    );
  }

  // ── System-Scan Tab ────────────────────────────────────────────────────────

  Widget _buildScanTab() {
    final type = _selectedType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isScanning ? null : _startScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary(context),
            disabledBackgroundColor: AppColors.inactiveButton(context),
            elevation: 3,
            minimumSize: const Size(double.infinity, 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isScanning)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.bluetooth_searching_rounded,
                  color: AppColors.onPrimary(context),
                  size: 24,
                ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _isScanning ? 'Suche läuft...' : type.scanButton,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _isScanning
                        ? Colors.white
                        : AppColors.onPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _buildScanResults(type)),
        const SizedBox(height: 10),
        _DialogActions(
          confirmLabel: 'Hinzufügen',
          onConfirm: _selectedScannedDevice != null ? _confirmScanned : null,
        ),
      ],
    );
  }

  /// Placeholder, scan state (Bluetooth off, permission missing, nothing
  /// found, error) or the list of found devices.
  Widget _buildScanResults(DeviceType type) {
    if (_isScanning) {
      return Center(
        child: Semantics(
          liveRegion: true,
          child: _HintText(text: type.scanRunning),
        ),
      );
    }

    return switch (_outcome) {
      null => _ScanMessage(
          text: 'Tippe auf „${type.scanButton}“,\n'
              'um verbundene Geräte zu finden.',
        ),
      ScanBluetoothOff() => const _ScanMessage(
          text: 'Bluetooth ist ausgeschaltet. Schalte es ein und suche dann '
              'noch einmal.',
          actionLabel: 'Bluetooth-Einstellungen öffnen',
          onAction: AudioDeviceService.openBluetoothSettings,
        ),
      ScanPermissionMissing(permanently: false) => _ScanMessage(
          text: 'SoundPilot braucht die Berechtigung „Geräte in der Nähe“, '
              'um deine Kopfhörer zu finden. Tippe noch einmal auf '
              '„${type.scanButton}“ und erlaube sie.',
        ),
      ScanPermissionMissing(permanently: true) => const _ScanMessage(
          text: 'Die Berechtigung „Geräte in der Nähe“ ist abgelehnt. Erlaube '
              'sie in den App-Einstellungen unter „Berechtigungen“.',
          actionLabel: 'App-Einstellungen öffnen',
          onAction: AudioDeviceService.openAppSettings,
        ),
      ScanFailed() => const _ScanMessage(
          text: 'Die Suche hat nicht funktioniert. Bitte versuche es noch '
              'einmal.',
        ),
      ScanFound(devices: final devices) when devices.isEmpty =>
        type == DeviceType.earbuds
            ? const _ScanMessage(
                text: 'Keine Kopfhörer gefunden. Kopple deine Kopfhörer '
                    'zuerst in den Bluetooth-Einstellungen.',
                actionLabel: 'Bluetooth-Einstellungen öffnen',
                onAction: AudioDeviceService.openBluetoothSettings,
              )
            : _ScanMessage(text: 'Keine ${type.singular} gefunden.'),
      ScanFound(devices: final devices) => _buildDeviceList(type, devices),
    };
  }

  Widget _buildDeviceList(DeviceType type, List<ScannedDevice> devices) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final device = devices[i];
        final alreadyAdded = _isAlreadyAdded(device);
        final selected = identical(_selectedScannedDevice, device);
        // Status as text, so it is not carried by colour alone.
        final status = alreadyAdded
            ? 'Bereits hinzugefügt'
            : switch (device.isConnected) {
                true => 'Verbunden',
                false => 'Gekoppelt, nicht verbunden',
                null => null,
              };
        final foreground =
            selected ? AppColors.onPrimary(context) : AppColors.text(context);
        final secondary = selected
            ? AppColors.onPrimary(context)
            : AppColors.mutedText(context);

        return Semantics(
          selected: selected,
          button: true,
          enabled: !alreadyAdded,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: alreadyAdded
                ? null
                : () => setState(() => _selectedScannedDevice = device),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
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
                    alreadyAdded ? Icons.check_rounded : type.icon,
                    size: 24,
                    color: secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: foreground,
                          ),
                        ),
                        if (status != null)
                          Text(
                            status,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Check mark, so the selection is not shown by colour alone.
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 24,
                      color: AppColors.onPrimary(context),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Manual Tab ─────────────────────────────────────────────────────────────

  Widget _buildManualTab() {
    final type = _selectedType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${type.manualLabel}:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirmManual(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                  decoration: InputDecoration(
                    // The caption above is decoration for sighted users; this
                    // invisible label is what screen readers announce.
                    labelText: type.manualLabel,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    labelStyle: const TextStyle(color: Colors.transparent),
                    hintText: type.manualHint,
                    // NOTE: The placeholder stays at w600 while the typed text
                    // is bold — see the same note in AuthTextField.
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                        width: 3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          type.nextStep,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedText(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _DialogActions(
          confirmLabel: 'Hinzufügen',
          onConfirm: _confirmManual,
        ),
      ],
    );
  }
}

/// Centred secondary text used for the placeholder and empty states.
class _HintText extends StatelessWidget {
  final String text;

  const _HintText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.mutedText(context),
        height: 1.35,
      ),
    );
  }
}

/// A scan state: a text and an optional button (e.g. to the Bluetooth
/// settings).
///
/// Scrolls, so a long text at a large system font size does not overflow the
/// fixed-height tab. Announced by screen readers when it appears.
///
/// NOTE: No icon on purpose: at normal font size the tab only has room for
/// the text and the button, and an icon pushed the button out of view.
class _ScanMessage extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final Future<Object?> Function()? onAction;

  const _ScanMessage({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(liveRegion: true, child: _HintText(text: text)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.settings_rounded),
                label: Text(
                  actionLabel!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary(context),
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  side: BorderSide(color: AppColors.primary(context), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 'Hinzufügen' / 'Abbrechen' block at the bottom of both dialog tabs.
///
/// The two buttons are stacked, not placed side by side: at large system font
/// sizes a row of both labels does not fit on a phone.
class _DialogActions extends StatelessWidget {
  final String confirmLabel;

  /// `null` disables the confirm button.
  final VoidCallback? onConfirm;

  const _DialogActions({
    required this.confirmLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary(context),
            disabledBackgroundColor: AppColors.inactiveButton(context),
            elevation: 3,
            minimumSize: const Size(double.infinity, 54),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          child: Text(
            confirmLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text(
            'Abbrechen',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primary(context),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Device-type toggle (Earbuds / Gürtel) ────────────────────────────────────

/// Two-button toggle to choose the [DeviceType].
///
/// The selected button carries a check mark as well as the accent colour, so
/// the choice is readable without distinguishing colours.
class _TypeSelector extends StatelessWidget {
  final DeviceType selectedType;
  final ValueChanged<DeviceType> onChanged;

  const _TypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight instead of CrossAxisAlignment.stretch: the row sits in a
    // scroll view, where stretching would ask for an infinite height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in DeviceType.values) ...[
            if (type != DeviceType.values.first) const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                selected: selectedType == type,
                button: true,
                child: _TypeSelectorButton(
                  type: type,
                  selected: selectedType == type,
                  onTap: () => onChanged(type),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One button of the [_TypeSelector].
class _TypeSelectorButton extends StatelessWidget {
  final DeviceType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeSelectorButton({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? AppColors.onPrimary(context) : AppColors.mutedText(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primary(context) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary(context)
                : AppColors.inputBorder(context),
            width: 1.5,
          ),
        ),
        // Icon above the label, so the label keeps the full button width even
        // at large system font sizes.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: foreground,
            ),
            const SizedBox(height: 2),
            Text(
              type.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
