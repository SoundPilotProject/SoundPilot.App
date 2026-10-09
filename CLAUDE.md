# CLAUDE.md — SoundPilot

Project context: architecture, data model and team conventions.
Diploma project (HTL).

> Rule for this document: it contains only what is backed by the code or the
> architecture docs. Unclear points are listed under "Open Points" and are
> marked as open — do not treat them as fact; check the code or ask.
>
> Status: reconciled with `firebase/firestore.rules`,
> `firebase/functions/src/index.ts`, `frontend/soundpilot_application/lib/`
> and `.github/workflows/ci-cd.yml`.

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
  VoiceOver (iOS).
- **Touch targets:** at least 48×48 dp, with enough spacing between them.
- **Contrast:** at least WCAG AA (4.5:1 for text, 3:1 for large text and
  controls) in both light and dark theme (`core/theme/app_colors.dart`).
  `test/color_contrast_test.dart` measures this on the palette and fails CI if
  it is broken. If a colour change makes it fail, change the colour — do not
  lower the threshold. Note that `mutedText` has to hold 4.5:1 on the *darker*
  `surface`, not only on `background`.
- **Text scaling:** layouts must not break or clip with large system font
  sizes; no fixed heights for text containers.
  `test/accessibility_layout_test.dart` renders the screens at text scale 1.0,
  1.6 and 2.0 on a 360x720 phone. No screen caps the system font size any more
  (the registration form used to, see §7).
- **Not color alone:** never convey state (e.g. connected, error) by color only;
  add text or an icon.
- **Multiple channels:** important feedback (e.g. belt warning distance,
  calibration) should be available via more than one sense — visual, audio and
  haptic/vibration — where the hardware allows it.
- **Simple flows:** short, clear German texts, one main action per screen,
  clear error messages (auth errors: `AuthService` returns an `AuthResult`
  with a German message from `AuthService.messageForCode`), no
  time-limited interactions.
- **Motion:** respect the system setting for reduced animations.

When in doubt, choose the more accessible option and mention the trade-off.

### Packages (`pubspec.yaml`)

| Package | Purpose |
|---|---|
| `firebase_core` | Initialization |
| `firebase_auth` | Authentication (email/password, Google Sign-In) |
| `google_sign_in` | Google login |
| `cloud_firestore` | devices and calibration of signed-in users (`FirestoreDeviceRepository`, see §4) |
| `shared_preferences` | local persistence (guest devices, guest mode) |
| `flutter_localizations` | German labels for Flutter's built-in widgets (see §7) |
| `google_fonts` | Plus Jakarta Sans font |
| `audioplayers` | Audio playback (calibration) |
| `logger` | global `logger` in `core/app_logger.dart` |
| `fake_cloud_firestore` (dev) | in-memory Firestore for the repository tests; pinned to 4.1.0, newer versions need newer Firebase packages |

`firebase_database` is **not** included.

Cloud Functions are written in **TypeScript (Node.js 22)**.

## 2. Directories

```
frontend/soundpilot_application/   Flutter app
firebase/                          Firestore rules, Cloud Functions
  firestore.rules
  functions/src/index.ts
  functions/lib/                   tsc output, git-ignored (see §3)
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
                                 GoogleSignInButton, GoogleLogo
  services/
    device_repository.dart       DeviceRepository + LocalDeviceRepository
                                 (guest)
    firestore_device_repository.dart  devices of a signed-in user
    device_storage_service.dart  local persistence of devices + calibration
    guest_mode_service.dart      guest mode flag (ValueNotifier + stored)
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
  device/widgets/                device_type (DeviceType + device scan),
                                 add_device_dialog, device_card,
                                 belt_setup_fields, unsynced_logout_dialog
```

- **Fonts:** Plus Jakarta Sans is set once as the `textTheme` of both themes
  in `main.dart` (`GoogleFonts.plusJakartaSansTextTheme`). Screens still name
  `GoogleFonts.plusJakartaSans(...)` for their own sizes/weights; no other
  family is used anywhere.
