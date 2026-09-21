# CLAUDE.md — SoundPilot

Projektkontext für Claude Code. Diplomprojekt (HTL).

> Regel für dieses Dokument: Hier steht nur, was aus dem Code bzw. der
> Architekturdoku belegt ist. Unklares steht unter „Offene Punkte" und ist als
> offen markiert — nicht als Fakt behandeln, sondern im Code nachsehen oder
> nachfragen.
>
> Stand: abgeglichen mit `firebase/firestore.rules`,
> `firebase/functions/src/index.ts` und `frontend/soundpilot_application/lib/`.

## 1. Überblick

- **App:** SoundPilot
- **Client:** Flutter / Dart
- **Backend:** Firebase — Authentication, Cloud Firestore, Cloud Functions
- **Zweck:** Benutzerauthentifizierung und Verwaltung von Kalibrierungsdaten für
  zwei Hardwaretypen: Kopfhörer (`HeadphoneCalib`) und Gürtel (`BeltCalib`)

### Pakete (`pubspec.yaml`)

| Paket | Zweck |
|---|---|
| `firebase_core` | Initialisierung |
| `firebase_auth` | Authentifizierung (E-Mail/Passwort, Google Sign-In) |
| `google_sign_in` | Google-Login |
| `cloud_firestore` | eingebunden, im Dart-Code aber **noch nicht verwendet** (siehe §4) |
| `shared_preferences` | aktuelle lokale Persistenz (Geräte, Kalibrierung, Gast-Flag) |
| `google_fonts` | Schriftart Poppins |
| `audioplayers` | Audiowiedergabe (Kalibrierung) |
| `logger` | globaler `logger` in `core/app_logger.dart` |

`firebase_database` ist **nicht** eingebunden.

Cloud Functions sind in **TypeScript (Node.js 22)** geschrieben.

## 2. Verzeichnisse

```
frontend/soundpilot_application/   Flutter-App
firebase/                          Firestore Rules, Cloud Functions
  firestore.rules
  functions/src/index.ts
```

Alle Flutter-Befehle werden aus `frontend/soundpilot_application/` ausgeführt,
alle Functions-Befehle aus `firebase/functions/`.

### Aufbau von `lib/`

```
main.dart                        Einstieg, Theme, Startrouting (AppEntryPoint)
firebase_options.dart            generiert
models/user_model.dart           HeadphoneCalib, BeltCalib, UserModel
core/
  app_logger.dart
  theme/app_colors.dart          Farben kontextabhängig (Light/Dark)
  widgets/                       LoadingScreen, SoundPilotLogo
  services/
    device_storage_service.dart  lokale Persistenz Geräte + Kalibrierung
    calibration_service.dart     Lautstärke L/R als int (0–100)
    audio_device_service.dart    MethodChannel com.soundpilot/audio_devices
features/
  auth/auth_service.dart
  auth/screens/                  start, login, register
  device/screens/                device_screen, calibration,
                                 belt_vibration_screen,
                                 belt_warning_distance_screen, TestPage
```

- **State-Management:** kein Paket, nur `StatefulWidget` + `setState`.
- **Routing:** `Navigator.push` mit `MaterialPageRoute`, kein Router-Paket.
- **Start:** `AppEntryPoint` öffnet `DeviceScreen`, wenn ein Firebase-User
  angemeldet ist oder das einmalige Flag `continueAsGuestThisSession` gesetzt
  ist (wird beim Start sofort zurückgesetzt). Sonst `StartScreen`.

## 3. Befehle

```cmd
cd frontend/soundpilot_application
flutter pub get
flutter run
```

Debug-SHA-1 für Android/Google Sign-In (Windows):

```cmd
cd frontend/soundpilot_application/android
gradlew.bat signingReport
```

Cloud Functions:

```cmd
cd firebase/functions
npm run build      :: tsc
npm run serve      :: Build + Emulator (nur functions)
npm run deploy     :: firebase deploy --only functions
```

## 4. Datenmodell

### Aktueller Stand der Persistenz

Die App speichert Geräte und Kalibrierung **derzeit nur lokal** in
SharedPreferences (`DeviceStorageService`):

- Schlüssel `user_calibration_<uid>`, für Gäste `user_calibration_guest`
- Wert: ein JSON-String `{ "headphones": {...}, "belts": {...} }`
- Nach Login/Registrierung kopiert `migrateGuestDataAfterLogin()` die
  Gastdaten in den User-Schlüssel — nur, wenn der User dort noch keine Daten hat.
  Die Gastdaten werden nicht gelöscht.
- Es gibt **keine Synchronisation mit Firestore**.
  `CalibrationService.migrateLocalToFirestoreIfNeeded()` ist ein leerer Stub.

