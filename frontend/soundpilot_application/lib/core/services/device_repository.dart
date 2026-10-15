// lib/core/services/device_repository.dart
//
// Where the DeviceScreen reads and writes the devices: one interface, kept
// in memory for guests (GuestDeviceRepository) and in Firestore for signed-in
// users (FirestoreDeviceRepository).

import 'dart:async';

import '../../models/user_model.dart';

/// Devices of the current user or guest.
///
/// [watch] delivers the complete device list, first the current one and then
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

/// [DeviceRepository] for guests: the devices live in memory for this app run
/// and are **never written to the phone**. Closing the app forgets them.
///
/// Without an account there is nowhere the devices belong, so storing them
/// would leave a stranger's data on the phone for whoever opens the app next.
/// A guest who wants to keep them signs in; [devices] is then offered for the
/// account (offerGuestDevices).
///
/// NOTE: The state is static and shared by every instance, because the
/// sign-in flow reads it after [DeviceScreen] has already been replaced, and
/// because AppEntryPoint builds a new instance whenever it rebuilds.
class GuestDeviceRepository implements DeviceRepository {
  /// The guest's devices in this app run.
  static DeviceData _data = const DeviceData();

  /// Every new state after a write; never closed, see the class note.
  static final StreamController<DeviceData> _changes =
      StreamController<DeviceData>.broadcast();

  /// What the guest has added so far, for the take-over into an account.
  static DeviceData get devices => _data;

  /// Forgets the guest's devices (end of guest mode, or after they went into
  /// an account) and tells everyone watching.
  static void clear() => _set(const DeviceData());

  static void _set(DeviceData data) {
    _data = data;
    _changes.add(data);
  }

  @override
  Stream<DeviceData> watch() {
    late final StreamSubscription<DeviceData> changes;
    final controller = StreamController<DeviceData>(
      onCancel: () => changes.cancel(),
    );
    // Subscribed before the current state is delivered, so a write in
    // between is not lost; the controller buffers until someone listens.
    changes = _changes.stream.listen(controller.add);
    controller.add(_data);
    return controller.stream;
  }

  @override
  Future<void> putHeadphone(String key, HeadphoneCalib calib) async =>
      _set(_data.withHeadphone(key, calib));

  @override
  Future<void> putBelt(String key, BeltCalib calib) async =>
      _set(_data.withBelt(key, calib));

  @override
  Future<void> removeHeadphone(String key) async =>
      _set(_data.withoutHeadphone(key));

  @override
  Future<void> removeBelt(String key) async => _set(_data.withoutBelt(key));

  // The state outlives the instance, so there is nothing to release here.
  @override
  void dispose() {}
}
