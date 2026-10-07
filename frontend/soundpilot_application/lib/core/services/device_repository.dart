// lib/core/services/device_repository.dart
//
// Where the DeviceScreen reads and writes the devices: one interface, kept
// locally for guests (LocalDeviceRepository) and in Firestore for signed-in
// users (FirestoreDeviceRepository).

import 'dart:async';

import '../../models/user_model.dart';
import 'device_storage_service.dart';

/// Devices of the current user or guest.
///
/// [watch] delivers the complete device list, first the stored one and then
/// again after every change, including the caller's own writes. Writes change
/// one device each.
abstract class DeviceRepository {
  /// The current devices, and the new state after every change.
  Stream<DeviceData> watch();

  /// Adds the headphone [key] or replaces it with [calib].
  Future<void> putHeadphone(String key, HeadphoneCalib calib);

  /// Adds the belt [key] or replaces it with [calib].
  Future<void> putBelt(String key, BeltCalib calib);

  Future<void> removeHeadphone(String key);

  Future<void> removeBelt(String key);

  /// Releases resources; the repository is not used afterwards.
  void dispose() {}
}

/// [DeviceRepository] for guests, stored in SharedPreferences through
/// [DeviceStorageService].
class LocalDeviceRepository implements DeviceRepository {
  LocalDeviceRepository({this.owner = DeviceStorageService.guestOwner});

  /// Whose devices these are (the storage key suffix).
  final String owner;

  /// The stored devices, read once on first use.
  late final Future<DeviceData> _loaded = DeviceStorageService.load(owner);

  /// The current devices; `null` until [_loaded] has completed.
  DeviceData? _data;

  /// Every new state after a write.
  final StreamController<DeviceData> _changes =
      StreamController<DeviceData>.broadcast();

  /// The current devices, loaded on the first call.
  Future<DeviceData> _current() async {
    final loaded = await _loaded;
    // NOTE: `??=` after the await, so a write that finished in the meantime
    // is not overwritten with the stored state.
    return _data ??= loaded;
  }

  @override
  Stream<DeviceData> watch() {
    late final StreamSubscription<DeviceData> changes;
    final controller = StreamController<DeviceData>(
      onCancel: () => changes.cancel(),
    );
    changes = _changes.stream.listen(controller.add);
    // NOTE: Every event is the complete state, so the initial one may come
    // after a change without losing anything; it reads [_data] at that point.
    _current().then(
      (_) => controller.add(_data!),
      onError: controller.addError,
    );
    return controller.stream;
  }

  /// Applies [change] to the current devices, publishes and saves the result.
  Future<void> _write(DeviceData Function(DeviceData data) change) async {
    final data = change(await _current());
    _data = data;
    _changes.add(data);
    await DeviceStorageService.save(owner, data);
  }

  @override
  Future<void> putHeadphone(String key, HeadphoneCalib calib) =>
      _write((data) => data.withHeadphone(key, calib));

  @override
  Future<void> putBelt(String key, BeltCalib calib) =>
      _write((data) => data.withBelt(key, calib));

  @override
  Future<void> removeHeadphone(String key) =>
      _write((data) => data.withoutHeadphone(key));

  @override
  Future<void> removeBelt(String key) =>
      _write((data) => data.withoutBelt(key));

  @override
  void dispose() => _changes.close();
}
