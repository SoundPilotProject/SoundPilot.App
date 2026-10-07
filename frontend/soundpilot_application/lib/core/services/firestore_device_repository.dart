// lib/core/services/firestore_device_repository.dart
//
// Devices of a signed-in user in the Firestore document users/{uid}, field
// `calibration` (see docs/PROJECT_CONTEXT.md §4 and §6).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_logger.dart';
import '../../models/user_model.dart';
import 'device_repository.dart';
import 'device_storage_service.dart';

/// [DeviceRepository] of a signed-in user, stored in `users/{uid}`.
///
/// - Reads with a snapshot listener, never with a one-time `get()`: right
///   after registration the cloud function `createUserDoc` may not have
///   written the document yet.
/// - Writes one device per field path
///   (`calibration.headphones.<BD_ADDR>`), never the whole map, so two
///   devices cannot overwrite each other. The security rules allow exactly
///   these updates; the client cannot create the document.
/// - Writes wait until the document exists, because `update()` fails on a
///   missing document. That wait only ends while [watch] is listened to.
/// - Offline, Firestore applies writes to its local cache at once (so [watch]
///   shows them) and sends them later; the returned futures only complete
///   then. Callers should therefore not wait for them in the UI.
/// - On the first snapshot from the server, devices that are still stored
///   locally (guest, or this user before the Firestore sync) are uploaded once
///   and removed locally (see [_importLocalDevices]).
class FirestoreDeviceRepository implements DeviceRepository {
  FirestoreDeviceRepository({required this.uid, FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Firebase Auth UID (= document id).
  final String uid;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(uid);

  /// Completes once the user document has been seen.
  final Completer<void> _exists = Completer<void>();

  /// Whether the local devices were already handed to [_importLocalDevices].
  bool _importStarted = false;

  /// Field path of one device: `calibration.<group>.<key>`. A [FieldPath]
  /// instead of a dotted string, so a key can never split the path.
  static FieldPath _path(String group, String key) =>
      FieldPath(['calibration', group, key]);

  @override
  Stream<DeviceData> watch() async* {
    await for (final snapshot in _doc.snapshots()) {
      final data = snapshot.data();

      if (data == null) {
        // NOTE: From the server this means the cloud function has not created
        // the document yet: wait for the next snapshot. From the cache it
        // means offline with nothing cached (e.g. first start after a
        // reinstall), where waiting could take forever: show no devices.
        if (snapshot.metadata.isFromCache) yield const DeviceData();
        continue;
      }

      if (!_exists.isCompleted) _exists.complete();

      final devices = DeviceData.fromMap(data['calibration']);

      // Only against server data, so a device deleted on another phone is not
      // brought back from a stale cache.
      if (!_importStarted && !snapshot.metadata.isFromCache) {
        _importStarted = true;
        unawaited(_importLocalDevices(devices));
      }

      yield devices;
    }
  }

  /// Uploads the devices stored locally (guest and this user) that are not in
  /// [cloud] yet, then removes them locally.
  ///
  /// A device that is already in the account wins over the local one. If the
  /// upload fails, the local data stays and is tried again on the next start.
  Future<void> _importLocalDevices(DeviceData cloud) async {
    final owners = [DeviceStorageService.guestOwner, uid];
    try {
      final updates = <Object, Object?>{};
      for (final owner in owners) {
        final local = await DeviceStorageService.load(owner);
        local.headphones.forEach((key, calib) {
          if (!cloud.headphones.containsKey(key)) {
            updates[_path('headphones', key)] = calib.toMap();
          }
        });
        local.belts.forEach((key, calib) {
          if (!cloud.belts.containsKey(key)) {
            updates[_path('belts', key)] = calib.toMap();
          }
        });
      }

      if (updates.isNotEmpty) {
        await _doc.update(updates);
        logger.i('FirestoreDeviceRepository: ${updates.length} local '
            'device(s) uploaded for $uid.');
      }

      for (final owner in owners) {
        await DeviceStorageService.clear(owner);
      }
    } catch (e) {
      logger.e('FirestoreDeviceRepository: Upload of local devices failed',
          error: e);
    }
  }

  /// Sets the field [path] once the document exists.
  Future<void> _update(FieldPath path, Object value) async {
    await _exists.future;
    await _doc.update({path: value});
  }

  @override
  Future<void> putHeadphone(String key, HeadphoneCalib calib) =>
      _update(_path('headphones', key), calib.toMap());

  @override
  Future<void> putBelt(String key, BeltCalib calib) =>
      _update(_path('belts', key), calib.toMap());

  @override
  Future<void> removeHeadphone(String key) =>
      _update(_path('headphones', key), FieldValue.delete());

  @override
  Future<void> removeBelt(String key) =>
      _update(_path('belts', key), FieldValue.delete());

  @override
  void dispose() {}
}
