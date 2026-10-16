# SoundPilot — Project Context

Project context: architecture, data model and team conventions.
Diploma project (HTL).

> Rule for this document: it contains only what is backed by the code or the
> architecture docs, and describes the current state — history belongs in git
> and the pull requests. Unclear points are listed under "Open Points" and are
> marked as open — do not treat them as fact; check the code or ask.
>
> Status: reconciled with `firebase/firestore.rules`,
> `firebase/functions/src/index.ts`, `firebase/firebase.json`,
> `frontend/soundpilot_application/lib/` and `.github/workflows/ci-cd.yml`.

## 1. Overview

- **App:** SoundPilot
- **Client:** Flutter / Dart
- **Backend:** Firebase — Authentication, Cloud Firestore, Cloud Functions
- **Purpose:** User authentication and management of calibration data for
  two hardware types: headphones (`HeadphoneCalib`) and belt (`BeltCalib`)

### Core requirement: accessibility

The UI must be very friendly for people with disabilities. This is the core of
the project, not an add-on. Every UI change must be evaluated against it.

Guidelines for new and changed UI code (a requirement from the team, not a
statement about the current state of the code):

- **Screen readers:** all interactive and informative elements need meaningful
  labels (`Semantics`, `semanticLabel`, `tooltip`); decorative elements are
  excluded from the semantics tree. Must work with TalkBack (Android) and
  VoiceOver (iOS). `test/screen_reader_test.dart` measures Flutter's own
  guidelines (labels, Android 48 dp and iOS 44 dp tap targets) over every
  screen and dialog in both themes, plus the states that matter (selected side
  and type, card with its connection, calibration value, named text fields).
  Two rules that cost real defects:
  - **Never wrap `Semantics` or a `Tooltip` around an `ElevatedButton`,
    `TextButton` or `OutlinedButton`.** `ButtonStyleButton` wraps itself in
    `Semantics(container: true)`, so the wrapper becomes a node of its own and
    never reaches the node a screen reader focuses. Put the label or the state
    on the button's *content* instead, as `_IconSquareButton` and `_SideButton`
    do.
  - **Name a text field that can be pre-filled with a `Semantics(label: ...)`
    wrapper** (`AuthTextField`, `BeltNumberField`): an invisible `labelText`
    only reaches the semantics tree while the field is empty, so a pre-filled
    field is announced as a nameless text box.
- **Touch targets:** at least 48×48 dp, with enough spacing between them.
- **Contrast:** at least WCAG AA (4.5:1 for text, 3:1 for large text and
  controls) in both light and dark theme (`core/theme/app_colors.dart`).
  `test/color_contrast_test.dart` measures the palette and fails CI if it is
  broken. If a colour change makes it fail, change the colour — do not lower
  the threshold. `mutedText` has to hold 4.5:1 on the *darker* `surface`, not
  only on `background`.
- **Text scaling:** layouts must not break or clip with large system font
  sizes; no fixed heights for text containers, and no screen may cap the
  system font size (see §7). `test/accessibility_layout_test.dart` renders the
  screens at text scale 1.0, 1.6 and 2.0 on a 360x720 phone.
- **Not color alone:** never convey state (e.g. connected, error) by color only;
  add text or an icon.
- **Multiple channels:** important feedback (e.g. belt warning distance,
  calibration) should be available via more than one sense — visual, audio and
  haptic/vibration — where the hardware allows it.
- **Simple flows:** short, clear German texts, one main action per screen,
  clear error messages (auth errors: `AuthService` returns an `AuthResult`
  with a German message from `AuthService.messageForCode`), no
  time-limited interactions. Messages go through `showAppMessage` /
  `showAppError` (`core/widgets/app_snack_bar.dart`), never through a
  hand-built `SnackBar`: in Flutter 3.47 the auto-dismiss timer only looks at
  `SnackBar.persist` (default: `action != null`), so a message without an
  action disappears after 4 s even with a screen reader running.
- **Motion:** respect the system setting for reduced animations.

When in doubt, choose the more accessible option and mention the trade-off.

### Packages (`pubspec.yaml`)

| Package | Purpose |
|---|---|
| `firebase_core` | Initialization |
| `firebase_auth` | Authentication (email/password, Google Sign-In) |
| `google_sign_in` | Google login |
| `cloud_firestore` | devices and calibration of signed-in users (`FirestoreDeviceRepository`, see §4) |
| `shared_preferences` | devices of app versions before the Firestore sync (`DeviceStorageService`) |
| `flutter_localizations` | German labels for Flutter's built-in widgets (see §7) |
| `google_fonts` | Plus Jakarta Sans font |
| `logger` | global `logger` in `core/app_logger.dart` |
| `fake_cloud_firestore` (dev) | in-memory Firestore for the repository tests; pinned to 4.1.0, newer versions need newer Firebase packages |

`firebase_database` is **not** included.

Cloud Functions are written in **TypeScript (Node.js 22)**.

## 2. Directories