- **Weight:** every visible text is bold (`w700` or heavier) — a request from
  the team for legibility. The only exception is the placeholder and the label
  *inside* an input box (`hintStyle` / `labelStyle` / `floatingLabelStyle`),
  which stay at `w600`, so an empty field is distinguishable from the bold text
  the user types into it. `grep -rn "FontWeight.w[1-6]00" lib` should only ever
  find those.
- **Shared widgets:** `AppTopBar` replaced the five nearly identical private top
  bars, `AuthTextField` the two login/register field duplicates.
- **Device types:** the `DeviceType` enum
  (`features/device/widgets/device_type.dart`) carries every user-visible word
  of a type (labels, scan button, hints). Do not compare bare strings like
  `'Earbuds'` / `'Gürtel'` again.
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
- **Guest mode** (`guestMode` in SharedPreferences) stays active across app
  starts until the user signs in or logs out. Logout leads to `StartScreen`.
  On sign-in and registration only the flag is turned off; the guest's
  devices are then offered for the account (see §4). Logout ends guest mode
  with `GuestModeService.end()`, which also deletes the guest's devices.

## 3. Commands

```cmd
cd frontend/soundpilot_application
flutter pub get
flutter run
```

Debug SHA-1 for Android/Google Sign-In (Windows):

```cmd
cd frontend/soundpilot_application/android
gradlew.bat signingReport
```

**Every developer has to register their own debug SHA-1 once** in the Firebase
console (Project settings → the Android app → "Add fingerprint"), and then put
the newly downloaded `google-services.json` into `android/app/`. The debug
keystore is generated locally on every machine, so a build signed with an
unregistered one is refused by Google: the Google sign-in fails with
`ApiException: 10` (DEVELOPER_ERROR), which the app reports as "Die
Google-Anmeldung ist für diese App-Version nicht freigegeben."
(`AuthService.messageForGoogleCode`). E-mail login is unaffected, and so is
everything else in the app — only Google sign-in needs the fingerprint.

Google Sign-In **in the browser** goes through Firebase Auth
(`signInWithPopup`, see §7) and needs no SHA-1 and no Google Cloud setting.
The host the app is served from must be listed under *Authorized domains* in
the Firebase console (Authentication → Settings); `localhost` is there by
default, on any port.

`flutter run -d chrome` picks a random port unless told otherwise;
`web_dev_config.yaml` in the app folder fixes it to `http://localhost:5000`
(also with the run button in Android Studio).

`flutter run -d chrome` (also the run button) starts Chrome with a temporary
profile that is deleted after the run, so the Firebase login and the Google
session are gone on the next start and the whole Google login (including the
confirmation on the phone) is asked again. That is a debug-only effect; a
normal browser keeps the login. To keep it while developing, give Chrome a
fixed profile outside the repo, e.g. as additional run args:
`--web-browser-flag=--user-data-dir=C:\Users\<you>\.flutter-chrome-profile`.

Cloud Functions:

```cmd
cd firebase/functions
npm run lint       :: eslint (also run in CI)
npm run build      :: tsc
npm run serve      :: Build + emulator (functions only)
npm run deploy     :: firebase deploy --only functions (does NOT build first)
```

`firebase.json` also configures the Auth (9099) and Firestore (8080) emulators.
To test the auth triggers together with the rules, run
`firebase emulators:start --only functions,auth,firestore` from `firebase/`.

`firebase/functions/lib/` (the compiled JavaScript) is git-ignored. Run
`npm run build` after cloning or pulling before using the emulator or
deploying by hand; `firebase.json` has no predeploy build step.

On Windows, `npm run lint` locally reports `linebreak-style` (CRLF) errors when
git's `core.autocrlf` is on. The repo stores LF, so CI is not affected.

**Everyone uses the Flutter version CI pins (3.47.6).** `pubspec.yaml`
requires its Dart (`sdk: ^3.13.0`), so an older Flutter stops at
`flutter pub get`. A different Flutter also gives different analyzer warnings
and deprecations than CI, and can rewrite transitive versions in
`pubspec.lock` during `flutter pub get`. Do not commit such lock changes unless
you changed dependencies on purpose; discard them with
`git checkout -- pubspec.lock`. To upgrade, change the CI version, the `sdk`
constraint, the lock and this section in one PR, and the whole team upgrades
with it.

