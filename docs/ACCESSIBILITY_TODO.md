# Accessibility TODO — SoundPilot

Date: 2026-10-12
Basis: static code review plus **measured** semantics trees and Flutter
accessibility guidelines, rendered with the real app theme (AppColors + Plus
Jakarta Sans) on a 360x720 phone, light and dark, text scale 1.0/1.6/2.0 and
landscape 720x360. **Nothing verified with TalkBack or VoiceOver on a real
device.**
Reference: the guidelines in `docs/PROJECT_CONTEXT.md` §1, the plan in
`docs/SCREEN_READER_PLAN.md`, the older findings in
`docs/ACCESSIBILITY_AUDIT.md` (outdated, see §6).

## Where we stand

14 screens and dialogs x 2 themes x 4 guidelines (`labeledTapTargetGuideline`,
`androidTapTargetGuideline`, `iOSTapTargetGuideline`, `textContrastGuideline`):
one single violation, the add-device button. No overflow at any text scale, in
portrait or landscape.

§1, §2, §3 and the first four items of §4 are **done** (2026-10-12), together
with the safety net in §5; `flutter analyze` is clean and all 332 tests pass.
What is left is below the line in §4 and in §6.

## 1. Screen reader blockers — done

Three real defects. Two shared one root cause: `ButtonStyleButton` wraps itself
in `Semantics(container: true)` (`button_style_button.dart:591`), so anything
wrapped *around* an `ElevatedButton` / `TextButton` / `OutlinedButton` lands on
a separate node and never reaches the node the screen reader focuses.

- [x] **`+` button had no label** — `device_screen.dart`, `_IconSquareButton`:
      the `Tooltip` around the `ElevatedButton` left the name on the outer
      node. The label now sits on the `Icon` inside the button
      (`semanticLabel`), the tooltip stays as the visual long-press hint
      (`excludeFromSemantics: true`).
- [x] **Side buttons never announced "ausgewählt"** —
      `belt_vibration_screen.dart`, `_SideButton`: the `Semantics(selected:)`
      moved from around the button to its content.
- [x] **Pre-filled text fields were unnamed** — an invisible `labelText` only
      reaches the semantics tree while the field is empty. `AuthTextField`,
      `BeltNumberField` and the manual field of the add dialog now carry a
      `Semantics(label: ...)` wrapper instead.

## 2. Status changes that stayed silent — done

- [x] **End of the scan** — the list's semantics node is now a live region
      labelled 'N Geräte gefunden. Wähle ein Gerät aus.' (on the node, not as
      a visible row: a row pushed the first device out of the tab's fixed
      height).
- [x] **SnackBars disappeared after 4 s** — all five now go through
      `showAppMessage` / `showAppError` (`core/widgets/app_snack_bar.dart`),
      which sets `persist: true` plus an 'OK' action. In Flutter 3.47 the
      timer only looks at `SnackBar.persist`, so a running screen reader no
      longer keeps a message open by itself; `SCREEN_READER_PLAN.md` §3.3 is
      out of date on that point.
- [x] **Connection announcements** — `SemanticsService.sendAnnouncement` is
      only called where `MediaQuery.supportsAnnounceOf` is true, and the
      change is always shown as a line on the screen, which is a live region
      exactly where it cannot be announced (Android has deprecated
      announcement events). Visible to sighted users as well.

## 3. Polish for screen readers — done

- [x] **Duplicate announcements** — the name inside the device card, the value
      inside the calibration wheel's highlight box and the logo on the
      `StartScreen` (the heading says 'SoundPilot' right after) are now
      excluded from the semantics tree.
- [x] **No hint what a tap does** — the card label is now
      'Kopfhörer, Pods, nicht verbunden' with the tap hint 'Kalibrierung
      öffnen' / 'Einrichtung öffnen' (`DeviceType.openHint`), so the type no
      longer depends on a group heading that swipe navigation can skip.
- [x] **Dialogs had no name** — the three dialogs mark their title
      `namesRoute: true`.
- [ ] **Focus handling in dialogs** — focus still does not start at the title
      and does not return to where it was after closing (asked for in
      `SCREEN_READER_PLAN.md` §3.2). Needs a device test to judge.

## 4. Beyond screen readers