```
frontend/soundpilot_application/   Flutter app
  tool/run_with_log.mjs            `flutter run` with a log file (see §3)
  logs/                            its log files, git-ignored
firebase/                          Firestore rules, Cloud Functions, Hosting
  firestore.rules
  functions/src/index.ts
  functions/lib/                   tsc output, git-ignored (see §3)
  web/                             the hosting site (see §3): auth-action.html
                                   is the page the e-mail links open
.github/workflows/ci-cd.yml        CI/CD pipeline (see §3)
```

All Flutter commands are run from `frontend/soundpilot_application/`,
all Functions commands from `firebase/functions/`.

### Structure of `lib/`

```
main.dart                        Entry point, themes, start routing (AppEntryPoint)
firebase_options.dart            generated
models/user_model.dart           HeadphoneCalib, BeltCalib, UserModel
core/
  app_locale.dart                App language (fixed German), shared with tests
  app_logger.dart
  theme/app_colors.dart          Colors depending on context (light/dark)
  widgets/                       LoadingScreen, SoundPilotLogo,
                                 AppTopBar, AuthTextField,
                                 GoogleSignInButton, GoogleLogo,
                                 app_snack_bar.dart (showAppMessage /
                                 showAppError, see §1 "Simple flows")
  services/
    device_repository.dart       DeviceRepository + GuestDeviceRepository
                                 (guest, memory only)
    firestore_device_repository.dart  devices of a signed-in user
    device_storage_service.dart  local devices of older app versions
    guest_mode_service.dart      guest mode flag (ValueNotifier, this run)
    audio_device_service.dart    MethodChannel com.soundpilot/audio_devices
features/
  auth/auth_service.dart
  auth/auth_flow.dart            shared sign-in flow of login + register
  auth/guest_devices_offer.dart  after sign-in: take over or delete the
                                 guest devices (GuestDevicesDialog)
  auth/screens/                  start, login, register, password_reset
  device/screens/                device_screen, calibration_screen,
                                 belt_vibration_screen,
                                 belt_warning_distance_screen, test_page
  device/volume_scale.dart       wheel value <-> stored volume <-> played gain
  device/headphone_connection.dart  whether one earbud is connected
  device/widgets/                device_type (DeviceType + device scan),
                                 add_device_dialog, device_card,
                                 belt_setup_fields, unsynced_logout_dialog
```

- **Fonts:** Plus Jakarta Sans is set once as the `textTheme` of both themes
  in `main.dart` (`GoogleFonts.plusJakartaSansTextTheme`). Screens still name
  `GoogleFonts.plusJakartaSans(...)` for their own sizes/weights. The one
  exception is `_sideTitleStyle` in `calibration_screen.dart` ('Linke Seite' /
  'Rechte Seite'), which uses the platform's own font on purpose
  (`inherit: false` and no family, so the text theme is not merged in).
  **Plus Jakarta Sans ends at `w800`**, so a `w900` style has no real face:
  Flutter takes the w800 file and fakes the extra weight by smearing it.
  Prefer `w800`; the remaining `w900` texts ('Geräte', 'Stärke in %', the
  dialog titles) are still synthesised and should follow.
- **Weight:** every visible text is bold (`w700` or heavier) — a request from
  the team for legibility. The only exception is the placeholder and the label
  *inside* an input box (`hintStyle` / `labelStyle` / `floatingLabelStyle`),
  which stay at `w600`, so an empty field is distinguishable from the bold text
  the user types into it. `grep -rn "FontWeight.w[1-6]00" lib` should only ever
  find those.
- **Shared widgets:** use `AppTopBar` for the top bar of a screen and
  `AuthTextField` for the login/register fields instead of building new ones.
- **Device types:** the `DeviceType` enum
  (`features/device/widgets/device_type.dart`) carries every user-visible word
  of a type (labels, scan button, hints). Do not compare bare strings like
  `'Earbuds'` / `'Gürtel'`.
- **State management:** no package, only `StatefulWidget` + `setState`.
- **Routing:** `Navigator.push` with `MaterialPageRoute`, no router package.
- **Start and auth state:** `AppEntryPoint` listens to
  `FirebaseAuth.authStateChanges()` and `GuestModeService.active`. It shows
  `DeviceScreen` if a user is signed in or guest mode is active, otherwise
  `StartScreen`, and switches by itself on sign-in, logout and "Als Gast
  fortfahren". Do not navigate to `DeviceScreen`/`StartScreen` manually:
  login/register are pushed on top and only close themselves on success
  (`popUntil(isFirst)`). It also hands `DeviceScreen` its `DeviceRepository`
  (see §4) and whether a user is signed in, so the screen itself does not
  touch Firebase.
