// test/core/services/audio_device_service_test.dart
//
// AudioDeviceService against a mocked native channel.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundpilot_application/core/services/audio_device_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.soundpilot/audio_devices');
  final calls = <String>[];

  /// Answers every channel call with [answers][method].
  void mockNative(Map<String, Object?> answers) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return answers[call.method];
    });
  }

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AudioDeviceInfo.fromMap', () {
    test('reads the Bluetooth address and flag', () {
      final device = AudioDeviceInfo.fromMap({
        'id': 7,
        'productName': 'Sony WH-1000XM5',
        'type': 'Bluetooth (A2DP)',
        'typeCode': 8,
        'isBluetooth': true,
        'address': 'AA:BB:CC:DD:EE:FF',
      });

      expect(device.id, 7);
      expect(device.isBluetooth, isTrue);
      expect(device.address, 'AA:BB:CC:DD:EE:FF');
    });

    test('falls back if address and flag are missing (old native side)', () {
      final device = AudioDeviceInfo.fromMap({
        'id': 1,
        'productName': 'Lautsprecher',
        'type': 'Lautsprecher',
      });

      expect(device.isBluetooth, isFalse);
      expect(device.address, '');
    });
  });

  group('Bluetooth permission', () {
    for (final (native, expected) in [
      ('granted', BluetoothPermissionStatus.granted),
      ('denied', BluetoothPermissionStatus.denied),
      ('permanentlyDenied', BluetoothPermissionStatus.permanentlyDenied),
      (null, BluetoothPermissionStatus.denied),
    ]) {
      test('native "$native" is $expected', () async {
        mockNative({
          'getBluetoothPermissionStatus': native,
          'requestBluetoothPermission': native,
        });

        expect(await AudioDeviceService.getBluetoothPermissionStatus(),
            expected);
        expect(await AudioDeviceService.requestBluetoothPermission(), expected);
      });
    }
  });

  group('Bluetooth state', () {
    for (final (native, expected) in [
      ('on', BluetoothState.on),
      ('off', BluetoothState.off),
      ('unavailable', BluetoothState.unavailable),
      (null, BluetoothState.unavailable),
    ]) {
      test('native "$native" is $expected', () async {
        mockNative({'getBluetoothState': native});
        expect(await AudioDeviceService.getBluetoothState(), expected);
      });
    }
  });

  test('opening the settings calls the native side', () async {
    mockNative({'openBluetoothSettings': true, 'openAppSettings': null});

    expect(await AudioDeviceService.openBluetoothSettings(), isTrue);
    expect(await AudioDeviceService.openAppSettings(), isFalse);
    expect(calls, ['openBluetoothSettings', 'openAppSettings']);
  });
}
