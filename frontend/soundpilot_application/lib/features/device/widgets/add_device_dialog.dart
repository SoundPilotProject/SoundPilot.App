// lib/features/device/widgets/add_device_dialog.dart
//
// Dialog to add an earbud or a belt (system scan or manual name).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'device_type.dart';

/// Result of the [AddDeviceDialog].
class AddDeviceResult {
  /// Type of the chosen device.
  final DeviceType type;

  /// Device name (typed in or chosen from the scan).
  final String name;

  /// Whether the calibration/setup should start right after adding.
  final bool openCalibration;

  const AddDeviceResult({
    required this.type,
    required this.name,
    this.openCalibration = false,
  });
}

/// Dialog to add a device: choose the type, then either pick a device from the
/// (currently simulated) system scan or type a name manually.
///
/// Every label follows the selected [DeviceType], so choosing 'Gürtel' really
/// offers a belt search instead of the headphone texts.
///
/// Pops with an [AddDeviceResult], or `null` if cancelled.
class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

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

  /// Switches the device type and drops the scan result, which belonged to the
  /// previous type.
  void _selectType(DeviceType type) {
    if (type == _selectedType) return;

    setState(() {
      _selectedType = type;
      _scannedDevices = [];
      _selectedScannedDevice = null;
      _scanDone = false;
    });
  }

  /// Runs the (simulated) scan for the selected type and shows the result.
  Future<void> _startScan() async {
    final type = _selectedType;

    setState(() {
      _isScanning = true;
      _scannedDevices = [];
      _selectedScannedDevice = null;
      _scanDone = false;
    });

    final devices = await scanForSystemDevices(type);

    if (!mounted) return;
    // The user may have switched the type while the scan was running.
    if (type != _selectedType) return;

    setState(() {
      _scannedDevices = devices;
      _isScanning = false;
      _scanDone = true;
    });
  }

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
      name: _selectedScannedDevice!,
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
                  style: GoogleFonts.poppins(
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
        labelStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(
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

  /// Placeholder, empty state or the list of found devices.
  Widget _buildScanResults(DeviceType type) {
    if (_isScanning) {
      return Center(
        child: Semantics(
          liveRegion: true,
          child: _HintText(text: type.scanRunning),
        ),
      );
    }

    if (!_scanDone) {
      return Center(
        child: _HintText(
          text: 'Tippe auf „${type.scanButton}“,\n'
              'um verbundene Geräte zu finden.',
        ),
      );
    }

    if (_scannedDevices.isEmpty) {
      return Center(
        child: _HintText(text: 'Keine ${type.singular} gefunden.'),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _scannedDevices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final name = _scannedDevices[i];
        final selected = _selectedScannedDevice == name;

        return Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _selectedScannedDevice = name),
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
                    type.icon,
                    size: 24,
                    color: selected
                        ? AppColors.onPrimary(context)
                        : AppColors.mutedText(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.onPrimary(context)
                            : AppColors.text(context),
                      ),
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
                  style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(
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
                    hintStyle: GoogleFonts.poppins(
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
                          style: GoogleFonts.poppins(
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
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.mutedText(context),
        height: 1.35,
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
            style: GoogleFonts.poppins(
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
            style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(
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