- **Guest mode** lasts for one app run: **nothing a guest does is written to
  the phone**, neither the mode nor the devices (see §4), so every start shows
  the `StartScreen` and every guest starts with an empty list. Storing either
  (`guestMode` and `user_calibration_guest` in SharedPreferences) sent a guest
  straight to the `DeviceScreen` on every later start with no way back, and
  left their devices on the phone for whoever opened the app next;
  `GuestModeService.load()` deletes both on start, so an install carrying them
  is not stuck. On sign-in and registration only the flag is turned off; the
  guest's devices are then offered for the account (see §4). Logout ends guest
  mode with `GuestModeService.end()`, which also forgets the guest's devices,
  and leads to `StartScreen`.
- **Google sign-in** takes two paths. On Android/iOS,
  `AuthService.signInWithGoogle()` uses the `google_sign_in` plugin and builds
  a Firebase credential from its ID token. In the browser it calls
  `FirebaseAuth.signInWithPopup(GoogleAuthProvider())`, which keeps the app's
  own accessible button (`google_sign_in_web`'s `signIn()` is deprecated and
  its `renderButton()` cannot be styled). The client ID meta tag in
  `web/index.html` is only needed by `google_sign_in_web`, which the web
  build no longer calls.
- **Password reset:** "Passwort vergessen?" on the login screen opens
  `PasswordResetScreen` (one field, pre-filled with the typed address, one
  button; the result stays on screen as text with an icon), which calls
  `AuthService.sendPasswordReset`. The link opens our own page
  (`firebase/web/auth-action.html`, see §3), where the new password is set.
  Back in the app the only thing left is to sign in again, so after a
  successful request the button says "Weiter" and pops down to the first route
  (`AppEntryPoint`, i.e. the `StartScreen`). The app never changes a password
  itself — whoever forgot it cannot enter the old one. `main.dart` sets
  Firebase's language to German (`FirebaseAuth.setLanguageCode`), so the
  e-mail uses Firebase's German template unless it was customised in the
  console.

## 3. Commands

```cmd
cd frontend/soundpilot_application
flutter pub get
flutter run
```

### Google Sign-In setup

- **Android:** every developer registers their own debug SHA-1 once in the
  Firebase console (Project settings → the Android app → "Add fingerprint")
  and puts the newly downloaded `google-services.json` into `android/app/`.
  Get the SHA-1 with `gradlew.bat signingReport` in
  `frontend/soundpilot_application/android`. Without it, Google sign-in fails
  with `ApiException: 10` (DEVELOPER_ERROR), reported as "Die
  Google-Anmeldung ist für diese App-Version nicht freigegeben."
  (`AuthService.messageForGoogleCode`). Everything else works without it.
- **Browser:** goes through `signInWithPopup` and needs no SHA-1. The host
  must be listed under *Authorized domains* in the Firebase console
  (Authentication → Settings); `localhost` is there by default, on any port.

### Web development

- `web_dev_config.yaml` fixes `flutter run -d chrome` to
  `http://localhost:5000` (also with the run button in Android Studio).
- `flutter run -d chrome` starts Chrome with a temporary profile, so the
  Firebase and Google login are asked again on every start (debug only). To
  keep them, add the run arg
  `--web-browser-flag=--user-data-dir=C:\Users\<you>\.flutter-chrome-profile`.

### Run logs

To keep what `flutter run` prints, start it through the log script with the
same arguments:

```cmd
cd frontend/soundpilot_application
node tool/run_with_log.mjs -d <device>
```

Every start writes `logs/run-<date>_<time>.log` (header with the arguments,
branch and commit; a time in front of every line; colour codes removed) and
keeps only the newest 5. The keys of `flutter run` (`r`, `R`, `q`) still work.
The file is written on the PC, not by the app. The logs can contain e-mail
addresses and device names; do not share them carelessly.

In Android Studio (repo root opened as the project), use the shared run
configuration **"flutter run with Log"** (`.run/`). It runs the script in the
terminal, so the device dropdown does not apply: with more than one device
connected, `flutter run` asks in the terminal. It needs the bundled *Shell
Script* plugin and `node` on the `PATH`.

### Cloud Functions and emulators

```cmd
cd firebase/functions
npm run lint       :: eslint (also run in CI)
npm run build      :: tsc
npm run serve      :: Build + emulator (functions only)
npm run deploy     :: firebase deploy --only functions (does NOT build first)
```

- `firebase/functions/lib/` (the compiled JavaScript) is git-ignored and
  `firebase.json` has no predeploy build step: run `npm run build` after
  cloning or pulling, before using the emulator or deploying by hand.
- To test the auth triggers together with the rules, run
  `firebase emulators:start --only functions,auth,firestore` from `firebase/`
  (ports: functions 5001, auth 9099, firestore 8080).
