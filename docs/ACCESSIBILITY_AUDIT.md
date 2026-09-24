# Accessibility Audit — SoundPilot

Date: 2026-09-24
Method: static code review of every screen and shared widget in
`frontend/soundpilot_application/lib/`. **Not tested on a device** with
TalkBack/VoiceOver, large fonts or a color-blindness simulator. Contrast ratios
are hand-calculated and approximate.
Reference: the accessibility guidelines in `docs/PROJECT_CONTEXT.md` §1.

Status: **findings only, nothing has been fixed yet.**

## Summary

| Requirement | Result |
|---|---|
| Screen readers | Fail |
| Touch targets | Partly |
| Contrast (WCAG AA) | Partly |
| Text scaling | Fail |
| Not color alone | Fail |
| Multiple channels | Fail |
| Simple flows | Partly |
| Reduced motion | No issue (animations are minimal) |

## 1. Screen readers — Fail

- No `Semantics`, `semanticLabel` or `tooltip` anywhere in `lib/`.
- Unlabeled icon buttons: back arrows (all top bars), password show/hide toggle
  (`login_screen.dart`, `register_screen.dart`), delete "X" on `_DeviceCard`
  (`device_screen.dart`).
- The red/green connection dot in `_DeviceCard` is not exposed to screen readers.
- Selected state is not announced for `_TypeSelector` (`Earbuds`/`Gürtel`) and
  `_SideButton` (`L`/`M`/`R`). `L`/`M`/`R` should be read as
  "Links/Mitte/Rechts".
- Belt text fields (`belt_warning_distance_screen.dart`,
  `belt_vibration_screen.dart`) have no label tied to the field; the label is a
  separate `Text` above it.
- Screen titles (`Geräte`, `Earbuds`, `Gürtel`, ...) are not marked as headings.
- No app locale is set in `main.dart`, so a screen reader may read German text
  with the wrong voice and Material built-in labels are English.
- `CalibrationScreen`: a 100-value `ListWheelScrollView` is very hard to use
  with a screen reader or a motor impairment. It needs a slider or +/- buttons.
  The user also cannot hear the volume while adjusting it.
- `SoundPilotLogo` has no `semanticLabel`.

## 2. Touch targets — Partly

- OK: the big buttons (60–90 dp), the type selector (48), the scan list rows (52).
- Too small (below 48 dp):
  - Delete "X" on `_DeviceCard` (32 dp).
  - Plain text links built from `GestureDetector` + `Text` (about 25–35 dp):
    "Als Gast Fortfahren", "Passwort vergessen?", "Registrieren",
    "Hier anmelden", "Abbrechen" (both tabs of the add-device dialog).
  - Tab bar in the add-device dialog (46 dp).
- Deleting a device has no confirmation or undo, and the "X" sits inside the
  tappable card (risk of accidental delete).

## 3. Contrast — Partly

- Dark theme: good. Light theme `primary`/`onPrimary`: about 7.6:1, good.
- `AppColors.mutedText` (light) is about 3.6:1 on the background and about 3.0:1
  on surfaces. Fails 4.5:1 for hint text, the inactive tab label and the small
  helper texts (12–14 px).
- `connectedGreen` / `disconnectedRed` dots: red is about 2.1:1 on the light-mode
  blue card, green is about 1.5:1 on the dark-mode yellow card (fails 3:1).

## 4. Text scaling — Fail

- `LoginScreen`, `RegisterScreen`, `StartScreen`, `CalibrationScreen` and
  `TestPage` are plain `Column`s with fixed heights and no scroll view. They
  overflow or clip with large system fonts, in landscape, or when the keyboard
  opens (register is the worst case).
- Only `DeviceScreen` scrolls, and only when it has more than 4 devices.
- The add-device dialog has a fixed content height of 260.
- Fixed button heights (e.g. 90 dp on `StartScreen`) clip wrapped text.
- Hard-coded `\n` line breaks in texts (`TestPage` description, dialog hints).
- Small font sizes: 12–15 px for helper and description texts.

## 5. Not color alone — Fail

- Connection state is only a red/green dot (classic color-blindness problem);
  the card itself has no text such as "Verbunden".
- Selected state of `_TypeSelector` and `_SideButton` is only a color change.
  (The scan list is fine: it also shows a check icon.)

## 6. Multiple channels — Fail

- No haptics anywhere and no vibration package in `pubspec.yaml`.
- The belt setup asks for vibration strength but gives no way to feel it.
- Calibration and the test exercise rely on sound only.

## 7. Simple flows — Partly

- `PopScope(canPop: false)` on login/register disables the system back button and
  gesture; only the arrow in the top bar works.
- Errors are a generic snackbar message with no reason (`AuthService` returns
  `null`).
- The register form asks for first name, last name and belt, but none of it is
  saved.
- The focused text field looks the same as an unfocused one on login and register
  (`focusedBorder` equals `enabledBorder`). The belt text fields have no border
  change either.
- No `autofillHints` / `textInputAction` on the auth fields.
- Belt screens use ALL-CAPS text; "SUCHE GURT..." is static placeholder text.
- Belt strength and distance inputs are not validated and show no error message.

## What already works

- Large buttons and fonts, generous spacing.
- Dark theme with strong contrast, follows the system setting.
- Icon plus text on Start/Stop; check icon for a selected scan result.
- Loading screens with a text.
- Mostly one main action per screen.

## Suggested fix order

1. Labels and semantics (icon buttons, headings, selected state, connection
   state, wheel/slider).
2. Make screens scrollable and text-scale safe.
3. Text next to the connection dot, and a non-color selected state.
4. Larger tap targets (delete "X", text links), delete confirmation or undo.
5. Enable the system back button on login/register.
6. Contrast fixes in `AppColors` (`mutedText`, status colors).
7. Haptic feedback for the belt; audio preview while calibrating.
8. Set the app locale; clearer error messages; visible focus state.