Das Firestore-Schema unten ist das Zielschema, das die Cloud Function bereits
anlegt und das die Dart-Modelle abbilden.

### Firestore: Collection `users`

Dokument-ID = Firebase-Auth-UID (`user.uid`). So legt es `createUserDoc` an:

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

`displayName` ist `"New User"`, wenn der Auth-Account keinen Namen hat.
Ein Feld `username` gibt es nirgends im Code.

### Zentrale Entwurfsentscheidung: Maps statt Arrays

Geräte werden als **Map** abgelegt, Schlüssel ist die Bluetooth-Hardware-Adresse
(`BD_ADDR`) — **nicht** als Array. Begründung: O(1)-Zugriff, atomare Updates
einzelner Geräte, keine Duplikate.

**Konsequenz für neuen Code:** Ein einzelnes Gerät wird über einen Feldpfad
aktualisiert, nie durch Neuschreiben der gesamten Map:

```dart
await FirebaseFirestore.instance.collection('users').doc(uid).update({
  'calibration.headphones.$bdAddr.volLeft': 0.7,
});
```

Kein Read-Modify-Write der kompletten `calibration`-Map — das erzeugt Race
Conditions zwischen mehreren Geräten.

Die Geräteschlüssel sind derzeit Platzhalter (`dummy_mac_<timestamp>`), weil
der Bluetooth-Scan in `device_screen.dart` simuliert ist (feste Liste,
1,5 s Verzögerung).

### Dart-Modelle (`models/user_model.dart`)

- `HeadphoneCalib` — `modelId`, `volumeLeft`, `volumeRight` (Defaults `0.5`)
- `BeltCalib` — `modelId`
- `UserModel` — `id`, `displayName`, `email`,
  `Map<String, HeadphoneCalib> headphones`, `Map<String, BeltCalib> belts`

`isConnected` (beide Calib-Klassen) und `category` sind reine Laufzeitfelder und
werden von `toMap()` nicht geschrieben. `isConnected` ist nach jedem Laden
`false`.

Namenskonvention beachten: in Dart `volumeLeft`/`volumeRight`, in Firestore
`volLeft`/`volRight`. Die Umsetzung passiert ausschließlich in `fromMap()` /
`toMap()`. Diese Trennung beim Erweitern der Modelle beibehalten.

Alle `fromMap`-Factories arbeiten defensiv mit Fallbacks (`?? 'unknown'`,
`?? 0.5`), weil Firestore-Dokumente Felder fehlen können. Neue Felder in diesem
Stil ergänzen.

## 5. Cloud Functions

Datei: `firebase/functions/src/index.ts`. Beide Functions laufen in der Region
`europe-central2` und sind Auth-Trigger in 1st Gen:

- **`createUserDoc`** (`onCreate`) legt das Standard-Benutzerdokument an (Schema
  siehe §4). Geschrieben wird mit `set(..., { merge: true })`.
- **`deleteUserDoc`** (`onDelete`) löscht `users/{uid}`, wenn der Auth-Account
  gelöscht wird.

Fehler werden in beiden Functions nur geloggt, nicht erneut geworfen.

### Cloud Functions 1st Gen — bewusste Entscheidung

Der Trigger nutzt 1st Gen. Grund: Firebase bietet in 2nd Gen **keinen
asynchronen** `onCreate`-Trigger für Auth-Ereignisse. Das dortige Äquivalent
sind **Blocking Functions** (`beforeUserCreated`), die ein projektweites Upgrade
auf *Firebase Authentication with Identity Platform* voraussetzen und synchron
in den Registrierungsvorgang eingreifen — ein Fehler würde die Registrierung
abbrechen. 1st Gen wird von Firebase weiterhin unterstützt.

**Nicht ohne Rücksprache auf 2nd Gen migrieren.**

### Import-Regel

Ab firebase-functions SDK **v6** ist v2 der Default-Export. v1-APIs müssen
explizit importiert werden. Installiert ist `firebase-functions` `^6.0.1`, im
Code steht:

```typescript
import * as functions from "firebase-functions/v1";

export const createUserDoc = functions
  .region("europe-central2")
  .auth.user()
  .onCreate(async (user) => { ... });
```

Vor dem Bearbeiten der Functions die SDK-Version in `package.json` prüfen und den
Import entsprechend wählen.

## 6. Security Rules (`firebase/firestore.rules`)

```javascript
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
match /{document=**} {
  allow read, write: if false;
}
```

Daraus folgt für Client-Code:

- Ein angemeldeter User darf sein eigenes Dokument und alle Subcollections
  **lesen, anlegen, ändern und löschen** (`write` umfasst `create`, `update`,
  `delete`).