- `firebase.json` configures Firestore, Functions and Hosting; Cloud Storage
  is not used. The hosting emulator and the web dev server (see "Web
  development" above) both use port 5000 — run only one of them at a time.
- On Windows, `npm run lint` reports `linebreak-style` (CRLF) errors when
  git's `core.autocrlf` is on. The repo stores LF, so CI is not affected.

### Toolchain versions

- **Everyone uses the Flutter version CI pins (3.47.6).** `pubspec.yaml`
  requires its Dart (`sdk: ^3.13.0`). A different Flutter gives different
  analyzer warnings and can rewrite transitive versions in `pubspec.lock`;
  do not commit such lock changes unless you changed dependencies on purpose
  (`git checkout -- pubspec.lock`). To upgrade, change the CI version, the
  `sdk` constraint, the lock and this section in one PR.
- **Android build:** Flutter 3.47.6 needs at least Gradle 8.14, Android
  Gradle plugin 8.11.1 and Kotlin 2.2.20
  (`android/gradle/wrapper/gradle-wrapper.properties`,
  `android/settings.gradle.kts`). CI does not build the app, so it would not
  notice a mismatch; raise these together with Flutter. Keep the
  `android.builtInKotlin` / `android.newDsl` lines in
  `android/gradle.properties` (written by Flutter's migrator). Flutter warns
  that these versions will be dropped (it names Gradle 9.1, AGP 9.0.1,
  Kotlin 2.3.20); moving to AGP 9 is a separate migration, ideally with the
  next Flutter upgrade.
- **Java:** this Gradle needs Java 17–24 and fails on Java 25, which recent
  Android Studio versions bundle. Point Flutter to a JDK 21 once:
  `flutter config --jdk-dir=<path to JDK 21>`.

### Troubleshooting

- `PKIX path building failed` during the first Android build: an antivirus or
  proxy intercepts HTTPS. Set
  `GRADLE_OPTS=-Djavax.net.ssl.trustStoreType=Windows-ROOT` and the same for
  `JAVA_TOOL_OPTIONS` for that build.
- "Connection closed before test suite loaded" on Windows is a crash of the
  local test runner, not a failing test: rerun those files with
  `flutter test --concurrency=1 <files>`.
- Strange build or test behaviour after switching branches, Flutter versions
  or native dependencies: `flutter clean`, then `flutter pub get`. Not
  routinely — the next build starts from scratch and takes minutes.

### The hosting site (`firebase/web/`)

Two static pages, deployed by CI with everything else:

- `auth-action.html` — the page a link from a Firebase Auth e-mail opens
  ("Passwort vergessen?", see §2). It reads `mode` and `oobCode` from the URL,
  sets the new password with `confirmPasswordReset` and tells the user to sign
  in again in the app. `verifyEmail` and `recoverEmail` are handled too, so no
  link of Firebase's lands on a blank page. Written in the app's palette
  (`core/theme/app_colors.dart`, light and dark) and in Plus Jakarta Sans,
  with the accessibility rules of §1.
- `index.html` — one paragraph, so the bare domain is not a 404.

Both are plain HTML with the Firebase JS SDK (pinned, from `gstatic.com`).
**No API key lives in the repository:** the page reads the config from
`/__/firebase/init.json`, which Firebase Hosting serves for its own project.
That is also why it only works when Hosting serves it — opening the file from
disk shows its "Seite nicht erreichbar" message.

**One setting has to be made by hand, once per project:** Firebase console →
Authentication → Templates → "Passwort zurücksetzen" → the pencil next to the
template → *Aktions-URL anpassen* → `https://<project>.web.app/auth-action`.
Without it, Firebase keeps sending its own page and this one is never opened.

To look at it locally: `firebase emulators:start --only hosting` in `firebase/`
(port 5000) — the emulator serves `init.json` as well, but the links
themselves still need a real e-mail from the project.

### CI/CD (`.github/workflows/ci-cd.yml`)

Runs on every pull request to `main` and every push to `main`:

| Job | Steps | Fails on |
|---|---|---|
| `build_and_test` | `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test` (Flutter 3.47.6) | analyzer warnings/errors, failing tests |
| `functions` | `npm ci`, `npm run lint`, `npm run build` (Node.js 22) | lint errors, TypeScript errors |
| `deploy` | build functions, `firebase deploy --only firestore:rules,functions,hosting` | any deploy error |

- **Deploying is automatic.** `deploy` runs only on pushes to `main` (i.e.
  merged PRs) and only after both other jobs pass. Rules, functions and the
  hosting site do not need to be deployed by hand.
- A manual deploy is overwritten by the next deploy from `main`. Deploy by
  hand only for things CI does not deploy (e.g. Firestore indexes), and test
  unmerged changes with the emulators instead.
- The app itself is not built or released by CI.
- `firebase-tools` is pinned to `15.5.1` (the unpinned latest version failed
  to deploy). Change it on purpose and check the first deploy after it.
- The deploy authenticates with a Google Cloud service account: its JSON key
  is the repository secret `FIREBASE_SERVICE_ACCOUNT`, exported as
  `GOOGLE_APPLICATION_CREDENTIALS` by `google-github-actions/auth`. A 403 /
  permission error means the service account is missing an IAM role.
- Deploys run one after another (`concurrency: deploy-main`) and with
  `--debug`. The deploy step makes up to 3 attempts, 30 s apart, because
  Google APIs sometimes return a temporary 503; a retry shows up as a
  warning. A deploy that fails all 3 attempts is a real error.

## 4. Data Model

### Persistence

`DeviceScreen` reads and writes the devices through a `DeviceRepository`
(`core/services/device_repository.dart`): `watch()` delivers the whole device
list (`DeviceData`) and again after every change, and every write changes one
device (`putHeadphone`, `putBelt`, `removeHeadphone`, `removeBelt`).

**Signed-in users: Firestore** (`FirestoreDeviceRepository`), field
`calibration` of `users/{uid}` (schema below).

- Reads with a snapshot listener, so a document the cloud function writes
  late is picked up (see §6, eventual consistency).
- Writes one device per field path (`FieldPath(['calibration', 'headphones',
  key])`), deletes with `FieldValue.delete()`; never the whole map. Writes
  wait until the document exists.
- Offline: Android and iOS keep a Firestore cache on disk; the browser keeps
  it in memory only (on purpose, see logout below). A write shows up at once
  but its future only completes when the server has it, so `DeviceScreen`
  does not await writes; a failed write is reported with a SnackBar.
- **Logout clears the cache** (Android/iOS): `AuthService.logout()` calls
  `terminate()` + `clearPersistence()` after the sign-out. The web plugin
  keeps the terminated instance (every later call fails until a reload),
  which is why the browser has no disk cache.
- Clearing also drops writes that have not reached the server. Before the
  logout, `DeviceScreen` asks `AuthService.hasUnsavedChanges()`, which waits
  up to 5 s for them; if they are still pending it shows
  `UnsyncedLogoutDialog` ("Angemeldet bleiben" / "Trotzdem abmelden").
- **Old local devices:** on the first snapshot from the server, devices stored
  under the SharedPreferences key `user_calibration_<uid>` (older app
  versions) that are not in the account yet are uploaded in one update;
  devices already in the account win. Then the local key is removed; if the
  upload fails, it is tried again on the next start.

**Guests: nothing is stored** (`GuestDeviceRepository`). Their devices live in
memory for one app run and are gone when the app closes: without an account
there is nowhere they belong, and storing them left a stranger's data on the
phone for whoever opened the app next. The state is `static`, so it survives a
rebuild of `AppEntryPoint` and can be read by the sign-in flow after
`DeviceScreen` is already gone; `watch()` is served from one shared broadcast
stream, and `dispose()` does nothing. Signing in is the only way they are ever
written, and **only if the user agrees**:

- After a sign-in or registration with guest devices present, `runSignIn`
  calls `offerGuestDevices` (`GuestDevicesDialog`: "Geräte übernehmen" /
  "Geräte löschen"; back and tapping outside do nothing, no time limit).
- "Übernehmen" waits for the user document and adds the devices that are not
  in the account yet (`FirestoreDeviceRepository.addMissingDevices`, the
  account wins), at most `guestUploadTimeout` (30 s), then forgets them. If it
  fails, a SnackBar says so and they stay for the rest of this app run.
- "Löschen" forgets them. Logout forgets any that are left
  (`GuestModeService.end()`).
- `GuestModeService.load()` deletes the guest devices an older app version
  stored under `user_calibration_guest`.

### Volume and sound

- The earbud volumes are `HeadphoneCalib.volumeLeft` / `volumeRight`.
  `CalibrationScreen` shows them on a wheel as 1–100 (`volumeToWheel` /
  `wheelToVolume` in `features/device/volume_scale.dart`). The stored value
  is the wheel position (`0.01`–`1.0`), not a gain: what is played is
  `wheelToGain`, evenly in decibels from −40 dB at 1 to 0 dB at 100.
- While the earbud is connected, `CalibrationScreen` offers a test tone
  ("Testton abspielen" / "Testton stoppen") routed to that earbud; turning a
  wheel changes its side at once. It never starts by itself, because a screen
  reader speaks through the same headphones. It stops when the screen is
  left, the app goes to the background, the earbud disconnects or the
  `TestPage` opens. Not connected: a note and a button to the Bluetooth
  settings. Outside the Android app there is no tone.
- The `TestPage` ("Testübung") plays `assets/audio/Marschieren.mp3` the same
  way, with the calibrated gain per side. **Unlike the calibration's test tone
  it does not need the earbud:** it plays on the calibrated earbud while that
  is connected and on the phone's own output otherwise (`deviceId` null, which
  the native side already understands). The note then says that the recording
  runs through the speaker and that left/right can only be heard on the
  earbuds, and the status line names the output as well. The test tone keeps
  requiring the earbud, because setting one ear's volume without that ear is
  meaningless.
- **'Start' and 'Stop' are both always on the screen**
  (`_buildPlaybackControls`, see §7), plus the button to the Bluetooth
  settings while no earbud is connected. 'Start' keeps the app's colour
  wherever there is sound at all and restarts the recording when it is already
  playing (the native side stops the running player before it opens the new
  one anyway); 'Stop' is grey until there is something to stop and red while
  it runs. Only a playback that went to the earbud is stopped when the earbud
  disconnects (`_playingOnEarbud`); sound on the phone itself keeps running.
- Both sounds go through `GainPlayer.java` (decoded with `MediaCodec`, mixed
  to mono, a gain per side).

### Bluetooth and connection state

- **Headphones only, Android only.** The add dialog's scan (`scanForDevices`
  in `device_type.dart`) lists real headphones; the belt scan is simulated
  (fixed list, 1.5 s delay). Before the scan it checks that Bluetooth is on
  and asks for the permission ("Geräte in der Nähe"); each case has its own
  German text and, where it helps, a button to the settings.
