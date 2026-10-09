// lib/core/services/audio_device_service.dart
//
// Dart side of the native Android audio device query (MethodChannel).

import 'package:flutter/services.dart';

/// Represents a single audio output device reported by Android.
class AudioDeviceInfo {
  /// Device id as reported by the native side.
  final int id;

  /// Human-readable device name as reported by the native side.
  final String productName;

  /// Device type as a string (e.g. Bluetooth A2DP, wired headset, USB audio).
  final String type;

  /// Whether this is Bluetooth headphones (A2DP, SCO or LE Audio).
  final bool isBluetooth;

  /// Bluetooth address (BD_ADDR) for Bluetooth devices; empty below
  /// Android 9 and for most other device types.
  final String address;

  const AudioDeviceInfo({
    required this.id,
    required this.productName,
    required this.type,
    this.isBluetooth = false,
    this.address = '',
  });

  factory AudioDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    final isBluetooth = map['isBluetooth'];
    final address = map['address'];
    return AudioDeviceInfo(
      id: map['id'] as int,
      productName: map['productName'] as String,
      type: map['type'] as String,
      isBluetooth: isBluetooth is bool && isBluetooth,
      address: address is String ? address : '',
    );
  }

  @override
  String toString() => '$productName ($type)';
}

/// Whether the app may use Bluetooth (Android 12+: `BLUETOOTH_CONNECT`).
enum BluetoothPermissionStatus {
  granted,

  /// Not granted yet; asking again shows the system dialog.
  denied,

  /// Android no longer shows the dialog; only the app settings can grant it
  /// ([AudioDeviceService.openAppSettings]).
  permanentlyDenied,
}

/// Whether Bluetooth is switched on.
enum BluetoothState {
  on,
  off,

  /// The phone has no Bluetooth (e.g. an emulator without virtual Bluetooth).
  unavailable,
}

/// Calls into native Android (AudioManager) to list all current audio
/// output devices (Bluetooth A2DP, wired headset, USB audio, etc.).
///
/// Requires API level 23+ (Android 6.0) — covers 99 %+ of active devices.
///
/// NOTE: The native Android side has to handle the channel
/// `com.soundpilot/audio_devices`. On other platforms (e.g. Windows) the call
/// throws a [MissingPluginException].
///
/// TODO(improve): This service is not used by any screen yet. DeviceScreen
/// still uses a simulated scan (`_scanForSystemHeadphones`). It should be
/// connected there and the result should provide real BD_ADDR keys.
class AudioDeviceService {
  static const MethodChannel _channel =
      MethodChannel('com.soundpilot/audio_devices');

  /// Returns all currently connected audio output devices.
  /// Throws a [PlatformException] if the native side reports an error.
  static Future<List<AudioDeviceInfo>> getConnectedOutputDevices() async {
    final List<dynamic> result =
        await _channel.invokeMethod('getConnectedOutputDevices');

    return result
        .cast<Map<dynamic, dynamic>>()
        .map(AudioDeviceInfo.fromMap)
        .toList();
  }

  // ── Bluetooth permission and state ─────────────────────────────────────────

  /// Current Bluetooth permission, without asking the user.
  static Future<BluetoothPermissionStatus> getBluetoothPermissionStatus() async {
    final String? status =
        await _channel.invokeMethod('getBluetoothPermissionStatus');
    return _permissionFromString(status);
  }

  /// Shows the system dialog for the Bluetooth permission if it is not
  /// granted yet, and returns the result. Below Android 12 it is always
  /// [BluetoothPermissionStatus.granted].
  ///
  /// NOTE: If the status is [BluetoothPermissionStatus.permanentlyDenied],
  /// Android does not show the dialog; offer [openAppSettings] instead.
  static Future<BluetoothPermissionStatus> requestBluetoothPermission() async {
    final String? status =
        await _channel.invokeMethod('requestBluetoothPermission');
    return _permissionFromString(status);
  }

  /// Whether Bluetooth is on, off or missing.
  static Future<BluetoothState> getBluetoothState() async {
    final String? state = await _channel.invokeMethod('getBluetoothState');
    return switch (state) {
      'on' => BluetoothState.on,
      'off' => BluetoothState.off,
      _ => BluetoothState.unavailable,
    };
  }

  /// Opens the Android Bluetooth settings (to switch Bluetooth on or pair
  /// headphones). Returns false if the phone has no such page.
  static Future<bool> openBluetoothSettings() async =>
      await _channel.invokeMethod<bool>('openBluetoothSettings') ?? false;

  /// Opens the app's page in the Android settings (to grant a permanently
  /// denied permission). Returns false if the phone has no such page.
  static Future<bool> openAppSettings() async =>
      await _channel.invokeMethod<bool>('openAppSettings') ?? false;

  static BluetoothPermissionStatus _permissionFromString(String? status) {
    return switch (status) {
      'granted' => BluetoothPermissionStatus.granted,
      'permanentlyDenied' => BluetoothPermissionStatus.permanentlyDenied,
      _ => BluetoothPermissionStatus.denied,
    };
  }
}