**Android build versions.** Flutter 3.47.6 refuses to build the Android app
below Gradle 8.14, Android Gradle plugin 8.11.1 and Kotlin 2.2.20
(`android/gradle/wrapper/gradle-wrapper.properties`,
`android/settings.gradle.kts`); the error names the minimum. CI does not build
the app, so it would not notice. Raise these together with Flutter. The
`android.builtInKotlin` / `android.newDsl` lines in `android/gradle.properties`
are written by Flutter's migrator on every Android build; keep them.
Flutter 3.47.6 already warns that support for these versions "will soon be
dropped" and names Gradle 9.1, AGP 9.0.1 and Kotlin 2.3.20. These are only
warnings, the build works. Moving to AGP 9 is a migration of its own (new
build DSL and built-in Kotlin, which the two flags above opt out of); do it
as a separate task, ideally with the next Flutter upgrade.

This Gradle needs Java 17–24 and fails on Java 25 ("incompatible with Gradle"),
which recent Android Studio versions bundle and Flutter uses by default. Point
Flutter to a JDK 21 once (a setting on your PC, not in the repo):
`flutter config --jdk-dir=<path to JDK 21>`.

If the first Android build fails with `PKIX path building failed` while
downloading, Java does not trust the certificate an antivirus or proxy puts in
front of HTTPS. Let Java use the Windows certificate store for that build:
`set GRADLE_OPTS=-Djavax.net.ssl.trustStoreType=Windows-ROOT` and the same for
`JAVA_TOOL_OPTIONS`. Once Gradle and the dependencies are cached, it is
usually not needed again.

On Windows, a full `flutter test` run sometimes fails to load single test files
with "Connection closed before test suite loaded". That is a crash of the local
test runner, not a failing test: rerun those files with
`flutter test --concurrency=1 <files>`.

If a build or test run behaves strangely after switching branches, Flutter
versions or native/plugin dependencies (stale errors, changes not picked up),
run `flutter clean` and then `flutter pub get`. Do not run it routinely: it
deletes `build/` and `.dart_tool/`, so the next build starts from scratch and
takes minutes.

### CI/CD (`.github/workflows/ci-cd.yml`)

Runs on every pull request to `main` and every push to `main`:

| Job | Steps | Fails on |
|---|---|---|
| `build_and_test` | `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test` (Flutter 3.47.6) | analyzer warnings/errors, failing tests |
| `functions` | `npm ci`, `npm run lint`, `npm run build` (Node.js 22) | lint errors, TypeScript errors |
| `deploy` | build functions, `firebase deploy --only firestore:rules,functions` | any deploy error |

- **Deploying is automatic.** `deploy` runs only on pushes to `main` (i.e.
  merged PRs) and only after both other jobs pass. Rules and functions do not
  need to be deployed by hand.
- A manual deploy is overwritten by the next deploy from `main`. Deploy by
  hand only for things CI does not deploy (e.g. Firestore indexes), and test
  unmerged changes with the emulators instead.
- The app itself is not built or released by CI.
- `firebase-tools` is pinned to `15.5.1` in the workflow (deploys with the unpinned
  latest version failed with "An unexpected error has occurred"; with 15.5.1
  they succeed). Change the version
  on purpose and check the first deploy after it.
- The deploy authenticates with a Google Cloud service account: its JSON key
  is the repository secret `FIREBASE_SERVICE_ACCOUNT`, and
  `google-github-actions/auth` exports it as `GOOGLE_APPLICATION_CREDENTIALS`.
  If a deploy fails with a 403 / permission error, the service account is
  missing an IAM role. (Previously: the deprecated `FIREBASE_TOKEN` from
  `firebase login:ci`.) Deploys run one after another
  (`concurrency: deploy-main`) and with `--debug`, so a failed run shows the
  cause in the Actions log.