- The native side is `MainActivity.java`: connected output devices (with the
  address from Android 9), a live event stream
  (`com.soundpilot/audio_device_events`), paired audio devices, the routed
  test tone, the `BLUETOOTH_CONNECT` permission (Android 12+) and the
  Bluetooth state. The app never pairs or connects headphones itself.
- `AudioDeviceService` wraps it; `findHeadphones()` merges connected and
  paired headphones into one list per headset and returns a simulated list
  where there is no Bluetooth (browser, desktop, most emulators). Bluetooth
  that is only switched off is not simulated.
- The connection state is runtime only. A headphone card counts as connected
  while headphones with its key (address, case-insensitive) are an active
  audio output (`AudioDeviceService.headphoneChanges()`). Changes are
  announced to screen readers ("… ist jetzt verbunden" / "… getrennt"),
  except the state at the start. Without Bluetooth only `simulated_1` …
  `simulated_5` are connected; typed-in and `dummy_mac_…` headphones never
  are. Belts count as connected once their setup was finished in this
  session.

### Firestore: collection `users`

Document ID = Firebase Auth UID (`user.uid`). This is how `createUserDoc`
creates it:

```json
{
  "uid": "string",
  "email": "string | null",
  "displayName": "string",
  "createdAt": "Timestamp",
  "schemaVersion": 1,
  "providers": ["password"],
  "settings": { "language": "system", "theme": "system" },
  "calibration": {
    "headphones": { "<BD_ADDR>": { "modelId": "string", "volLeft": 0.5, "volRight": 0.5 } },
    "belts":      { "<BD_ADDR>": { "modelId": "string" } }
  }
}
```

