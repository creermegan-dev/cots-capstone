# COTS Monitor — Multi-Workstation Firebase Collaboration Guide

This guide is for teams working on the **same Git repository** from multiple machines (Windows, Android, Web) without breaking Firebase auth, configs, or each other's test data.

**Canonical Firebase project:** [`cots-monitor`](https://console.firebase.google.com/project/cots-monitor)

For first-time Firebase setup, security rules, data models, and troubleshooting, see **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)**.

---

## Quick reference

| Topic | What the repo does |
|--------|----------------------|
| Project ID | `cots-monitor` (`.firebaserc`, `google-services.json`, Android/Web/Windows) |
| Android package | `com.example.cots_monitor` |
| Shared debug keystore | `android/app/debug.keystore` (committed) |
| Config files | `lib/firebase_options.dart`, `android/app/google-services.json` are **committed** so clones work out of the box |
| Windows auth | REST API (`WindowsAuthRestService`), not native `firebase_auth` plugins |
| Admin access | Set `accountRole: "admin"` in Firestore `users/{uid}` (not via app signup) |

---

## 1. Shared Android debug keystore

### Why it matters

By default, each PC generates its own `~/.android/debug.keystore`, so **SHA-1 / SHA-256 fingerprints differ per developer**. Features that depend on app signing (Google Sign-In, some Firebase Android checks) can work on one machine and fail on another.

### What we did (already in the repo)

A team-wide `debug.keystore` lives at `android/app/debug.keystore`, and `android/app/build.gradle.kts` forces debug builds to use it:

```kotlin
signingConfigs {
    getByName("debug") {
        storeFile = file("debug.keystore")
        storePassword = "android"
        keyAlias = "androiddebugkey"
        keyPassword = "android"
    }
}
```

### One-time Firebase Console step (project admin)

Register these fingerprints on the **Android** app (`com.example.cots_monitor`) under **Project settings → Your apps → Android → Add fingerprint**:

| Type | Fingerprint |
|------|-------------|
| SHA-1 | `E3:87:7B:E4:F3:F2:6A:DE:8F:AB:29:C0:51:D2:B7:20:BB:4D:27:28` |
| SHA-256 | `10:3C:80:F0:28:98:69:AD:29:0F:88:97:25:D7:4C:7C:44:ED:CB:13:1C:91:AA:CF:E8:6A:68:A8:71:B1:D4:A4` |

To verify locally:

```bash
cd android/app
keytool -list -v -keystore debug.keystore -storepass android -alias androiddebugkey
```

> **Note:** This app uses **Email/Password** sign-in. SHA fingerprints are still worth registering for Android Firebase features you may add later.

---

## 2. New workstation setup

When someone clones the repo on a new PC or laptop:

### Step 1 — Prerequisites

1. **Flutter** and **Dart** on `PATH`
2. **Node.js** (for Firebase CLI)
3. **Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```
4. **FlutterFire CLI:**
   ```bash
   dart pub global activate flutterfire_cli
   ```

### Step 2 — Firebase login

Use a Google account that has access to **`cots-monitor`**:

```bash
firebase login
```

Invite teammates under **Firebase Console → Project settings → Users and permissions** (Editor or Developer is enough).

### Step 3 — Confirm or refresh configs

After `git clone`, checked-in configs should already point at `cots-monitor`. Open `lib/firebase_options.dart` and confirm `projectId: 'cots-monitor'` for **android**, **web**, and **windows**.

If configs are missing, stale, or wrong, regenerate from the repo root:

```powershell
# Interactive — pick cots-monitor from the list
powershell -ExecutionPolicy Bypass -File scripts/connect_firebase.ps1