- The deploy step makes up to 3 attempts, 30 s apart, because Google APIs
  sometimes return a temporary 503 (this failed the deploy of PR #20). A retry
  shows up as a warning in the run. A deploy that fails all 3 attempts is a
  real error (e.g. a 403), not a hiccup.

## 4. Data Model

### Current state of persistence

`DeviceScreen` reads and writes the devices through a `DeviceRepository`
(`core/services/device_repository.dart`): `watch()` delivers the whole device
list (`DeviceData`) and again after every change, and every write changes one
device (`putHeadphone`, `putBelt`, `removeHeadphone`, `removeBelt`).

- **Signed-in users: Firestore** (`FirestoreDeviceRepository`), field
  `calibration` of `users/{uid}` (schema below).
  - Reads with a snapshot listener, so a document the cloud function writes
    late is picked up (see §6, eventual consistency).
  - Writes one device per field path (`FieldPath(['calibration',
    'headphones', key])`), deletes with `FieldValue.delete()`; never the whole
    map. Writes wait until the document exists.
  - Offline: Android and iOS keep a Firestore cache on disk by default; the
    browser keeps it in memory only (its default, on purpose, see logout
    below), so offline does not survive a reload there. A write shows up at
    once but its future only completes when the server has it, so
    `DeviceScreen` does not await writes; a failed write is reported with a
    SnackBar.
  - **Logout clears the cache** (Android/iOS): `AuthService.logout()` calls
    `terminate()` + `clearPersistence()` after the sign-out, so the user's
    devices do not stay on the phone. FlutterFire creates a new instance on
    the next use. The web plugin keeps the terminated instance (every later
    call fails until a reload), which is why the browser has no disk cache.
  - Clearing also drops writes that have not reached the server. Before the
    logout, `DeviceScreen` asks `AuthService.hasUnsavedChanges()`, which waits
    up to 5 s for them; if they are still pending (offline) it shows
    `UnsyncedLogoutDialog` ("Angemeldet bleiben" / "Trotzdem abmelden").
- **Guests: only on the phone** (`LocalDeviceRepository` →
  `DeviceStorageService`), SharedPreferences key `user_calibration_guest`,
  value a JSON string `{ "headphones": {...}, "belts": {...} }` (same format
  as `calibration`). They stay across app starts while guest mode is active
  and are **only uploaded if the user agrees**:
  - After a successful sign-in or registration on a phone with guest
    devices, `runSignIn` calls `offerGuestDevices` (`GuestDevicesDialog`:
    "Geräte übernehmen" / "Geräte löschen"; back and tapping outside do
    nothing, no time limit).
  - "Übernehmen" waits for the user document and adds the devices that are
    not in the account yet (`FirestoreDeviceRepository.addMissingDevices`,
    the account wins), at most `guestUploadTimeout` (30 s), then deletes them
    on the phone. If it fails, a SnackBar says so and they stay, so the
    question comes again on the next sign-in.
  - "Löschen" deletes them on the phone.
  - Logout deletes any guest devices that are left (`GuestModeService.end()`),
    so the next guest starts with an empty list.
- **Old local devices of a user:** on the first snapshot from the server,
  `FirestoreDeviceRepository` uploads the devices stored under
  `user_calibration_<uid>` (written by app versions before the sync) that are
  not in the account yet, in one update; devices already in the account win.
  Afterwards the local key is removed. If the upload fails, it stays and is
  tried again on the next start.
- The earbud volumes are part of this map (`HeadphoneCalib.volumeLeft` /
  `volumeRight`, one pair per device). `CalibrationScreen` gets the earbud and
  saves through a callback; its wheel shows them as 1–100
  (`volumeToWheel` / `wheelToVolume` in `calibration_screen.dart`).
- The connection state is runtime only: `DeviceScreen` keeps the connected
  keys itself; nothing is stored.

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

`displayName` is `"New User"` if the auth account has no name.
There is no `username` field anywhere in the code.

`schemaVersion` identifies the schema of the document (`SCHEMA_VERSION` in
`index.ts`, `UserModel.currentSchemaVersion` in Dart). **Increase it whenever
the default document changes**, in both places. Outdated documents can then be
found with a query on `schemaVersion` (documents created before versioning have
no field, `UserModel` reads them as `0`) and migrated with a one-off admin
script, not with a deployed function. Only the cloud function writes it; the
security rules block client writes.

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

The device keys are currently placeholders (`dummy_mac_<timestamp>`) because
the Bluetooth scan in `device_screen.dart` is simulated (fixed list,
1.5 s delay).

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
7 days). Keep them idempotent. A retry of `createUserDoc` keeps existing devices
(`merge: true`) but rewrites `createdAt`.

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
- The rules were tested against the Firestore emulator (13 allow/deny cases,
  2026-09-24). Re-test after changing them. The writes of
  `FirestoreDeviceRepository` were sent to the emulator as REST field-path
  updates on 2026-10-07: put/remove of a device (also with a `AA:BB:…` key)
  and the multi-device import are allowed; `displayName`, another user's
  document and a document that does not exist yet are denied.