`displayName` is `"New User"` if the auth account has no name (the Dart model
falls back to `"User"`). There is no `username` field anywhere in the code.

`schemaVersion` identifies the schema of the document (`SCHEMA_VERSION` in
`index.ts`, `UserModel.currentSchemaVersion` in Dart). **Increase it whenever
the default document changes**, in both places. Outdated documents can then be
found with a query on `schemaVersion` (documents without the field are read as
`0`) and migrated with a one-off admin script, not with a deployed function.
Only the cloud function writes it; the security rules block client writes.

### Key design decision: maps instead of arrays

Devices are stored as a **map**, keyed by the Bluetooth hardware address
(`BD_ADDR`) — **not** as an array. Rationale: O(1) access, atomic updates of
individual devices, no duplicates.

**Consequence for new code:** A single device is updated via a field path,
never by rewriting the whole map:

```dart
await FirebaseFirestore.instance.collection('users').doc(uid).update({
  'calibration.headphones.$bdAddr.volLeft': 0.7,
});
```

No read-modify-write of the entire `calibration` map — that creates race
conditions between multiple devices.

Keys:

- Headphones from the scan: their real `BD_ADDR`, upper case
  (`AA:BB:CC:DD:EE:FF`).
- Belts, names typed in by hand and headphones whose address Android does not
  report (Android 7–8): `dummy_mac_<timestamp>`.
- Simulated headphones without Bluetooth: `simulated_1` … `simulated_5`.

The scan does not offer headphones that are already in the list, so adding
them again cannot reset their calibration.

### Dart models (`models/user_model.dart`)

- `HeadphoneCalib` — `modelId`, `volumeLeft`, `volumeRight` (defaults `0.5`)
- `BeltCalib` — `modelId`
- `UserModel` — `id`, `displayName`, `email`,
  `Map<String, HeadphoneCalib> headphones`, `Map<String, BeltCalib> belts`

`isConnected` (both Calib classes) and `category` are runtime-only fields and
are not written by `toMap()`. `isConnected` is `false` after every load.
`category` is a `static const` of the enum `DeviceCategory` (`earbuds`,
`belt`); its `label` is the German UI text ('Earbuds', 'Gürtel'). Use the enum,
not category strings.

Mind the naming convention: in Dart `volumeLeft`/`volumeRight`, in Firestore
`volLeft`/`volRight`. The mapping happens exclusively in `fromMap()` /
`toMap()`. Keep this separation when extending the models.

All `fromMap` factories work defensively with fallbacks (`'unknown'`, `0.5`),
because Firestore documents can be missing fields. They check the type
(`value is String ? value : 'unknown'`), so fields of the wrong type fall back
too. Device maps are parsed with `parseDeviceMap()`, which skips invalid
entries instead of throwing (used by `UserModel.fromFirestore` and
`DeviceStorageService`). Add new fields in the same style; tests are in
`test/models/user_model_test.dart`.

