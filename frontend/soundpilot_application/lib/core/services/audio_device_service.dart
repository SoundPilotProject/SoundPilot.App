// lib/core/services/audio_device_service.dart
//
// Dart side of the native Android audio device query (MethodChannel) and the
// Bluetooth headphones found through it.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a single audio output device reported by Android.
class AudioDeviceInfo {
  /// Device id as reported by the native side.
  final int id;

  /// Human-readable device name as reported by the native side.
  final String productName;

  /// Device type as a string (e.g. Bluetooth A2DP, wired headset, USB audio).
  final String type;

  /// Android's `AudioDeviceInfo.TYPE_*` constant; -1 if not reported.
  final int typeCode;

  /// Whether this is Bluetooth headphones (A2DP, SCO or LE Audio).
  final bool isBluetooth;

  /// Bluetooth address (BD_ADDR) for Bluetooth devices; empty below
  /// Android 9 and for most other device types.
  final String address;

  const AudioDeviceInfo({
    required this.id,
    required this.productName,
    required this.type,
    this.typeCode = -1,
    this.isBluetooth = false,
    this.address = '',
  });

  factory AudioDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    final typeCode = map['typeCode'];
    final isBluetooth = map['isBluetooth'];
    final address = map['address'];
    return AudioDeviceInfo(
      id: map['id'] as int,
      productName: map['productName'] as String,
      type: map['type'] as String,
      typeCode: typeCode is int ? typeCode : -1,
      isBluetooth: isBluetooth is bool && isBluetooth,
      address: address is String ? address : '',
    );
  }

  @override
  String toString() => '$productName ($type)';
}

/// Bluetooth headphones the user can add: connected, or paired in the
/// Android settings but not connected right now.
@immutable
class HeadphoneDevice {
  /// Name shown to the user (as set in the Android Bluetooth settings).
  final String name;

  /// Bluetooth address (BD_ADDR), upper case; the map key in `calibration`.
  ///
  /// NOTE: Empty for connected headphones on Android 7–8, where Android does
  /// not report the address of an output device and no paired entry matched.
  final String address;

  /// Whether the headphones are an active audio output right now.
  final bool isConnected;

  /// Id of the Android output device to route the test tone to
  /// ([AudioDeviceService.playTestTone]); null if not connected.
  final int? outputDeviceId;

  const HeadphoneDevice({
    required this.name,
    required this.address,
    required this.isConnected,
    this.outputDeviceId,
  });

  @override
  bool operator ==(Object other) =>
      other is HeadphoneDevice &&
      other.name == name &&
      other.address == address &&
      other.isConnected == isConnected &&
      other.outputDeviceId == outputDeviceId;

  @override
  int get hashCode => Object.hash(name, address, isConnected, outputDeviceId);

  @override
  String toString() =>
      '$name ($address, ${isConnected ? 'connected' : 'paired'})';
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
/// throws a [MissingPluginException]. Only [findHeadphones] and
/// [headphoneChanges] fall back to a simulated list there ([isSupported]).
///
/// TODO(improve): This service is not used by any screen yet. DeviceScreen
/// still uses a simulated scan (`scanForSystemDevices`). It should be
/// connected there and the result should provide real BD_ADDR keys.
class AudioDeviceService {
  static const MethodChannel _channel =
      MethodChannel('com.soundpilot/audio_devices');

  static const EventChannel _events =
      EventChannel('com.soundpilot/audio_device_events');

  // Android's AudioDeviceInfo.TYPE_* values used for sorting.
  static const int _typeBluetoothA2dp = 8;
  static const int _typeBleHeadset = 26;

  /// Whether the native side exists (Android app, not the browser).
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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

  /// Every change of the connected output devices, as the full list; the
  /// first event is the current list.
  static Stream<List<AudioDeviceInfo>> outputDeviceChanges() {
    return _events.receiveBroadcastStream().map((event) => (event as List)
        .cast<Map<dynamic, dynamic>>()
        .map(AudioDeviceInfo.fromMap)
        .toList());
  }

  /// Headphones paired in the Android settings (connected or not), as name
  /// and address. Throws a [PlatformException] with code `PERMISSION_DENIED`
  /// without the Bluetooth permission.
  static Future<List<({String name, String address})>>
      getPairedAudioDevices() async {
    final List<dynamic> result =
        await _channel.invokeMethod('getPairedAudioDevices');
    return [
      for (final map in result.cast<Map<dynamic, dynamic>>())
        if (map['address'] is String)
          (
            name: map['name'] is String ? map['name'] as String : '',
            address: map['address'] as String,
          ),
    ];
  }

  // ── Headphones ─────────────────────────────────────────────────────────────