### Eventual consistency on registration

The auth trigger runs **asynchronously**. Right after registration, the client
may read `users/{uid}` before the function has written it. Registration flows
must therefore never be built with a one-time `get()`, but with a snapshot
listener on the document or a retry with backoff. A client-side `update()` on a
document that does not exist yet also fails.

## 7. Open Points

Not backed by evidence — check in the code instead of assuming:

- **Firestore sync: not tried on a device yet.** Tested with
  `fake_cloud_firestore` and the rules in the emulator (§4, §6), not with the
  real backend, offline, or on two phones at once.
- **Firestore cache after logout:** cleared on Android/iOS (§4). Not tried on
  a real phone yet, and `clearPersistence()` only drops the data, it does not
  overwrite it securely (FlutterFire documentation). In the browser the
  memory cache lasts until the tab is reloaded or closed.
- **Guest devices if the app is closed during the question:** if the app is
  closed while `GuestDevicesDialog` is open (or the take-over failed), the
  guest devices stay on the phone. They are offered again on the next
  sign-in, and a new guest session would show them meanwhile. Accepted on
  purpose; the take-over has not been tried on a real phone yet.
- **Real Bluetooth integration is missing.** The scan is simulated.
  `AudioDeviceService` (Android MethodChannel) exists in Dart but is not called
  by `DeviceScreen`. Whether the native Android side is implemented was not
  checked.
- **Accessibility: partly fixed, never tested on a device.** The full list of
  findings is still `docs/ACCESSIBILITY_AUDIT.md` (static code review). Done so
  far: every screen scrolls and survives text scale 2.0 (exception below);
  `Semantics` headers, labels and tooltips on all icon-only controls; 48x48 dp
  tap targets; state is no longer carried by colour alone (connection dot, type
  selector and side buttons all carry an icon too); the whole palette measured
  against WCAG AA in `test/color_contrast_test.dart`; the system back button
  works again on login/register (`PopScope(canPop: true)`, back just pops);
  the app locale is fixed to German (`core/app_locale.dart`), so Flutter's
  built-in labels are German and the app reports German to the platform
  (whether TalkBack/VoiceOver then pick a German voice is not verified).
  Still open: localisation (texts are hardcoded German; a second language
  would need `gen-l10n` with ARB files), haptics only in the calibration
  wheel, nothing verified with TalkBack or VoiceOver on real hardware. The plan
  for screen reader support (CI checks, device test protocol, open gaps) is
  `docs/SCREEN_READER_PLAN.md`.
- **The registration form scrolls; do not try to fit it on one screen again.**
  It was built without a scroll view for a while, because a form that needs no
  scrolling had been asked for. Holding that promise cost a text-scale cap
  (first 1.3x, then 1.15x), 16 px captions and 58 px fields — small print in an
  app whose whole point is impaired vision. That was the wrong trade and was
  reverted. Measured now on a 360x720 phone: caption 29 px, field 72 px, submit
  button 108 px at scale 1.0, growing to 116 / 103 / 188 px at scale 2.0, with
  no cap anywhere. Sizes are bounded from below by
  `test/accessibility_layout_test.dart`. If the form has to get shorter, remove
  a field (first name, last name and the belt question are not used yet, see
  the TODO in the file) — do not shrink the type.