## 5. Cloud Functions

File: `firebase/functions/src/index.ts`. Both functions run in the region
`europe-central2` and are auth triggers in 1st Gen:

- **`createUserDoc`** (`onCreate`) creates the default user document (schema
  see §4). It writes with `set(..., { merge: true })`.
- **`deleteUserDoc`** (`onDelete`) deletes `users/{uid}` when the auth account
  is deleted.

Both functions log errors and then **rethrow** them, and use
`runWith({ failurePolicy: true })`, so a failed run is retried (for up to
7 days). Keep them idempotent. A retry of `createUserDoc` rewrites
`createdAt`; what it does to existing data is open (see §7).

### Cloud Functions 1st Gen — deliberate decision

The trigger uses 1st Gen. Reason: in 2nd Gen, Firebase offers **no
asynchronous** `onCreate` trigger for auth events. The equivalent there is
**Blocking Functions** (`beforeUserCreated`), which require a project-wide
upgrade to *Firebase Authentication with Identity Platform* and intervene
synchronously in the registration process — an error would abort the
registration. 1st Gen is still supported by Firebase.

**Do not migrate to 2nd Gen without consultation.**

### Import rule

Since firebase-functions SDK **v6**, v2 is the default export. v1 APIs must be
imported explicitly. Installed is `firebase-functions` `^6.0.1`, and the code
contains:

```typescript
import * as functions from "firebase-functions/v1";

export const createUserDoc = functions
  .region("europe-central2")
  .runWith({failurePolicy: true})
  .auth.user()
  .onCreate(async (user) => { ... });
```

Before editing the functions, check the SDK version in `package.json` and
choose the import accordingly.

## 6. Security Rules (`firebase/firestore.rules`)

```javascript
match /users/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;
  allow create, delete: if false;
  allow update: if request.auth != null && request.auth.uid == uid
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['calibration', 'settings']);
}
match /{document=**} {
  allow read, write: if false;
}
```

For client code this means:

- A signed-in user may **read** their own document and **update** only the
  top-level fields `calibration` and `settings` (field paths such as
  `calibration.headphones.<BD_ADDR>.volLeft` are fine).
- The client can **not** create or delete the document, and can not change
  `uid`, `email`, `displayName`, `createdAt`, `providers` or `schemaVersion`.
  The cloud functions do that (the Admin SDK ignores the rules). This also
  means `UserModel.toMap()` can not be written as a whole.
- Other users' documents and all other paths, including any subcollection,
  are blocked. Do not build queries over the whole `users` collection. A rule
  for a new subcollection has to be added on purpose.
- The rules are not tested in CI. They were tested by hand against the
  Firestore emulator (13 allow/deny cases, 2026-09-24), and the writes of
  `FirestoreDeviceRepository` as REST field-path updates (2026-10-07).
  Re-test after changing them.

### Eventual consistency on registration

The auth trigger runs **asynchronously**. Right after registration, the client
may read `users/{uid}` before the function has written it. Registration flows
must therefore never be built with a one-time `get()`, but with a snapshot
listener on the document or a retry with backoff. A client-side `update()` on a
document that does not exist yet also fails.

## 7. Open Points

Not backed by evidence — check in the code instead of assuming:

- **Not tried on a real phone yet:** the Firestore sync (tested only with
  `fake_cloud_firestore` and the rules emulator; not offline or on two phones
  at once), clearing the cache on logout, taking over guest devices, the
  headphone scan, and Android 13+ predictive back
  (`enableOnBackInvokedCallback`).
- **The hosting site has not been opened in a browser** (`firebase/web/`, see
  §3), and whether the action URL is set in the Firebase console — without
  which the e-mail links never reach `auth-action.html` — nobody has
  confirmed.
- **Firestore cache after logout:** `clearPersistence()` only drops the data,
  it does not overwrite it securely (FlutterFire documentation). In the
  browser the memory cache lasts until the tab is reloaded or closed.
- **Guest devices if the app is closed during the question,** or after a
  failed take-over: they are gone — a guest's are never stored (§4). The user
  has to add them again in the account. Accepted on purpose.
- **Leaving guest mode:** within a session only by signing in; there is no
  button back to the `StartScreen`. Restarting the app does lead there
  (nothing of a guest is stored, see §2), and the devices they added are then
  gone.
- **`createUserDoc` retries:** `set(..., { merge: true })` with
  `settings` and the empty `calibration.headphones` / `belts` maps may reset
  those fields on a retry, instead of keeping existing devices. Not verified
  in the emulator.
- **Android 12+ address:** whether Android anonymises the Bluetooth address
  without the permission is not checked.
- **Old `dummy_mac_…` headphones:** devices stored under a placeholder key
  cannot be matched to real headphones; what to do with them is open.
