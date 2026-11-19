// test/features/exercise/direction_hint_test.dart
//
// What the app says about the system settings that make a direction
// inaudible — and that it says nothing when it does not know.

import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/core/services/audio_device_service.dart';
import 'package:soundpilot_application/features/exercise/direction_hint.dart';

void main() {
  group('directionBlockedMessage', () {
    test('names mono audio', () {
      final message = directionBlockedMessage(
        const AudioAccessibility(monoAudio: true),
      );

      expect(message, contains('Mono-Audio'));
    });

    test('names a shifted balance', () {
      final message = directionBlockedMessage(
        const AudioAccessibility(monoAudio: false, balance: -0.8),
      );

      expect(message, contains('Audio-Balance'));
    });

    test('mono audio comes first, because it is the whole channel', () {
      final message = directionBlockedMessage(
        const AudioAccessibility(monoAudio: true, balance: -0.8),
      );

      expect(message, contains('Mono-Audio'));
    });

    test('says nothing when both are fine', () {
      expect(
        directionBlockedMessage(
          const AudioAccessibility(monoAudio: false, balance: 0),
        ),
        isNull,
      );
    });

    test('says nothing when nothing could be read', () {
      // Unknown is not "in the way", and it is not "fine" either: the hint
      // on the test exercise is what covers this case.
      expect(directionBlockedMessage(AudioAccessibility.unknown), isNull);
    });
  });

  group('directionCheckHint', () {
    test('names both settings, so it works without reading them', () {
      expect(directionCheckHint, contains('Mono-Audio'));
      expect(directionCheckHint, contains('Audio-Balance'));
      expect(directionCheckHint, contains('Bedienungshilfen'));
    });
  });
}