- **Google sign-in takes two paths.** On Android/iOS,
  `AuthService.signInWithGoogle()` uses the `google_sign_in` plugin and builds
  a Firebase credential from its ID token. In the browser it calls
  `FirebaseAuth.signInWithPopup(GoogleAuthProvider())` instead:
  `google_sign_in_web`'s `signIn()` is deprecated, cannot reliably provide an
  ID token and needs the People API for the profile, and its replacement
  `renderButton()` cannot be styled and would not follow the app's
  accessibility rules. The popup path keeps the app's own button. Nobody has
  decided whether the browser is a target at all (`web/` is otherwise untouched
  Flutter scaffolding); the client ID meta tag in `web/index.html` is only
  needed by `google_sign_in_web`, which the web build no longer calls.
- **Password reset and Google accounts.** "Passwort vergessen?" on the login
  screen opens `PasswordResetScreen` (one field, pre-filled with the typed
  address, one button; the result stays on screen as text with an icon), which
  calls `AuthService.sendPasswordReset`; the link opens Firebase's own web
  page. According to Firebase's documentation (not tried on this project):
  a reset for an account that only uses Google adds e-mail/password to the
  same account. The other way round, a Google sign-in with the Gmail address of
  an e-mail/password account whose address is not verified replaces the
  password, and the reset is then the way back. The app never sends a
  verification e-mail; whether it should is open. Whether e-mail enumeration
  protection is on and which language the reset e-mail template uses (console:
  Authentication → Templates) has not been checked.
- **Leaving guest mode:** a guest can only leave guest mode by signing in;
  there is no button to go back to the `StartScreen`.
- **Two device-type enums:** `DeviceCategory` (`models/user_model.dart`, label
  only) and `DeviceType` (`features/device/widgets/device_type.dart`, all UI
  texts and the icon) describe the same two types. The device screens use
  `DeviceType`; merging the two is open.
- **Test strategy** is not documented. CI runs `flutter test`; tested so far
  are the models (`test/models/`), the auth error messages
  (`test/features/auth/`), `GuestModeService` (`test/core/services/`) and
  the German app locale (`test/core/app_locale_test.dart`).
  `test/accessibility_layout_test.dart` renders the screens on a 360x720 phone
  in both themes at text scale 1.0/1.6/2.0 and checks the add-device dialog
  and the password reset flow;
  `test/color_contrast_test.dart` checks the palette;
  `test/features/device/calibration_screen_test.dart` checks that the
  calibration starts at and saves the volumes of its earbud;
  `test/features/device/device_screen_test.dart` checks the `DeviceScreen`
  with a fake repository (`test/helpers/`), which the layout test uses too;
  `test/core/services/` tests both repositories (Firestore with
  `fake_cloud_firestore`);
  `test/widget_test.dart` is still a placeholder. `AuthService`,
  `AudioDeviceService` and the security rules are not tested in CI.
- **Firestore language default:** The function sets `settings.language:
  "system"`, but the app UI is German. Whether this is intended is open.

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

## 9. Claude Code

Only in `CLAUDE.md`, not copied to `docs/PROJECT_CONTEXT.md`.

### Keeping the project context safe

- `docs/PROJECT_CONTEXT.md` holds the project knowledge (§1–§8) without
  anything about Claude, so it is preserved and readable on its own if
  `CLAUDE.md` is ever deleted or replaced.
- `CLAUDE.md` contains all of it: the same §1–§8 plus this Claude-only §9.
- **Whenever §1–§8 change, apply the same change to `docs/PROJECT_CONTEXT.md`
  in the same commit.** Only the title (first line) differs. Claude-specific
  content (hooks, session start, this sync rule) goes into §9 only.
- Code comments and other docs refer to `docs/PROJECT_CONTEXT.md`, not to
  `CLAUDE.md`, so those references keep working.

### Hooks (`.claude/settings.json`)

Shared hooks enforce the rules of §8 for everyone who uses Claude Code in this
repo. They are Node scripts in `.claude/hooks/` (Node is already required for
the Cloud Functions), so they work the same on Windows, macOS and Linux.