- **Accessibility: measured in CI, never tested on a device.** Findings of the
  static review are in `docs/ACCESSIBILITY_AUDIT.md` (partly outdated), what
  is still to do in `docs/ACCESSIBILITY_TODO.md`, the screen reader plan (CI
  checks, device test protocol, open gaps) in `docs/SCREEN_READER_PLAN.md`.
  Still open: localisation (texts are hardcoded German; a second language
  would need `gen-l10n` with ARB files); multiple channels — one
  `HapticFeedback` call in the whole app, and only on the screen-reader path
  of the calibration wheel, while the belt warning distance has neither
  vibration nor sound; validation of the belt fields; a confirmation before a
  device is deleted; nothing verified with TalkBack or VoiceOver on real
  hardware, and whether they pick a German voice for the fixed German locale
  (`core/app_locale.dart`).
- **Browser as a target:** nobody has decided whether the web build is a
  target; `web/` is otherwise untouched Flutter scaffolding.
- **Password reset and Google accounts** (from Firebase's documentation, not
  tried here): a reset for a Google-only account adds e-mail/password to it;
  a Google sign-in with the Gmail address of an unverified e-mail/password
  account replaces the password. The app never sends a verification e-mail;
  whether it should is open. Whether the reset template was customised and
  whether e-mail enumeration protection is on has not been checked.
- **Two device-type enums:** `DeviceCategory` (`models/user_model.dart`, label
  only) and `DeviceType` (`features/device/widgets/device_type.dart`, all UI
  texts and the icon) describe the same two types. Merging them is open.
- **Firestore language default:** the function sets `settings.language:
  "system"`, but the app UI is German. Whether this is intended is open.
- **Test strategy** is not documented. Tests mirror `lib/` under `test/`;
  `test/helpers/` holds the fakes (repository, auth service). Not tested in
  CI: `AuthService` itself, the native Android side (`MainActivity.java`) and
  the security rules. `test/widget_test.dart` is still a placeholder.

### Settled decisions

- **The test exercise keeps both 'Start' and 'Stop', and works without an
  earbud** (see §4). Collapsing the pair into the single button that applied
  left two grey buttons as the screen's only offer without an earbud — a dead
  end on the screen that is how the app is shown and tried. Do not take either
  away again.
- **The registration form scrolls; do not try to fit it on one screen again.**
  Fitting it once cost a text-scale cap and small captions and fields — the
  wrong trade for an app about impaired vision. Sizes are bounded from below
  by `test/accessibility_layout_test.dart`. If the form has to get shorter,
  remove a field (first name, last name and the belt question are not used
  yet, see the TODO in the file) — do not shrink the type.

## 8. Working Conventions in This Repo

- English is the default language in the project (docs, code, comments,
  commits). Only user-facing UI texts are German.
- Do not output Firebase configuration files, API keys or `google-services.json`
  in responses or commits.
- When changing the Firestore schema, always update all three places:
  Cloud Function (defaults), Dart model (`fromMap`/`toMap`) and
  Security Rules.

### Git workflow

- **One short-lived branch per task**, created from an up-to-date `main`. No
  long-lived `develop` branch.
- **Naming:** kebab-case with a type prefix, e.g. `fix/accessibility-semantics`,
  `feature/firestore-sync`, `docs/branching-convention`.
- **Never commit or push code changes to `main`** unless explicitly told to.
  Work on a branch and merge through a pull request.
- Keep branches small and merge them quickly; delete a branch after it is
  merged.
- **`main` is protected on GitHub** (ruleset `main-ruleset`): every change,
  documentation included, goes through a pull request; merging needs green
  `build_and_test` and `functions` checks and 1 approval. Direct pushes,
  force pushes and deleting `main` are rejected. Admins may merge their own
  PR without an approval (or in an emergency with failing checks) via "bypass
  rules" / `gh pr merge --admin`, but cannot push to `main` directly either.

### Comment convention

- **Language:** Code comments in English. UI texts are German.
- **File header:** first line `// lib/<path>`, followed by one or two lines on
  the file's purpose.
- **Doc comments (`///`)** for classes, fields with non-obvious meaning and
  methods with logic. Plain `//` only inside methods. Trivial overrides
  (`build`, `dispose`, `createState`) need none.
- **Sections:** `// ── Title ───…` at 80 characters width.
- **Markers:**
  - `NOTE:` explains behavior that is not obvious.
  - `TODO(improve):` improvement suggestion from the code review (bugs,
    duplicates, deprecated APIs, missing integrations).
  - `TODO:` original open tasks of the team.
- **Keep existing comments:** The team's comments stay and are not rewritten
  more than needed. If one is outdated or wrong, correct it with a minimal
  change and preserve the original statement (example:
  `AuthService.loginWithEmail`).
- **Resolved TODOs are deleted.** When a `TODO` / `TODO(improve)` is fixed,
  remove it; do not turn it into a history note ("Originally a TODO …
  Fixed"). Add a short `NOTE:` only if the new code needs an explanation.
- Find all improvement suggestions:
  `grep -rn "TODO(improve)" frontend firebase/firestore.rules firebase/functions/src`