  /// Bluetooth headphones the user can add: the connected ones first, then
  /// the paired ones that are not connected right now.
  ///
  /// The paired ones are only included with the Bluetooth permission; this
  /// method never asks for it ([requestBluetoothPermission]). Outside
  /// Android it returns [simulatedHeadphones].
  static Future<List<HeadphoneDevice>> findHeadphones() async {
    if (!isSupported) return simulatedHeadphones;

    final outputs = await getConnectedOutputDevices();
    final paired = await getBluetoothPermissionStatus() ==
            BluetoothPermissionStatus.granted
        ? await getPairedAudioDevices()
        : const <({String name, String address})>[];
    return mergeHeadphones(outputs, paired);
  }

  /// The connected headphones, again on every connect and disconnect.
  /// Outside Android it emits [simulatedHeadphones] once.
  static Stream<List<HeadphoneDevice>> headphoneChanges() {
    if (!isSupported) return Stream.value(simulatedHeadphones);
    return outputDeviceChanges()
        .map((outputs) => mergeHeadphones(outputs, const []));
  }

  /// Builds the headphone list from the connected [outputs] and the [paired]
  /// devices. Public for tests.
  ///
  /// NOTE: Android reports one headset as several outputs (A2DP for media,
  /// SCO for calls, both with the same address). They are merged into one
  /// entry; the test tone uses the media output (A2DP, else LE Audio).
  @visibleForTesting
  static List<HeadphoneDevice> mergeHeadphones(
    List<AudioDeviceInfo> outputs,
    List<({String name, String address})> paired,
  ) {
    final pairedNames = {
      for (final p in paired) p.address.toUpperCase(): p.name,
    };
    // Below Android 9 an output has no address; it is matched by name if
    // the headset is paired under the same name.
    final pairedAddresses = {
      for (final p in paired) p.name: p.address.toUpperCase(),
    };

    // Connected: one entry per headset (by address, else by name), keeping
    // the best output for the test tone.
    final best = <String, (String address, AudioDeviceInfo output)>{};
    for (final output in outputs.where((o) => o.isBluetooth)) {
      var address = output.address.toUpperCase();
      if (address.isEmpty) address = pairedAddresses[output.productName] ?? '';
      final key = address.isEmpty ? 'name:${output.productName}' : address;
      final current = best[key];
      if (current == null || _rank(output) < _rank(current.$2)) {
        best[key] = (address, output);
      }
    }

    final result = [
      for (final (address, output) in best.values)
        HeadphoneDevice(
          // The paired name is the one the user sees in the Android settings.
          name: (pairedNames[address] ?? '').isNotEmpty
              ? pairedNames[address]!
              : output.productName,
          address: address,
          isConnected: true,
          outputDeviceId: output.id,
        ),
    ];

    final connectedAddresses = {for (final h in result) h.address};
    for (final p in paired) {
      final address = p.address.toUpperCase();
      if (connectedAddresses.contains(address)) continue;
      result.add(HeadphoneDevice(
        name: p.name.isEmpty ? address : p.name,
        address: address,
        isConnected: false,
      ));
    }
    return result;
  }

  /// Lower is better for the test tone: A2DP, LE Audio, then the rest (SCO).
  static int _rank(AudioDeviceInfo output) => switch (output.typeCode) {
        _typeBluetoothA2dp => 0,
        _typeBleHeadset => 1,
        _ => 2,
      };

  /// Headphones shown outside Android (browser, desktop), so the screens
  /// work without the native side.
  ///
  /// NOTE: The addresses are not real BD_ADDRs. Devices added in the browser
  /// are stored under them and do not match real headphones on a phone.
  static const List<HeadphoneDevice> simulatedHeadphones = [
    HeadphoneDevice(
        name: 'AirPods Pro', address: 'simulated_1', isConnected: true),
    HeadphoneDevice(
        name: 'Sony WH-1000XM5', address: 'simulated_2', isConnected: true),
    HeadphoneDevice(
        name: 'Bose QC45', address: 'simulated_3', isConnected: true),
    HeadphoneDevice(
        name: 'JBL Live 660NC', address: 'simulated_4', isConnected: true),
    HeadphoneDevice(
        name: 'Sennheiser HD 450BT', address: 'simulated_5', isConnected: true),
  ];

  // ── Test tone ──────────────────────────────────────────────────────────────

  /// Plays a 440 Hz test tone until [stopTestTone], with the left and right
  /// volume as on the calibration wheel (1–100).
  ///
  /// With [outputDeviceId] ([HeadphoneDevice.outputDeviceId]) the tone only
  /// plays on those headphones: if they are not connected it throws a
  /// [PlatformException] with code `DEVICE_NOT_CONNECTED` instead of using
  /// the speaker, and it stops by itself when they disconnect.
  static Future<void> playTestTone({
    required int leftVolume,
    required int rightVolume,
    int? outputDeviceId,
  }) async {
    await _channel.invokeMethod('playTestTone', {
      'leftVolume': leftVolume.clamp(1, 100),
      'rightVolume': rightVolume.clamp(1, 100),
      'deviceId': ?outputDeviceId,
    });
  }

  /// Stops the test tone; does nothing if none is playing.
  static Future<void> stopTestTone() => _channel.invokeMethod('stopTestTone');

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
