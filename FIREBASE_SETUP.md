# COTS Monitor — Firebase setup

This app uses **Firebase Authentication**, **Cloud Firestore**, and **Firebase Storage**. Follow these steps once per machine / Firebase project.

## 1. Create a Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) and create a project.
2. Enable **Authentication → Sign-in method → Email/Password**.
3. Create a **Cloud Firestore** database (production mode, then deploy rules from this repo).
4. Enable **Storage** (same project).

## 2. Register apps and download config

### FlutterFire CLI (recommended)

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` with real API keys and registers Android/iOS/Web/macOS apps. Overwrites the placeholder file in the repo.

### Windows helper script

From the project root — **interactive** (pick the correct Firebase project from the list; use this if you see “project not found”):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/connect_firebase.ps1
```

If you know the exact **Project ID** from Console → Project settings → General:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/connect_firebase.ps1 -ProjectId your-real-project-id
```

### Android

- Download **google-services.json** from Firebase Console (Project settings → Your apps → Android).
- Replace `android/app/google-services.json` (delete the placeholder values).
- Ensure package name matches `applicationId` in `android/app/build.gradle.kts` (`com.example.cots_monitor` unless you change it).

### iOS / macOS

- Download **GoogleService-Info.plist** and add it to `ios/Runner` (and `macos/Runner` if you ship macOS).
- Match **Bundle ID** to your Firebase iOS app.

### Web

- After `flutterfire configure`, ensure `web/index.html` includes any scripts the CLI adds (usually handled automatically).

## 3. Deploy security rules

From the project root (with [Firebase CLI](https://firebase.google.com/docs/cli) installed and logged in):

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

Rules live in:

- `firebase/firestore.rules`
- `firebase/storage.rules`

## 4. Firestore data model

Collection: **`users`**, document ID = Auth **UID**.

Fields written on signup:

| Field           | Description                                      |
|-----------------|--------------------------------------------------|
| `uid`           | Same as document ID                              |
| `fullName`      | Display name                                     |
| `email`         | Email                                            |
| `phoneNumber`   | Phone                                            |
| `role`          | Position / role from signup dropdown           |
| `accountRole`   | Application RBAC (`user` by default; reserved for future `admin`) |
| `organization`  | Optional org text                                |
| `createdAt`     | Server timestamp                                 |
| `profileImage`  | Empty string until upload                        |
| `isActive`      | `true`                                           |

## 5. Run the app

```bash
flutter pub get
flutter run
```

If Gradle complains about Google Services, confirm `google-services.json` is the file from **your** Firebase project, not the placeholder.

## 6. Troubleshooting

### `configuration not found` / `CONFIGURATION_NOT_FOUND` on login

This means **Firebase Authentication has not been turned on** for your project yet (common on new projects).

1. Open [Firebase Console → Authentication](https://console.firebase.google.com/project/cots-capstone-project/authentication).
2. Click **Get started** (if you see it).
3. Open **Sign-in method** → **Email/Password** → **Enable** → **Save**.
4. Restart the app and try logging in again.

On Windows, the app uses the Identity Toolkit REST API; login will not work until step 3 is complete.

Optional: In [Google Cloud Console](https://console.cloud.google.com/apis/library/identitytoolkit.googleapis.com?project=cots-capstone-project), ensure **Identity Toolkit API** is enabled.

### Other issues

- **Profile unavailable after login**: Check Firestore rules deployment and device network; use **Retry** on the error screen or view logs.
- **Email already in use**: Sign in instead of registering again.
- **OneDrive / locked `build` folder** (Windows): See `scripts/windows_deep_clean_flutter.ps1` and consider moving the repo outside synced folders.