| Hook | Script | What it does |
|---|---|---|
| `SessionStart` (startup) | `session-start.mjs` | `git fetch --prune`; on a clean `main` that is behind, `git pull --ff-only`; on any other branch, fast-forwards the local `main` without switching (`git fetch origin main:main`, never touches the current branch); reports uncommitted changes, stale/merged local branches and open PRs |
| `PreToolUse` (shell, file edits) | `pre-tool-guard.mjs` | **blocks** `--no-verify`, deleting `main` on GitHub, and edits to credentials (`google-services.json`, `GoogleService-Info.plist`, `.env*`, service-account JSON, keystores) and the generated `firebase_options.dart`; **asks first** for commits/pushes to `main`, force pushes, `firebase deploy`, and commands that throw away work (`reset --hard`, `clean -f`, `checkout -- .`, `restore .`, `branch -D`, `stash drop/clear`, `rm -rf`) |
| `PostToolUse` (file edits) | `post-edit-reminders.mjs` | reminds to mirror §1–§8 of `CLAUDE.md` ↔ `docs/PROJECT_CONTEXT.md`, and to update all three schema places when `firestore.rules`, `index.ts` or `user_model.dart` change |

- The guards check the command text; they are a safety net against mistakes,
  not a security boundary.
- An "ask" action that is really intended (e.g. a force push to your own
  branch) is confirmed in the permission prompt. To change a rule, edit the
  script through a PR like any other code.
- Review or temporarily disable hooks with `/hooks` in Claude Code.
- **When a hook blocks or questions a command, never work around it** (other
  wording, a script, another tool). Tell the user what was blocked and why. If
  it is a false positive (e.g. a trigger word inside a commit message or
  heredoc), say so and suggest fixing the rule in the script.

### Session start

The `SessionStart` hook (see Hooks above) already runs the fetch/pull and
collects the state below; its report is in the context at the start of a
session. Report it to the user, and still check the points it does not cover
(leftover remote branches of merged PRs).

Before starting any task, check the state of the repo and report it:

- **Pull:** `git fetch --prune`, then check whether `main` (or the current
  branch) is behind `origin`; if so, pull before working.
- **Clean up:**
  - uncommitted changes (`git status`)
  - local branches that are merged or whose remote branch is gone
  - leftover remote branches of merged PRs
  - open PRs that still wait for a merge

Ask before deleting anything or discarding changes.

### Before pushing / opening a PR

- Run the checks CI runs, for the parts you changed (see §3):
  `flutter analyze --no-fatal-infos` and `flutter test` in
  `frontend/soundpilot_application/`; `npm run lint` and `npm run build` in
  `firebase/functions/`. Report failures with their output; do not push
  known-red code.
- Leave unrelated local changes out of the commit (e.g. a `pubspec.lock` that
  only a local `flutter pub get` changed, see §3). Stage files by name, not
  with `git add -A`.
- If §1–§8 of this file changed, `docs/PROJECT_CONTEXT.md` changes in the same
  commit (see "Keeping the project context safe").
- PR description: what changed and why, how it was tested (commands and
  results), and anything the reviewer has to decide. Do not merge the PR
  yourself; the user merges (admins via the ruleset bypass, see §8).

### Merge conflicts in a PR

- Merge `main` into the PR branch (`git merge main`); do not rebase, because
  that needs a force push and rewrites commits teammates may have pulled.
- Understand both sides first (`git diff <merge-base> main -- <file>` and the
  same for the branch). Often one side restructured a file and the other
  changed its logic; keep the restructured version and re-apply the logic
  change on top, rather than picking one side.
- After resolving: `flutter analyze` and `flutter test` (plus the functions
  checks if `firebase/` is involved), and search for leftover `<<<<<<<` markers.
- Ask before pushing to a branch another person owns, and name the decisions
  you made (e.g. something left duplicated on purpose).

### After a PR is merged

When the user says a PR was merged:

1. `git checkout main` and `git pull --prune`. If local changes block the
   checkout, find out where they come from before discarding anything.
2. Check CI for the merge commit (`gh run list --branch main --limit 1`). It
   includes the automatic deploy of rules and functions; report a failure
   with a link to the run. A run can take a moment to appear.
3. Delete the merged local branch (`git branch -d`, which refuses unmerged
   work) after asking, and check for other merged or orphaned branches and
   open PRs, as at session start.
