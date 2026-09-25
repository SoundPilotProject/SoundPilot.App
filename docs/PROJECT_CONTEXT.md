# SoundPilot — Project Context

Project context for Claude Code. Diploma project (HTL).

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
- **Text scaling:** layouts must not break or clip with large system font
  sizes; no fixed heights for text containers.
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
  functions/lib/                   tsc output, git-ignored (see §3)
.github/workflows/ci-cd.yml        CI/CD pipeline (see §3)
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

### CI/CD (`.github/workflows/ci-cd.yml`)

Runs on every pull request to `main` and every push to `main`:

| Job | Steps | Fails on |
|---|---|---|
| `build_and_test` | `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test` (Flutter 3.35.4) | analyzer warnings/errors, failing tests |
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
  2026-09-24). Re-test after changing them.

### Eventual consistency on registration

The auth trigger runs **asynchronously**. Right after registration, the client
may read `users/{uid}` before the function has written it. Registration flows
must therefore never be built with a one-time `get()`, but with a snapshot
listener on the document or a retry with backoff. A client-side `update()` on a
document that does not exist yet also fails.

## 7. Open Points

Not backed by evidence — check in the code instead of assuming:

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
- **Test strategy** is not documented. CI runs `flutter test`; so far only the
  models are tested (`test/models/user_model_test.dart`), and
  `test/widget_test.dart` is a placeholder. Services, screens and the security
  rules are not tested in CI.
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
- Small documentation-only edits may go to `main` only if the team agreed to
  that for the change.

### Keeping the project context safe

- `docs/PROJECT_CONTEXT.md` contains the same content as this file
  (`CLAUDE.md`), so the project knowledge is preserved if `CLAUDE.md` is ever
  deleted or replaced.
- **Whenever `CLAUDE.md` changes, update `docs/PROJECT_CONTEXT.md` in the same
  commit.** It is a full copy; only its title (first line) differs.
- Code comments and other docs refer to `docs/PROJECT_CONTEXT.md`, not to
  `CLAUDE.md`, so those references keep working.

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
- **Keep existing comments:** The team's comments stay and are not rewritten
  more than needed. If one is outdated or wrong, correct it with a minimal
  change and preserve the original statement (example:
  `AuthService.loginWithEmail`).
- **Resolved TODOs are deleted.** When a `TODO` / `TODO(improve)` is fixed,
  remove it; do not turn it into a history note ("Originally a TODO …
  Fixed"). Add a short `NOTE:` only if the new code needs an explanation.
- Find all improvement suggestions:
  `grep -rn "TODO(improve)" frontend firebase/firestore.rules firebase/functions/src`
