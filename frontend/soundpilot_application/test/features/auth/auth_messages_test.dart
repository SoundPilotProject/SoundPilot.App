// test/features/auth/auth_messages_test.dart
//
// Tests for the German error messages of AuthService and for AuthResult.

import 'package:flutter_test/flutter_test.dart';
import 'package:soundpilot_application/features/auth/auth_service.dart';
import 'package:soundpilot_application/models/user_model.dart';

void main() {
  group('AuthService.messageForCode', () {
    test('wrong password and unknown user give the same message', () {
      const expected = 'E-Mail oder Passwort ist falsch.';

      expect(AuthService.messageForCode('invalid-credential'), expected);
      expect(AuthService.messageForCode('wrong-password'), expected);
      expect(AuthService.messageForCode('user-not-found'), expected);
    });

    test('known codes give a specific message', () {
      expect(AuthService.messageForCode('email-already-in-use'),
          contains('schon ein Konto'));
      expect(AuthService.messageForCode('weak-password'),
          contains('mindestens 6 Zeichen'));
      expect(AuthService.messageForCode('network-request-failed'),
          contains('Keine Internetverbindung'));
      expect(AuthService.messageForCode('invalid-email'),
          contains('ungültig'));
    });

    test('unknown codes and null give the general message', () {
      const general = 'Etwas ist schiefgelaufen. Bitte versuche es noch einmal.';

      expect(AuthService.messageForCode('some-new-code'), general);
      expect(AuthService.messageForCode(null), general);
    });
  });

  group('AuthService.messageForGoogleCode', () {
    test('a blocked setup names e-mail login as the way out', () {
      // Android's DEVELOPER_ERROR (unregistered SHA-1) arrives as
      // 'sign_in_failed'. It must not end up in the general message, because
      // the user cannot do anything about it except use e-mail.
      final message = AuthService.messageForGoogleCode('sign_in_failed');

      expect(message, contains('nicht freigegeben'));
      expect(message, contains('E-Mail und Passwort'));
      expect(message, isNot(AuthService.messageForCode(null)));
    });

    test('a platform without the plugin says so', () {
      final message = AuthService.messageForGoogleCode('missing-plugin');

      expect(message, contains('auf diesem Gerät nicht'));
      expect(message, isNot(AuthService.messageForCode(null)));
    });

    test('a network error reuses the Firebase message', () {
      expect(
        AuthService.messageForGoogleCode('network_error'),
        AuthService.messageForCode('network-request-failed'),
      );
    });

    test('unknown codes and null give the general message', () {
      final general = AuthService.messageForCode(null);

      expect(AuthService.messageForGoogleCode('some_new_code'), general);
      expect(AuthService.messageForGoogleCode(null), general);
    });
  });

  group('AuthResult', () {
    test('success has a user and no message', () {
      final result = AuthResult.success(
        UserModel(id: 'uid-1', displayName: 'Anna', email: 'a@example.com'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('failure has a message and no user', () {
      const result = AuthResult.failure('Fehler');

      expect(result.isSuccess, isFalse);
      expect(result.user, isNull);
      expect(result.errorMessage, 'Fehler');
    });

    test('cancelled has neither', () {
      const result = AuthResult.cancelled();

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, isNull);
    });
  });
}
