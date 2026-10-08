# Screen Reader Support — Plan

Date: 2026-10-08
Status: **plan only, nothing in this document has been built yet.**
Reference: the accessibility guidelines in `docs/PROJECT_CONTEXT.md` §1, the
findings in `docs/ACCESSIBILITY_AUDIT.md`.

Goal: when a user has a screen reader switched on on their phone, SoundPilot
works with it fully — every screen, every action, every status change.

## 1. How it works in Flutter

There is no switch to build into the app. A Flutter app does not ship its own
screen reader; it hands a **semantics tree** (labels, roles, states, actions)
to the platform. As soon as the operating system reports that an assistive
service is running, Flutter builds that tree and the service reads it:

- Android: TalkBack, and any other screen reader that uses the Android
  accessibility API (e.g. third-party readers some users install, Select to
  Speak, Switch Access, Voice Access).
- iOS: VoiceOver, Switch Control, Voice Control.

So "if the user has it on, it is on in our app" is already true today. The work
is making sure what the tree says is **complete and correct**, and that it is
proven on real phones.

Exception: the **browser**. Flutter web only builds the tree after the user
activates the hidden "Enable accessibility" button, or when the app calls
`SemanticsBinding.instance.ensureSemantics()`. Only relevant if the browser
becomes a target (open point in `PROJECT_CONTEXT.md` §7).

## 2. Current state (from the code)

Already in place:

- `Semantics` headers on screen titles, labels and tooltips on all icon-only
  controls, decorative images excluded (`SoundPilotLogo`, `GoogleLogo`).
- Selected state on the type selector, side buttons and belt vibration choice;
  connection state as icon + text, not colour only.
- Live regions on loading texts, the password reset result, the add-device
  scan status and `TestPage`.
- The calibration wheel exposes its value and increase/decrease actions
  (`calibration.dart`, `_VolumeSection`), so the standard swipe up/down works.
- App locale fixed to German (`core/app_locale.dart`).

Not done:

- **Nothing has been tried with TalkBack or VoiceOver on a real phone.**
- No automated semantics checks in CI (the layout test checks sizes, not
  labels).
- `docs/ACCESSIBILITY_AUDIT.md` still says "nothing has been fixed yet"; its
  findings list is out of date for screen readers.

## 3. Work items

In suggested order. Each one is small enough for its own PR.

### 3.1 Automated checks in CI

Add Flutter's built-in guidelines to `test/accessibility_layout_test.dart`,
per screen and per theme:

```dart
final handle = tester.ensureSemantics();
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
await expectLater(tester, meetsGuideline(textContrastGuideline));
handle.dispose();
```

Plus targeted `matchesSemantics` checks for states that matter (selected type,
connected/disconnected card, calibration value). Cheap, and it stops later
changes from silently removing labels. It does **not** replace device tests:
it cannot judge reading order or whether a label makes sense.

### 3.2 Device test protocol

A written checklist, run on one Android phone (TalkBack) and one iPhone
(VoiceOver), before each larger release. Per screen:

- Swiping through reads every element **once**, in a sensible order, in German.
- Every button says what it does; every state (selected, connected, error) is
  spoken.
- Every action works with double-tap; the calibration wheel works with
  swipe up/down.
- After opening a screen or dialog, focus starts at its title; after closing a
  dialog, focus returns to where it was.
- Status changes (scan finished, device added, save failed) are spoken without
  the user having to search for them.
- Nothing has to be done within a time limit.

Results go into a short table (screen × platform × pass/fail + notes), e.g. a
new section in `ACCESSIBILITY_AUDIT.md`. For the diploma thesis, a session with
one or two people who use a screen reader every day would be far stronger
evidence than our own tests.

### 3.3 SnackBars disappear too fast

Every `SnackBar` in the app has no `action` and the default duration (4 s),
e.g. the failed-write message in `device_screen.dart` and the guest
take-over result in `guest_devices_offer.dart`. A screen reader may still be
reading something else when it vanishes, and it breaks "no time-limited
interactions". Flutter keeps a SnackBar open while a screen reader is on only
if it has an action. Options:

- give the important ones an action ("OK") — Flutter then keeps them until
  dismissed when `MediaQuery.accessibleNavigationOf(context)` is true, or
- show errors as text on the screen (like `PasswordResetScreen` already does).

### 3.4 Announcing status changes

Rule: a change the user did not cause directly, or that happens later (scan
result, connection lost, write failed), must be spoken.

- Prefer a visible text in a `Semantics(liveRegion: true)`, which is already
  the pattern in the app.
- Use a one-off announcement (`SemanticsService.announce` or its successor)
  only where there is no visible text. Check the API of the pinned Flutter
  3.47.6 first: Android 16 deprecated the platform's announcement call in
  favour of live regions, and Flutter's API has been changing with it.

Known gap: in the add-device dialog (`add_device_dialog.dart`,
`_buildScanResults`) only "scan running" is a live region. The end of the scan
("Keine … gefunden" or the list of results) is not spoken, so a screen reader
user does not learn that the scan has finished.

### 3.5 When the real Bluetooth and belt features arrive

The simulated scan will be replaced (`PROJECT_CONTEXT.md` §7). New features
need screen reader support from the start, not afterwards:

- Scan states ("Suche läuft", "3 Geräte gefunden", "Keine Geräte gefunden") as
  live text.
- Connect/disconnect of a device spoken, also when it happens in the
  background.
- Belt warning distance: the warning itself must not rely on the screen —
  vibration and sound first (guideline "multiple channels"); a spoken message
  is an addition, because a screen reader may be busy or off.

### 3.6 Same UI for everyone

`MediaQuery.accessibleNavigationOf(context)` tells the app that an assistive
service is running. Use it only where behaviour must differ (e.g. keeping a
message open), not to build a separate "screen reader mode". Controls that are
hard for screen reader users are usually hard for motor-impaired users too;
fix them for everyone.

## 4. Open decisions

- Which phones are available for testing (at least one Android, one iPhone)?
- Who runs the device protocol, and how often?
- Can we find screen reader users for a test session?
- Is the browser a target (then `ensureSemantics()` and web testing are needed)?
