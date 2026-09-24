# CLAUDE.md — SoundPilot

Project context for Claude Code. Diploma project (HTL).

> Rule for this document: it contains only what is backed by the code or the
> architecture docs. Unclear points are listed under "Open Points" and are
> marked as open — do not treat them as fact; check the code or ask.
>
> Status: reconciled with `firebase/firestore.rules`,
> `firebase/functions/src/index.ts` and `frontend/soundpilot_application/lib/`.

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
- **Text scaling:** layouts must not break or clip with large system font
  sizes; no fixed heights for text containers.
- **Not color alone:** never convey state (e.g. connected, error) by color only;
  add text or an icon.
- **Multiple channels:** important feedback (e.g. belt warning distance,
  calibration) should be available via more than one sense — visual, audio and
  haptic/vibration — where the hardware allows it.
- **Simple flows:** short, clear German texts, one main action per screen,
  clear error messages (see the `AuthService` open point in §7), no
  time-limited interactions.
- **Motion:** respect the system setting for reduced animations.

When in doubt, choose the more accessible option and mention the trade-off.

### Packages (`pubspec.yaml`)

| Package | Purpose |
|---|---|
| `firebase_core` | Initialization |
| `firebase_auth` | Authentication (email/password, Google Sign-In) |
| `google_sign_in` | Google login |
| `cloud_firestore` | included, but **not yet used** in the Dart code (see §4) |
| `shared_preferences` | current local persistence (devices, calibration, guest flag) |
| `google_fonts` | Poppins font |
| `audioplayers` | Audio playback (calibration) |
| `logger` | global `logger` in `core/app_logger.dart` |

`firebase_database` is **not** included.

Cloud Functions are written in **TypeScript (Node.js 22)**.

## 2. Directories

```
frontend/soundpilot_application/   Flutter app
firebase/                          Firestore rules, Cloud Functions
  firestore.rules
  functions/src/index.ts
```

All Flutter commands are run from `frontend/soundpilot_application/`,
all Functions commands from `firebase/functions/`.

### Structure of `lib/`

```
main.dart                        Entry point, theme, start routing (AppEntryPoint)
firebase_options.dart            generated
models/user_model.dart           HeadphoneCalib, BeltCalib, UserModel
core/
  app_logger.dart
  theme/app_colors.dart          Colors depending on context (light/dark)
  widgets/                       LoadingScreen, SoundPilotLogo
  services/
    device_storage_service.dart  local persistence of devices + calibration
    calibration_service.dart     Volume L/R as int (0–100)
    audio_device_service.dart    MethodChannel com.soundpilot/audio_devices
features/
  auth/auth_service.dart
  auth/screens/                  start, login, register
  device/screens/                device_screen, calibration,
                                 belt_vibration_screen,
                                 belt_warning_distance_screen, TestPage
```

- **State management:** no package, only `StatefulWidget` + `setState`.
- **Routing:** `Navigator.push` with `MaterialPageRoute`, no router package.
- **Start:** `AppEntryPoint` opens `DeviceScreen` if a Firebase user is signed
  in or the one-time flag `continueAsGuestThisSession` is set (it is reset
  immediately at startup). Otherwise `StartScreen`.

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

Cloud Functions:

```cmd
cd firebase/functions
npm run build      :: tsc
npm run serve      :: Build + emulator (functions only)
npm run deploy     :: firebase deploy --only functions
```

## 4. Data Model

### Current state of persistence

The app currently stores devices and calibration **only locally** in
SharedPreferences (`DeviceStorageService`):

- Key `user_calibration_<uid>`, for guests `user_calibration_guest`
- Value: a JSON string `{ "headphones": {...}, "belts": {...} }`
- After login/registration, `migrateGuestDataAfterLogin()` copies the guest
  data to the user key — only if the user has no data there yet.
  The guest data is not deleted.
- There is **no synchronization with Firestore**.
  `CalibrationService.migrateLocalToFirestoreIfNeeded()` is an empty stub.

The Firestore schema below is the target schema that the Cloud Function already
creates and that the Dart models map.

### Firestore: collection `users`

Document ID = Firebase Auth UID (`user.uid`). This is how `createUserDoc`
creates it:

