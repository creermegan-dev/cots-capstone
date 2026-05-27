# COTS Monitor — Firebase setup

This app uses **Firebase Authentication**, **Cloud Firestore**, and **Firebase Storage** on the shared project **`cots-monitor`**.

**Working from multiple PCs?** See **[FIREBASE_COLLABORATION_GUIDE.md](FIREBASE_COLLABORATION_GUIDE.md)** for shared keystores, committed configs, emulators, and team workflow.

---

## 1. Firebase project (team default)

| Setting | Value |
|---------|--------|
| **Project ID** | `cots-monitor` |
| **Console** | [console.firebase.google.com/project/cots-monitor](https://console.firebase.google.com/project/cots-monitor) |

One-time in Firebase Console:

1. **Authentication → Sign-in method → Email/Password** → Enable → Save
2. **Firestore** — create database (production mode), then deploy rules from this repo (step 3)
3. **Storage** — enable bucket for the same project

Optional: In [Google Cloud Console](https://console.cloud.google.com/apis/library/identitytoolkit.googleapis.com?project=cots-monitor), ensure **Identity Toolkit API** is enabled (needed for Windows REST login).

---

## 2. Connect this Flutter app

### Option A — Use committed configs (fastest)

After `git clone`, these files should already target `cots-monitor`:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `.firebaserc`

Run:

```bash
flutter pub get
flutter run
```

### Option B — Regenerate configs (new machine or project refresh)

**Prerequisites:** Flutter, Node.js, Firebase CLI, FlutterFire CLI

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```

From the **repository root**:

```powershell
# Interactive — select cots-monitor
powershell -ExecutionPolicy Bypass -File scripts/connect_firebase.ps1

# Non-interactive — team default
powershell -ExecutionPolicy Bypass -File scripts/connect_firebase.ps1 -ProjectId cots-monitor
```

Or manually:

```bash
flutterfire configure --project=cots-monitor --platforms=web,android,windows --android-package-name=com.example.cots_monitor
```

Confirm `lib/firebase_options.dart` shows `projectId: 'cots-monitor'` for **android**, **web**, and **windows**.

### Android

- Package name: `com.example.cots_monitor` (`android/app/build.gradle.kts`)
- `google-services.json` is generated/updated by FlutterFire or downloaded from Console
- Debug builds use the **shared** `android/app/debug.keystore` (see collaboration guide for SHA fingerprints)

### Windows

- Uses `DefaultFirebaseOptions.windows` from `firebase_options.dart`
- Auth and profile I/O use **HTTPS REST**, not native Firebase plugins at startup (`lib/core/firebase_bootstrap.dart`)
- Requires Email/Password enabled on `cots-monitor`

### Web

- After `flutterfire configure`, Web SDK config comes from `firebase_options.dart` (usually no extra manual steps)

### iOS (if needed)

If iOS still references a legacy project in `firebase_options.dart`, reconfigure:

```bash
flutterfire configure --project=cots-monitor --platforms=ios --ios-bundle-id=com.example.cots_monitor
```

Add **GoogleService-Info.plist** to `ios/Runner` from Console or FlutterFire output.

---

## 3. Deploy security rules

From the repo root (Firebase CLI logged in):

```bash
firebase deploy --only firestore:rules,storage
```

| File | Purpose |
|------|---------|
| `firebase/firestore.rules` | `users`, `scan_records` access |
| `firebase/storage.rules` | Storage access |

All developers should deploy after pulling rule changes.

---

## 4. Firestore data model

### `users` (document ID = Auth UID)

Written on signup:

| Field | Description |
|-------|-------------|
| `uid` | Same as document ID |
| `fullName` | Display name |
| `email` | Email |
| `phoneNumber` | Phone |
| `role` | Position / role from signup dropdown |
| `accountRole` | App RBAC: `user` (default) or `admin` |
| `organization` | Optional |
| `createdAt` | Server timestamp |
| `profileImage` | Empty until upload |
| `isActive` | `true` |

**Admin dashboard access:** set `accountRole` to `"admin"` in Console for that UID. The app cannot self-promote to admin (Firestore rules block it).

### `scan_records` (auto ID)

Created when a signed-in user submits a GoPro scan (`ScanRecordService`). Key fields include `uid`, `activity_type`, `capture_source`, `citizen_contribution`, GPS, and AI detection counts. See `lib/services/scan_record_service.dart`.

---

## 5. Run the app

```bash
flutter pub get
flutter run -d windows   # desktop
flutter run -d chrome    # web
flutter run              # pick device
```

### After login — where you land

| Profile | Screen |
|---------|--------|
| `accountRole: "admin"` | Admin shell (analytics, map, records UI) |
| `accountRole: "user"` | Field user dashboard |

Same login screen for both roles. If Auth succeeds but Firestore has no `users/{uid}` document, the app shows **Profile unavailable** with Retry / Sign out.

> Admin and user **dashboards mostly use mock UI data** today. Live Firestore writes are primarily **auth profiles** and **scan_records** submissions.

---

## 6. Troubleshooting

### `configuration not found` / `CONFIGURATION_NOT_FOUND` on login

Email/Password is not enabled on the project.

1. [Authentication](https://console.firebase.google.com/project/cots-monitor/authentication) → **Get started** (if shown)
2. **Sign-in method** → **Email/Password** → **Enable** → **Save**
3. Restart the app

On **Windows**, login uses the Identity Toolkit REST API and will not work until step 2 is complete.

### Wrong Firebase project / mixed data

Check:

- `lib/firebase_options.dart` → `projectId` is `cots-monitor` for your platform
- `android/app/google-services.json` → `"project_id": "cots-monitor"`
- `.firebaserc` → `"default": "cots-monitor"`

Re-run `scripts/connect_firebase.ps1 -ProjectId cots-monitor` if needed. See **FIREBASE_COLLABORATION_GUIDE.md**.

### Profile unavailable after login

- Firestore rules deployed? (`firebase deploy --only firestore:rules`)
- Network available?
- Document `users/{uid}` exists for that Auth user?
- Use **Retry** on the error screen; check debug console logs

### Email already in use

Use **Login** instead of signup for that address.

### Android / Google Sign-In issues on another PC

Register the team **shared debug keystore** SHA fingerprints (collaboration guide §1).

### OneDrive / locked `build` or `.plugin_symlinks` (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows_deep_clean_flutter.ps1
```

Prefer cloning the repo outside OneDrive-synced folders.

### Flutter failed to delete `.plugin_symlinks`

Usually a file lock, not permissions. Close running app instances, then remove build folders manually or use the deep-clean script above.

---

## 7. Optional — local emulators

To avoid overwriting shared cloud test data, use the **Firebase Emulator Suite**. Full steps: **FIREBASE_COLLABORATION_GUIDE.md** §6.

```bash
firebase init emulators    # once: Auth, Firestore, Storage
firebase emulators:start --import=./firebase/mock_data
```

Emulator wiring in `lib/core/firebase_bootstrap.dart` is documented there but **not enabled by default** in the app yet.
