// lib/features/device/widgets/device_type.dart
//
// The two hardware types and their user-visible texts, plus the device scan
// (real headphones on Android, simulated belts).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_logger.dart';
import '../../../core/services/audio_device_service.dart';

/// The two hardware types the app manages.
///
/// Replaces the bare strings 'Earbuds' / 'Gürtel' that used to be compared all
/// over the device screen: every user-visible word of a type now lives here, so
/// a belt can never be offered with a headphone text again.
enum DeviceType {
  earbuds(
    label: 'Earbuds',
    singular: 'Kopfhörer',
    icon: Icons.headphones_rounded,
    scanButton: 'Kopfhörer suchen',
    scanRunning: 'Kopfhörer werden gesucht...',
    manualLabel: 'Name der Kopfhörer',
    manualHint: 'z. B. Meine Kopfhörer',
    emptyList: 'Noch keine Kopfhörer hinzugefügt.',
    // Earbuds are calibrated (volume left/right), belts are set up (warning
    // distance, vibration) — the dialog says which one follows.
    nextStep: 'Nach dem Hinzufügen wird die Kalibrierung gestartet.',
  ),
  belt(
    label: 'Gürtel',
    singular: 'Gürtel',
    icon: Icons.vibration_rounded,
    scanButton: 'Gürtel suchen',
    scanRunning: 'Gürtel werden gesucht...',
    manualLabel: 'Name des Gürtels',
    manualHint: 'z. B. Mein Gürtel',
    emptyList: 'Noch keine Gürtel hinzugefügt.',
    nextStep: 'Nach dem Hinzufügen wird die Einrichtung gestartet.',
  );

  const DeviceType({
    required this.label,
    required this.singular,
    required this.icon,
    required this.scanButton,
    required this.scanRunning,
    required this.manualLabel,
    required this.manualHint,
    required this.emptyList,
    required this.nextStep,
  });

  /// Name of the group in the list and on the type selector.
  final String label;

  /// Name of a single device, used inside sentences.
  final String singular;

  /// Icon of a device of this type.
  final IconData icon;

  /// Label of the scan button.
  final String scanButton;

  /// Status text while the scan runs.
  final String scanRunning;

  /// Screen-reader label of the manual name field.
  final String manualLabel;

  /// Placeholder of the manual name field.
  final String manualHint;

  /// Text shown instead of an empty device list.
  final String emptyList;

  /// Hint about what happens right after the device was added.
  final String nextStep;
}

/// A device found by [scanForDevices].
@immutable
class ScannedDevice {
  /// Name shown in the list and stored as `modelId`.
  final String name;

  /// Bluetooth address (BD_ADDR), the map key the device is stored under;
  /// null if unknown (belts, which are still simulated).
  final String? address;

  /// Whether the device is connected right now; null if unknown (belts).
  final bool? isConnected;

  const ScannedDevice({required this.name, this.address, this.isConnected});
}

/// Result of [scanForDevices].
sealed class ScanOutcome {
  const ScanOutcome();
}

/// The scan ran; [devices] may be empty.
class ScanFound extends ScanOutcome {
  final List<ScannedDevice> devices;
  const ScanFound(this.devices);
}

/// Bluetooth is switched off.
class ScanBluetoothOff extends ScanOutcome {
  const ScanBluetoothOff();
}

/// The Bluetooth permission ("Geräte in der Nähe") is missing.
class ScanPermissionMissing extends ScanOutcome {
  /// Android no longer asks; only the app settings can grant it.
  final bool permanently;
  const ScanPermissionMissing({required this.permanently});
}

/// The native side reported an error.
class ScanFailed extends ScanOutcome {
  const ScanFailed();
}

/// Signature of [scanForDevices]; the add dialog takes it so tests can
/// replace the scan.
typedef DeviceScanner = Future<ScanOutcome> Function(DeviceType type);

/// Looks for devices of the given [type].
///
/// Earbuds: the Bluetooth headphones that are paired or connected in the
/// Android settings ([AudioDeviceService.findHeadphones]). Asks for the
/// Bluetooth permission first if needed. Without Bluetooth (browser, desktop,
/// emulator) the list is simulated.
///
/// Belts: still a simulated list without addresses.
Future<ScanOutcome> scanForDevices(DeviceType type) async {
  switch (type) {
    case DeviceType.earbuds:
      return _scanForHeadphones();
    case DeviceType.belt:
      // Simulate a ~1.5 s scan delay.
      await Future.delayed(const Duration(milliseconds: 1500));
      // TODO: replace with real platform scan, e.g. flutter_blue_plus or
      //       bluetooth_classic:  BluetoothClassic().getPairedDevices()
      return const ScanFound([
        ScannedDevice(name: 'SoundPilot Belt 1'),
        ScannedDevice(name: 'SoundPilot Belt 2'),
        ScannedDevice(name: 'FeelSpace naviBelt'),
      ]);
  }
}

Future<ScanOutcome> _scanForHeadphones() async {
  try {
    if (!await AudioDeviceService.usesSimulatedHeadphones()) {
      if (await AudioDeviceService.getBluetoothState() == BluetoothState.off) {
        return const ScanBluetoothOff();
      }
      // NOTE: Required, not optional: without it the paired headphones are
      // missing, and Android 12+ may hide the real address.
      final permission = await AudioDeviceService.requestBluetoothPermission();
      if (permission != BluetoothPermissionStatus.granted) {
        return ScanPermissionMissing(
          permanently:
              permission == BluetoothPermissionStatus.permanentlyDenied,
        );
      }
    }

    final headphones = await AudioDeviceService.findHeadphones();
    return ScanFound([
      for (final h in headphones)
        ScannedDevice(
          name: h.name,
          // Android 7-8 may not report the address; such headphones are
          // stored under a temporary key like a manual entry.
          address: h.address.isEmpty ? null : h.address,
          isConnected: h.isConnected,
        ),
    ]);
  } on PlatformException catch (e) {
    logger.e('scanForDevices: Headphone scan failed', error: e);
    return const ScanFailed();
  } on MissingPluginException catch (e) {
    logger.e('scanForDevices: No native side', error: e);
    return const ScanFailed();
  }
}
