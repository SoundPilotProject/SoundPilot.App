import 'package:flutter/services.dart';

/// Represents a single audio output device reported by Android.
class AudioDeviceInfo {
  final int id;
  final String productName;
  final String type;

  const AudioDeviceInfo({
    required this.id,
    required this.productName,
    required this.type,
  });

  factory AudioDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return AudioDeviceInfo(
      id: map['id'] as int,
      productName: map['productName'] as String,
      type: map['type'] as String,
    );
  }

  @override
  String toString() => '$productName ($type)';
}

/// Calls into native Android (AudioManager) to list all current audio
/// output devices (Bluetooth A2DP, wired headset, USB audio, etc.).
///
/// Requires API level 23+ (Android 6.0) — covers 99 %+ of active devices.
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
}
