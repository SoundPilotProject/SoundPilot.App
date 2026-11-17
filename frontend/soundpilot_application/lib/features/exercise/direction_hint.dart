// lib/features/exercise/direction_hint.dart
//
// What to tell the user when the system settings make a direction inaudible,
// and the hint that applies when those settings cannot be read at all.

import '../../core/services/audio_device_service.dart';

/// Message for a system setting that is known to make left and right
/// inaudible, or null if nothing known does.
String? directionBlockedMessage(AudioAccessibility settings) {
  if (settings.monoAudio == true) {
    return 'In den Bedienungshilfen ist Mono-Audio aktiv. Links und rechts '
        'sind damit nicht zu hören.';
  }
  if (settings.balanceOffCentre) {
    return 'In den Bedienungshilfen ist die Audio-Balance zu einer Seite '
        'verschoben. Links und rechts stimmen damit nicht.';
  }
  return null;
}

/// The hint that is shown after a direction test, whatever the settings say.
///
/// NOTE: It exists because [AudioAccessibility] can come back unknown — the
/// settings have no public constants and a setting nobody has ever touched is
/// not in the system database. Without this hint, a user whose phone is set to
/// mono hears the same thing five times in the direction test and has only one
/// conclusion left: that they cannot tell left from right. This one names the
/// other possible cause, and it works even where nothing can be read.
const String directionCheckHint =
    'Wenn du links und rechts nicht unterscheiden kannst, prüfe in den '
    'Bedienungshilfen Mono-Audio und Audio-Balance.';