- [x] **Calibration wheel was squeezed at large fonts** — the item extent and
      the highlight box are now derived from
      `MediaQuery.textScalerOf(context)` instead of the fixed 44 / 72 dp.
      Measured before the fix (height of the number):

      | Text scale | Wheel (slot 44) | Highlight box (72) |
      |---|---|---|
      | 100 % | 37 ✔ | 46 ✔ |
      | 160 % | 44 (natural ~59) | 72 (natural ~74) |
      | 200 % | 44 (natural ~74) | 72 (natural ~82) |

      Nothing throws, so `accessibility_layout_test.dart` could not catch it;
      check it on a device at 200 %.
- [x] **Belt fields accepted anything** — `inputFormatters` now allow digits
      only, so a pasted word cannot become a setting.
- [x] **No `autofillHints`** — e-mail, password, first and last name carry
      them now, so password managers and autofill work.
- [x] **Reduced motion** — the `LoadingScreen` spinner is left out where the
      system asks for reduced animations (its status text already says that
      something is running).
- [x] **ALL-CAPS 'NEIN' / 'JA'** — now 'Nein' / 'Ja'.
- [x] **Deleting a device had no confirmation** — with TalkBack the delete
      button is the element right after the card, so one double tap dropped
      the device and its calibration for good. `RemoveDeviceDialog` now asks
      first and names the device; "Behalten" is the prominent button, and
      back or tapping outside keeps the device.

Still open:

- [ ] **Validation of the belt values** — digits only is in place, but a range
      check (warning distance, 0–100 %) with a spoken error message is still
      missing, and the values are still not stored at all (see the
      `TODO(improve)` in both belt screens).
- [ ] **Multiple channels is not implemented** (`PROJECT_CONTEXT.md` §1):
      `HapticFeedback` occurs once in all of `lib/`
      (`calibration_screen.dart`, and only on the screen-reader path), there
      is no `VIBRATE` permission and no vibration package, and the belt
      warning distance — the core feature for blind users — has neither
      vibration nor sound. This is a feature, not a fix: it needs the real
      belt hardware and a decision on the package.
- [ ] **Localisation** — texts are hardcoded German; a second language needs
      `gen-l10n` with ARB files.
- [ ] **The remaining `AnimatedContainer`s** (180 ms, type selector and scan
      list) still animate under reduced motion. Harmless, but inconsistent.

## 5. Safety net — done

- [x] `test/screen_reader_test.dart`: `labeledTapTargetGuideline`,
      `androidTapTargetGuideline` and `iOSTapTargetGuideline` over every
      screen and dialog in both themes, plus `isSemantics` checks for the
      selected side and type, the card with its connection and tap hint, the
      calibration value and the named text fields. Reverting either blocker
      fix makes four of these tests fail, which is what the net is for.
      `textContrastGuideline` is left out: it renders the screen to an image,
      and the await inside it lets google_fonts' runtime font fetch fail
      inside the test. The palette stays measured in
      `color_contrast_test.dart`.
- [x] `accessibility_layout_test.dart` now renders with the real app theme
      (`SoundPilotApp.buildTheme`, made public for this) instead of a plain
      `ThemeData`, so sizes are measured with AppColors and Plus Jakarta Sans.
- [ ] Two real colour pairs are still missing from `color_contrast_test.dart`:
      the unselected side button's border on its own fill (2.8:1; against the
      screen background 3.4:1, so still within WCAG 1.4.11) and text over the
      `StartScreen` gradient (passes the rendered check, but nothing guards
      it).

## 6. Only answerable on a device

- [ ] Run the TalkBack/VoiceOver protocol from `SCREEN_READER_PLAN.md` §3.2:
      reading order, whether the labels make sense, focus after dialogs,
      status changes. None of it can be proved in a widget test.
- [ ] Look at every screen at 200 % system font size on a real phone, the
      calibration wheel first.
- [ ] Rewrite `docs/ACCESSIBILITY_AUDIT.md`: it still says "nothing has been
      fixed yet" and its screen-reader findings are stale (tab bars are 72 dp
      now, not 46; L/M/R read as Links/Mitte/Rechts).

## Definition of "done"

1. ~~§1 fixed~~ — done.
2. ~~§5 in CI~~ — done; the guidelines now stay green by themselves.
3. §2 and §3 worked through — done except focus handling in dialogs; §4 is
   open where it needs a product decision or hardware. The belt needs
   vibration *and* sound before it can count as accessible.
4. §6 passed with a screen reader on real hardware. Only then is the claim
   backed by evidence — ideally in a session with someone who uses a screen
   reader every day, which would also be the stronger evidence for the thesis.