# Non-interactive — team default
powershell -ExecutionPolicy Bypass -File scripts/connect_firebase.ps1 -ProjectId cots-monitor
```

The script configures **web, Android, and Windows** and updates `lib/firebase_options.dart` plus `android/app/google-services.json`.

### Step 4 — Deploy rules (once per machine or after rule changes)

```bash
firebase deploy --only firestore:rules,storage
```

### Step 5 — Run the app

```bash
flutter pub get
flutter run -d windows    # or chrome, android, etc.
```

See **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)** for Email/Password enablement, admin accounts, and troubleshooting.

---

## 3. Windows desktop (team note)

Windows builds **do not** use native `firebase_auth` / `cloud_firestore` plugins at startup (avoids a known Windows engine crash). Instead:

- Login/signup use **Firebase Auth REST** (`lib/services/windows_auth_rest_service.dart`)
- Profiles are read/written via **Firestore REST** using the same `cots-monitor` project
- `lib/firebase_options.dart` → `DefaultFirebaseOptions.windows` must stay on **`cots-monitor`**

Implications for the team:

- Enable **Email/Password** in Firebase Console (required on every platform, including Windows).
- After `connect_firebase.ps1`, confirm the **windows** block in `firebase_options.dart` matches **android/web**.
- Scan submission on Windows currently expects native `FirebaseAuth.instance.currentUser`; prefer **Android or Web** for full scan→Firestore flows until that path is unified.

---

## 4. Committed config policy

This repo **commits** Firebase config so every clone targets the same backend:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `.firebaserc`

**Do**

- Commit intentional changes after `flutterfire configure` when the whole team migrates projects.
- Commit rule changes under `firebase/firestore.rules` and `firebase/storage.rules`.
- Use pull requests so everyone stays on the same `projectId`.

**Don't**

- Run `connect_firebase.ps1` against a personal Firebase project and commit without team agreement.
- Point half the team at `cots-monitor` and half at another project ID (e.g. legacy `cots-capstone-project`).

**iOS caveat:** If `firebase_options.dart` still shows `cots-capstone-project` for iOS, re-run FlutterFire for iOS against `cots-monitor` or avoid iOS builds until aligned:

```bash
flutterfire configure --project=cots-monitor --platforms=ios --ios-bundle-id=com.example.cots_monitor
```

---

## 5. Roles: admin vs field user

There is **one login screen** for everyone. Routing after sign-in is driven by Firestore, not separate credentials:

| `users/{uid}.accountRole` | App destination |
|---------------------------|-----------------|
| `"admin"` | Admin shell (`AdminShellScreen`) |
| `"user"` (default on signup) | Field user dashboard (`DashboardScreen`) |

To create an admin: Firebase Console → Firestore → `users` → document for that user's UID → set `accountRole` to `admin`. Signup in the app always creates `accountRole: "user"` (enforced by security rules).

---

## 6. Local isolation — Firebase Emulator Suite (optional)

Use emulators when several developers need to test auth/Firestore/Storage **without** overwriting shared cloud data.

### Initial setup (once per repo)

1. Install a **JRE** (Java).
2. From the repo root:
   ```bash
   firebase init emulators
   ```
   Select **Auth**, **Firestore**, and **Storage**. Accept default ports unless your team standardizes others.
3. (Optional) Create shared seed data:
   ```bash
   mkdir firebase/mock_data
   ```

### Start emulators

```bash
# Empty emulators
firebase emulators:start

# With team seed data (after someone exports mock_data)
firebase emulators:start --import=./firebase/mock_data
```

Emulator UI: `http://localhost:4000/`

### Point the Flutter app at emulators (not wired by default)

On **Android emulator**, the host for your PC's localhost is `10.0.2.2`. On **Windows/Web/desktop**, use `localhost`.

Planned change in `lib/core/firebase_bootstrap.dart` inside `ensureFirebaseInitialized()` after `Firebase.initializeApp`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

// After Firebase.initializeApp(...):
if (kDebugMode) {
  // Android emulator → 10.0.2.2; Windows/Web/iOS simulator → localhost
  const host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: 'localhost',
  );
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  debugPrint('Firebase emulators: $host');
}
```

Run with a custom host for Android emulator:

```bash
flutter run -d android --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

**Windows REST auth** does not automatically use emulators; Windows developers should use emulators via Android/Web targets, or add REST emulator host configuration later.

### Share emulator seed data

```bash
# Export after building test users/zones locally
firebase emulators:export ./firebase/mock_data

# Commit firebase/mock_data only if the team agrees (no real user passwords)
```

---

## 7. Collaboration best practices

1. **Single project ID** — Treat `cots-monitor` as production/staging for the capstone unless you create a separate `cots-monitor-dev` project.
2. **Rules in Git** — Change `firebase/firestore.rules` / `firebase/storage.rules` in the repo, then deploy:
   ```bash
   firebase deploy --only firestore:rules,storage
   ```
3. **Avoid clobbering cloud data** — Use emulators or clearly named test accounts; don't delete shared `users` docs without coordinating.
4. **Windows build locks** — If `flutter clean` fails on `.plugin_symlinks`, see `scripts/windows_deep_clean_flutter.ps1` and keep the repo outside OneDrive-synced folders when possible.
5. **Admin UI data** — Admin dashboards are still largely **mock UI**; live monitoring data in Firestore is written mainly via user scan submission (`scan_records`). See FIREBASE_SETUP.md for collections.

---

## 8. Checklist: “Am I on the right Firebase?”

- [ ] `lib/firebase_options.dart` → android / web / windows `projectId` is `cots-monitor`
- [ ] `android/app/google-services.json` → `"project_id": "cots-monitor"`
- [ ] `.firebaserc` → `"default": "cots-monitor"`
- [ ] `firebase login` uses an account with access to that project
- [ ] Authentication → Email/Password is **enabled**
- [ ] Firestore + Storage rules deployed from this repo
- [ ] Android SHA-1 / SHA-256 registered (Section 1)
- [ ] Admin test user has `accountRole: "admin"` in Firestore