- Fremde Benutzerdokumente und alle anderen Pfade sind gesperrt. Keine Queries
  über die gesamte `users`-Collection bauen.
- Das Anlegen des Dokuments ist zwar erlaubt, gehört aber nach dem Entwurf der
  Cloud Function. Der Client soll `update()` verwenden, nicht `set()`.

### Eventual Consistency beim Registrieren

Der Auth-Trigger läuft **asynchron**. Direkt nach der Registrierung kann der
Client `users/{uid}` lesen, bevor die Function geschrieben hat. Registrierungs-
Flows deshalb nie mit einem einmaligen `get()` bauen, sondern mit einem
Snapshot-Listener auf das Dokument oder einem Retry mit Backoff. Ein
clientseitiges `update()` auf ein noch nicht existierendes Dokument schlägt
ebenfalls fehl.

## 7. Offene Punkte

Nicht belegt — bitte im Code prüfen, statt anzunehmen:

- **Rules validieren keine Felder.** Ein Client kann `email`, `createdAt`,
  `providers` oder `uid` im eigenen Dokument überschreiben und das Dokument
  auch löschen. Ob das beabsichtigt ist, ist nicht dokumentiert.
- **Firestore-Anbindung fehlt im Client.** Geräte und Kalibrierung liegen nur
  lokal (siehe §4). Ob und wann auf Firestore umgestellt wird, ist offen.
- **Zwei parallele Kalibrierungsspeicher:** `CalibrationService` (int 0–100,
  eigene SharedPreferences-Schlüssel) und `HeadphoneCalib` (double 0.0–1.0 über
  `DeviceStorageService`). Welcher wo tatsächlich genutzt wird, ist nicht
  geklärt (`calibration.dart` wurde nicht geprüft).
- **Echte Bluetooth-Anbindung fehlt.** Der Scan ist simuliert.
  `AudioDeviceService` (Android-MethodChannel) existiert in Dart, wird aber von
  `DeviceScreen` nicht aufgerufen. Ob die native Android-Seite implementiert
  ist, wurde nicht geprüft.
- **`DeviceScreen._logout()`** ruft `FirebaseAuth.signOut()` direkt auf und
  umgeht damit `AuthService.logout()` (kein Google-Sign-Out, kein Zurücksetzen
  des Gast-Flags).
- **`AuthService`** gibt bei jedem Fehler `null` zurück; die UI kann den Grund
  nicht unterscheiden.
- **Teststrategie** ist nicht festgehalten.
- **Firestore-Sprachdefault:** Die Function setzt `settings.language: "system"`,
  die App-UI ist aber deutsch. Ob das so gewollt ist, ist offen.

## 8. Arbeitsweise in diesem Repo

- Deutsch ist die Standardsprache im Projekt; UI-Texte entsprechend.
- Keine Firebase-Konfigurationsdateien, API-Keys oder `google-services.json` in
  Antworten oder Commits ausgeben.
- Bei Änderungen am Firestore-Schema immer alle drei Stellen mitziehen:
  Cloud Function (Defaults), Dart-Modell (`fromMap`/`toMap`) und
  Security Rules.

### Kommentar-Konvention

- **Sprache:** Code-Kommentare auf Englisch. UI-Texte sind deutsch; die
  Logmeldungen in `CalibrationService` sind noch deutsch.
- **Dateikopf:** erste Zeile `// lib/<pfad>`, danach ein bis zwei Zeilen zum
  Zweck der Datei.
- **Doc-Kommentare (`///`)** für Klassen, Felder mit nicht offensichtlicher
  Bedeutung und Methoden mit Logik. Einfaches `//` nur innerhalb von Methoden.
  Triviale Overrides (`build`, `dispose`, `createState`) brauchen keinen.
- **Abschnitte:** `// ── Titel ───…` auf 80 Zeichen Breite.
- **Markierungen:**
  - `NOTE:` erklärt Verhalten, das nicht offensichtlich ist.
  - `TODO(improve):` Verbesserungsvorschlag aus dem Code-Review (Bugs,
    Duplikate, veraltete APIs, fehlende Anbindungen).
  - `TODO:` ursprüngliche offene Aufgaben des Teams.
- **Nichts löschen:** Vorhandene Kommentare bleiben erhalten. Ist einer
  veraltet oder falsch, korrigieren und die ursprüngliche Aussage im Kommentar
  festhalten (Beispiel: `AuthService.loginWithEmail`).
- Alle Verbesserungsvorschläge finden:
  `grep -rn "TODO(improve)" frontend firebase/firestore.rules firebase/functions/src`
