// lib/features/device/widgets/device_type.dart
//
// The two hardware types and their user-visible texts, plus the (still
// simulated) device scan.

import 'package:flutter/material.dart';

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

/// Simulated Bluetooth device discovery for the given [type].
///
/// Replace this list / function with a real BLE/bluetooth_classic scan result.
///
/// TODO(improve): Use `AudioDeviceService` (Android MethodChannel) or a
/// Bluetooth package to get real devices. The result should contain the
/// `BD_ADDR` as well as the name, so devices can be stored under real map keys
/// instead of `dummy_mac_<timestamp>`.
Future<List<String>> scanForSystemDevices(DeviceType type) async {
  // Simulate a ~1.5 s scan delay.
  await Future.delayed(const Duration(milliseconds: 1500));
  // TODO: replace with real platform scan, e.g. flutter_blue_plus or
  //       bluetooth_classic:  BluetoothClassic().getPairedDevices()
  switch (type) {
    case DeviceType.earbuds:
      return [
        'AirPods Pro',
        'Sony WH-1000XM5',
        'Bose QC45',
        'JBL Live 660NC',
        'Sennheiser HD 450BT',
      ];
    case DeviceType.belt:
      return [
        'SoundPilot Belt 1',
        'SoundPilot Belt 2',
        'FeelSpace naviBelt',
      ];
  }
}
