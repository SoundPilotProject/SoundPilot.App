// lib/features/device/headphone_connection.dart
//
// Watches whether one earbud is connected, for the screens that play sound on
// it (calibration, test exercise).

import 'dart:async';

import '../../core/app_logger.dart';
import '../../core/services/audio_device_service.dart';

/// Follows the connection of the earbud with the map key [address] (its
/// BD_ADDR, case-insensitive) and calls [onChanged] on every change.
class HeadphoneConnection {
  final String address;
  final void Function() onChanged;

  StreamSubscription<List<HeadphoneDevice>>? _subscription;

  /// False until the first headphone list (or an error) arrived.
  bool known = false;

  /// The earbud while it is connected, otherwise null. Its
  /// [HeadphoneDevice.outputDeviceId] is where the sound is routed.
  HeadphoneDevice? connected;

  HeadphoneConnection({
    required this.address,
    required Stream<List<HeadphoneDevice>> Function() changes,
    required this.onChanged,
  }) {
    _subscription = changes().listen(
      _update,
      onError: (Object e) {
        // E.g. no native side: the earbud then counts as not connected.
        logger.w('HeadphoneConnection: Connection state unavailable',
            error: e);
        known = true;
        connected = null;
        onChanged();
      },
    );
  }

  void _update(List<HeadphoneDevice> headphones) {
    final key = address.toUpperCase();
    HeadphoneDevice? match;
    for (final h in headphones) {
      if (h.isConnected && h.address.toUpperCase() == key) match = h;
    }
    known = true;
    connected = match;
    onChanged();
  }

  void dispose() => _subscription?.cancel();
}
