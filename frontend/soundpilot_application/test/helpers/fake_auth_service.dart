// test/helpers/fake_auth_service.dart
//
// AuthService double for widget tests: records the logout instead of
// talking to Firebase.

import 'package:soundpilot_application/features/auth/auth_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({this.unsavedChanges = false});

  /// What [hasUnsavedChanges] reports.
  final bool unsavedChanges;

  /// How often [logout] was called.
  int logouts = 0;

  @override
  Future<bool> hasUnsavedChanges({
    Duration wait = const Duration(seconds: 5),
  }) async =>
      unsavedChanges;

  @override
  Future<void> logout() async => logouts++;
}
