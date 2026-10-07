// test/features/auth/pending_writes_test.dart
//
// Tests AuthService.writesStillPending, which decides whether the logout has
// to warn about changes that would be lost with the Firestore cache.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundpilot_application/features/auth/auth_service.dart';

const _wait = Duration(milliseconds: 50);

void main() {
  test('nothing pending: the writes complete in time', () async {
    expect(await AuthService.writesStillPending(Future.value(), _wait), isFalse);
  });

  test('offline: the writes do not complete in time', () async {
    final never = Completer<void>().future;

    expect(await AuthService.writesStillPending(never, _wait), isTrue);
  });

  test('an error counts as pending, so the user is asked', () async {
    final failed = Future<void>.error(Exception('user changed'));

    expect(await AuthService.writesStillPending(failed, _wait), isTrue);
  });
}
