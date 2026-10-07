// test/helpers/fake_device_repository.dart
//
// In-memory DeviceRepository for widget tests of the DeviceScreen.

import 'dart:async';

import 'package:soundpilot_application/core/services/device_repository.dart';
import 'package:soundpilot_application/models/user_model.dart';

/// Repository whose devices the test pushes in, and that records the writes.
class FakeDeviceRepository implements DeviceRepository {
  final StreamController<DeviceData> devices = StreamController<DeviceData>();

  /// Every write as text, e.g. `removeBelt bb`.
  final List<String> writes = [];

  /// If set, every write fails with it.
  Object? writeError;

  bool disposed = false;

  Future<void> _record(String write) async {
    writes.add(write);
    if (writeError != null) throw writeError!;
  }

  @override
  Stream<DeviceData> watch() => devices.stream;

  @override
  Future<void> putHeadphone(String key, HeadphoneCalib calib) =>
      _record('putHeadphone $key ${calib.modelId}');

  @override
  Future<void> putBelt(String key, BeltCalib calib) =>
      _record('putBelt $key ${calib.modelId}');

  @override
  Future<void> removeHeadphone(String key) => _record('removeHeadphone $key');

  @override
  Future<void> removeBelt(String key) => _record('removeBelt $key');

  @override
  void dispose() => disposed = true;
}
