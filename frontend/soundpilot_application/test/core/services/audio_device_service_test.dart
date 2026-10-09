// test/core/services/audio_device_service_test.dart
//
// AudioDeviceService against a mocked native channel.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundpilot_application/core/services/audio_device_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.soundpilot/audio_devices');
  const events = EventChannel('com.soundpilot/audio_device_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  /// Answers every channel call with [answers][method].
  void mockNative(Map<String, Object?> answers) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answers[call.method];
    });
  }

  /// A native output device as the channel sends it.
  Map<String, Object> output(int id, String name, String address,
          {int typeCode = 8, bool isBluetooth = true}) =>
      {
        'id': id,
        'productName': name,
        'type': 'Bluetooth',
        'typeCode': typeCode,
        'isBluetooth': isBluetooth,
        'address': address,
      };

  AudioDeviceInfo info(int id, String name, String address,
          {int typeCode = 8, bool isBluetooth = true}) =>
      AudioDeviceInfo.fromMap(output(id, name, address,
          typeCode: typeCode, isBluetooth: isBluetooth));

  tearDown(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockStreamHandler(events, null);
    debugDefaultTargetPlatformOverride = null;
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
    expect(calls.map((c) => c.method),
        ['openBluetoothSettings', 'openAppSettings']);
  });

  group('mergeHeadphones', () {
    test('keeps only Bluetooth outputs', () {
      final result = AudioDeviceService.mergeHeadphones([
        info(1, 'Lautsprecher', '', typeCode: 2, isBluetooth: false),
        info(2, 'Sony', 'aa:bb:cc:dd:ee:ff'),
      ], const []);

      expect(result, [
        const HeadphoneDevice(
          name: 'Sony',
          address: 'AA:BB:CC:DD:EE:FF',
          isConnected: true,
          outputDeviceId: 2,
        ),
      ]);
    });

    test('merges A2DP and SCO of one headset and routes to A2DP', () {
      final result = AudioDeviceService.mergeHeadphones([
        info(3, 'Sony', 'AA:BB:CC:DD:EE:FF', typeCode: 7), // SCO
        info(4, 'Sony', 'AA:BB:CC:DD:EE:FF', typeCode: 8), // A2DP
      ], const []);

      expect(result, hasLength(1));
      expect(result.single.outputDeviceId, 4);
    });

    test('adds paired headphones that are not connected, after the '
        'connected ones', () {
      final result = AudioDeviceService.mergeHeadphones([
        info(4, 'WH-1000XM5', 'AA:BB:CC:DD:EE:FF'),
      ], [
        (name: 'Bose QC45', address: '11:22:33:44:55:66'),
        (name: 'Meine Sony', address: 'aa:bb:cc:dd:ee:ff'),
      ]);

      expect(result, [
        // The connected one carries the name from the Android settings.
        const HeadphoneDevice(
          name: 'Meine Sony',
          address: 'AA:BB:CC:DD:EE:FF',
          isConnected: true,
          outputDeviceId: 4,
        ),
        const HeadphoneDevice(
          name: 'Bose QC45',
          address: '11:22:33:44:55:66',
          isConnected: false,
        ),
      ]);
    });

    test('finds the address of an output without one by its paired name '
        '(Android 7-8)', () {
      final result = AudioDeviceService.mergeHeadphones([
        info(5, 'Bose QC45', ''),
        info(6, 'Unbekannt', ''),
      ], [
        (name: 'Bose QC45', address: '11:22:33:44:55:66'),
      ]);

      expect(result.map((h) => (h.name, h.address, h.isConnected)), [
        ('Bose QC45', '11:22:33:44:55:66', true),
        ('Unbekannt', '', true),
      ]);
    });
  });

  group('findHeadphones', () {
    test('includes paired headphones with the permission', () async {
      mockNative({
        'getBluetoothState': 'on',
        'getConnectedOutputDevices': [output(4, 'Sony', 'AA:BB:CC:DD:EE:FF')],
        'getBluetoothPermissionStatus': 'granted',
        'getPairedAudioDevices': [
          {'name': 'Bose QC45', 'address': '11:22:33:44:55:66'},
        ],
      });

      final result = await AudioDeviceService.findHeadphones();

      expect(result.map((h) => h.name), ['Sony', 'Bose QC45']);
    });

    test('only connected ones without the permission, and does not ask',
        () async {
      mockNative({
        'getBluetoothState': 'on',
        'getConnectedOutputDevices': [output(4, 'Sony', 'AA:BB:CC:DD:EE:FF')],
        'getBluetoothPermissionStatus': 'denied',
      });

      final result = await AudioDeviceService.findHeadphones();

      expect(result.map((h) => h.name), ['Sony']);
      expect(calls.map((c) => c.method),
          isNot(contains('requestBluetoothPermission')));
      expect(calls.map((c) => c.method),
          isNot(contains('getPairedAudioDevices')));
    });

    test('is simulated outside Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(AudioDeviceService.isSupported, isFalse);
      expect(await AudioDeviceService.findHeadphones(),
          AudioDeviceService.simulatedHeadphones);
      expect(calls, isEmpty);
    });

    test('is simulated on Android without Bluetooth (e.g. emulator)',
        () async {
      mockNative({'getBluetoothState': 'unavailable'});

      expect(await AudioDeviceService.usesSimulatedHeadphones(), isTrue);
      expect(await AudioDeviceService.findHeadphones(),
          AudioDeviceService.simulatedHeadphones);
      expect(calls.map((c) => c.method),
          isNot(contains('getConnectedOutputDevices')));
    });

    test('is not simulated if Bluetooth is only switched off', () async {
      mockNative({
        'getBluetoothState': 'off',
        'getConnectedOutputDevices': <Object>[],
        'getBluetoothPermissionStatus': 'granted',
        'getPairedAudioDevices': <Object>[],
      });

      expect(await AudioDeviceService.usesSimulatedHeadphones(), isFalse);
      expect(await AudioDeviceService.findHeadphones(), isEmpty);
    });
  });

  test('headphoneChanges reports every change of the connected headphones',
      () async {
    mockNative({'getBluetoothState': 'on'});
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (arguments, sink) {
        sink.success([output(4, 'Sony', 'AA:BB:CC:DD:EE:FF')]);
        sink.success(<Object>[]);
        sink.endOfStream();
      }),
    );

    final updates = await AudioDeviceService.headphoneChanges().toList();

    expect(updates.map((list) => list.map((h) => h.name).toList()), [
      ['Sony'],
      <String>[],
    ]);
  });

  test('headphoneChanges is simulated without Bluetooth', () async {
    mockNative({'getBluetoothState': 'unavailable'});

    expect(await AudioDeviceService.headphoneChanges().toList(),
        [AudioDeviceService.simulatedHeadphones]);
  });

  group('test tone', () {
    test('sends the volumes (clamped to 1-100) and the output device',
        () async {
      mockNative({});

      await AudioDeviceService.playTestTone(
          leftVolume: 0, rightVolume: 140, outputDeviceId: 4);
      await AudioDeviceService.stopTestTone();

      expect(calls.first.method, 'playTestTone');
      expect(calls.first.arguments,
          {'leftVolume': 1, 'rightVolume': 100, 'deviceId': 4});
      expect(calls.last.method, 'stopTestTone');
    });

    test('leaves the device out if none is given', () async {
      mockNative({});

      await AudioDeviceService.playTestTone(leftVolume: 50, rightVolume: 60);

      expect(calls.single.arguments, {'leftVolume': 50, 'rightVolume': 60});
    });
  });
}
