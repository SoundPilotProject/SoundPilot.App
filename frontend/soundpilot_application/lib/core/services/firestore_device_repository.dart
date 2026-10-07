// lib/core/services/firestore_device_repository.dart
//
// Devices of a signed-in user in the Firestore document users/{uid}, field
// `calibration` (see docs/PROJECT_CONTEXT.md §4 and §6).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

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
/// - On the first snapshot from the server, devices this user still has
///   stored locally from before the Firestore sync are uploaded once and
///   removed locally (see [_importLocalDevices]). Guest devices are only
///   uploaded if the user agrees after signing in ([addMissingDevices], see
///   offerGuestDevices).
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
  Stream<DeviceData> watch() => watchSnapshots(_doc.snapshots());

  /// Turns the document [snapshots] into device lists; [watch] passes the
  /// real listener, tests a stream of their own.
  ///
  /// NOTE: A stream transformation on purpose, not an `async*` generator with
  /// `await for`. Cancelling an `async*` stream does not cancel the Firestore
  /// listener while the generator waits for the next snapshot. After logout
  /// that listener then gets `permission-denied`, and the error ended up
  /// uncaught (in the future of `cancel()`, which nobody awaits). Here,
  /// cancelling ends the listener at once.
  @visibleForTesting
  Stream<DeviceData> watchSnapshots(
    Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots,
  ) {
    return snapshots.transform(StreamTransformer.fromHandlers(
      handleData: (snapshot, sink) {
        final data = snapshot.data();

        if (data == null) {
          // NOTE: From the server this means the cloud function has not
          // created the document yet: wait for the next snapshot. From the
          // cache it means offline with nothing cached (e.g. first start after
          // a reinstall), where waiting could take forever: show no devices.
          if (snapshot.metadata.isFromCache) sink.add(const DeviceData());
          return;
        }

        if (!_exists.isCompleted) _exists.complete();

        final devices = DeviceData.fromMap(data['calibration']);

        // Only against server data, so a device deleted on another phone is
        // not brought back from a stale cache.
        if (!_importStarted && !snapshot.metadata.isFromCache) {
          _importStarted = true;
          unawaited(_importLocalDevices(devices));
        }

        sink.add(devices);
      },
    ));
  }

  /// Uploads the devices this user stored locally before the Firestore sync
  /// (`user_calibration_<uid>`) that are not in [cloud] yet, then removes
  /// them locally.
  ///
  /// A device that is already in the account wins over the local one. If the
  /// upload fails, the local data stays and is tried again on the next start.
  Future<void> _importLocalDevices(DeviceData cloud) async {
    try {
      final local = await DeviceStorageService.load(uid);
      final updates = _missingDevices(cloud, local);

      if (updates.isNotEmpty) {
        await _doc.update(updates);
        logger.i('FirestoreDeviceRepository: ${updates.length} local '
            'device(s) uploaded for $uid.');
      }

      await DeviceStorageService.clear(uid);
    } catch (e) {
      logger.e('FirestoreDeviceRepository: Upload of local devices failed',
          error: e);
    }
  }

  /// Adds the devices of [local] that are not in the account yet, in one
  /// update; a device that is already in the account wins.
  ///
  /// Waits until the user document exists (right after registration the cloud
  /// function may not have written it yet), so callers should put a timeout
  /// on it. Does not need [watch].
  Future<void> addMissingDevices(DeviceData local) async {
    final snapshot = await _doc.snapshots().firstWhere((s) => s.exists);
    final cloud = DeviceData.fromMap(snapshot.data()?['calibration']);
    final updates = _missingDevices(cloud, local);
    if (updates.isEmpty) return;
    await _doc.update(updates);
    logger.i('FirestoreDeviceRepository: ${updates.length} device(s) added '
        'for $uid.');
  }

  /// Field-path updates for the devices of [local] that are not in [cloud].
  static Map<Object, Object?> _missingDevices(
    DeviceData cloud,
    DeviceData local,
  ) {
    final updates = <Object, Object?>{};
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
    return updates;
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