```json
{
  "uid": "string",
  "email": "string | null",
  "displayName": "string",
  "createdAt": "Timestamp",
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

Mind the naming convention: in Dart `volumeLeft`/`volumeRight`, in Firestore
`volLeft`/`volRight`. The mapping happens exclusively in `fromMap()` /
`toMap()`. Keep this separation when extending the models.

All `fromMap` factories work defensively with fallbacks (`?? 'unknown'`,
`?? 0.5`), because Firestore documents can be missing fields. Add new fields in
the same style.

## 5. Cloud Functions

File: `firebase/functions/src/index.ts`. Both functions run in the region
`europe-central2` and are auth triggers in 1st Gen:

- **`createUserDoc`** (`onCreate`) creates the default user document (schema
  see §4). It writes with `set(..., { merge: true })`.
- **`deleteUserDoc`** (`onDelete`) deletes `users/{uid}` when the auth account
  is deleted.

Errors in both functions are only logged, not rethrown.

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
  .auth.user()
  .onCreate(async (user) => { ... });
```

Before editing the functions, check the SDK version in `package.json` and
choose the import accordingly.

## 6. Security Rules (`firebase/firestore.rules`)

```javascript
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
match /{document=**} {
  allow read, write: if false;
}
```

For client code this means:

- A signed-in user may **read, create, update and delete** their own document
  and all subcollections (`write` covers `create`, `update`, `delete`).
- Other users' documents and all other paths are blocked. Do not build queries
  over the whole `users` collection.
- Creating the document is allowed, but by design belongs to the Cloud
  Function. The client should use `update()`, not `set()`.

### Eventual consistency on registration

The auth trigger runs **asynchronously**. Right after registration, the client
may read `users/{uid}` before the function has written it. Registration flows
must therefore never be built with a one-time `get()`, but with a snapshot
listener on the document or a retry with backoff. A client-side `update()` on a
document that does not exist yet also fails.

## 7. Open Points

Not backed by evidence — check in the code instead of assuming:

- **Rules do not validate fields.** A client can overwrite `email`,
  `createdAt`, `providers` or `uid` in their own document and can also delete
  the document. Whether this is intended is not documented.
- **Firestore integration is missing in the client.** Devices and calibration
  are stored only locally (see §4). Whether and when to switch to Firestore is
  open.
- **Two parallel calibration stores:** `CalibrationService` (int 0–100, own
  SharedPreferences keys) and `HeadphoneCalib` (double 0.0–1.0 via
  `DeviceStorageService`). Which one is actually used where has not been
  clarified (`calibration.dart` was not checked).
- **Real Bluetooth integration is missing.** The scan is simulated.
  `AudioDeviceService` (Android MethodChannel) exists in Dart but is not called
  by `DeviceScreen`. Whether the native Android side is implemented was not
  checked.
- **`DeviceScreen._logout()`** calls `FirebaseAuth.signOut()` directly and thus
  bypasses `AuthService.logout()` (no Google sign-out, no reset of the guest
  flag).
- **`AuthService`** returns `null` on any error; the UI cannot distinguish the
  reason.
- **Accessibility gaps** (full list: `docs/ACCESSIBILITY_AUDIT.md`;
  static code review, not tested on a device, nothing fixed yet): the
  screens do not yet meet the guidelines in §1. There is no `Semantics`,
  `semanticLabel` or `tooltip` anywhere in `lib/`, no `MediaQuery`/text-scale
  handling, no haptics, no app locale. Login, register, start, calibration and
  test screens are not scrollable and overflow with large text or the keyboard.
  Connection state (red/green dot), selected state (type selector, L/M/R) is
  color only. `AppColors.mutedText` in light mode has about 3.6:1 contrast on
  the background. Small tap targets: the delete "X" on device cards and the
  plain-text links (`GestureDetector` + `Text`). The system back button is
  disabled on login/register (`PopScope(canPop: false)`).
- **Test strategy** is not documented.
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

### Comment convention

- **Language:** Code comments in English. UI texts are German; the log messages
  in `CalibrationService` are still German.
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
- **Delete nothing:** Existing comments stay. If one is outdated or wrong,
  correct it and preserve the original statement in the comment (example:
  `AuthService.loginWithEmail`).
- Find all improvement suggestions:
  `grep -rn "TODO(improve)" frontend firebase/firestore.rules firebase/functions/src`
