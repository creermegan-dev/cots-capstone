# COTS Monitor — Multi-Workstation Firebase Collaboration Guide

This guide outlines the unified pipeline for your development team to collaborate on the **COTS Monitor** Firebase backend (`cots-capstone-project`) across different developer machines and workstations without breaking configurations, authentication, or clobbering each other's test data.

---

## 1. Architectural Strategy: The Shared Debug Keystore

### Why this is mandatory:
By default, Android builds signed in debug mode utilize a local keystore generated automatically on that specific computer (`~/.android/debug.keystore`). Since every developer workstation has a unique local keystore, their compilation SHA-1 and SHA-256 signatures differ.
If you try to run Firebase Auth (Google Sign-In, SMS, etc.) on multiple developer workstations, **it will work on the initial developer's machine but silently fail on everyone else's.**

### The Solution (Already Implemented):
We have copied a standard, uniform `debug.keystore` directly into the repository at `android/app/debug.keystore` and overrode your Gradle configurations inside `android/app/build.gradle.kts` to enforce its use:

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

Now, **every team member on every workstation compiles with the exact same debug signature.**

### Action Required in Firebase Console (Once):
The principal project administrator must register the fingerprints of this shared keystore under your Android App configuration inside the **[Firebase Console](https://console.firebase.google.com/)** -> **Project Settings** -> **Your Apps** -> **Android**:

To view the fingerprints from your own machine, run:
```bash
# From the android/app directory:
keytool -list -v -keystore debug.keystore -storepass android -alias androiddebugkey
```
Add the resulting **SHA-1** and **SHA-256** fingerprints to your Firebase project.

---

## 2. Setting Up a New Workstation (Step-by-Step)

When a new developer joins or a team member switches machines, follow these steps to connect seamlessly:

### Step 1: Install System Prerequisites
The developer must install the following utilities on their workstation:
1. **Node.js** (required for Firebase CLI).
2. **Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```
3. **FlutterFire CLI**:
   Ensure Flutter/Dart is on the system path, then run:
   ```bash
   dart pub global activate flutterfire_cli
   ```

### Step 2: Authenticate with Firebase
The developer must sign in using the Google account that has access/permissions for the `cots-capstone-project` Firebase console:
```bash
firebase login
```
*(If they are a team member, invite their email as a **Developer/Editor** under Project Settings -> Users and Permissions in the Firebase Console).*

### Step 3: Run the Synchronize Script
From the repository root, run your pre-configured PowerShell helper script:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/connect_firebase.ps1 -ProjectId cots-capstone-project
```
This script will:
- Initialize the local FlutterFire command line tool.
- Fetch the official cloud project configurations.
- Regenerate the local `lib/firebase_options.dart` file automatically with correct local keys.
- Register their local workstation configuration with the web, Android, and iOS profiles.

---

## 3. Local Isolation: Firebase Local Emulators

To prevent developers from clobbering each other's test data (e.g., deleting active reefs, editing Firestore profiles, or causing token conflicts) while working concurrently, your team should utilize the **Firebase Local Emulator Suite**.

### Setting Up the Emulators:
1. Ensure Java Runtime Environment (JRE) is installed on the machine.
2. From the repository root, initialize emulators:
   ```bash
   firebase init emulators
   ```
   Select **Auth**, **Firestore**, and **Storage** emulators. Accept the default port selections.
3. Start the emulators locally:
   ```bash
   firebase emulators:start
   ```
   This spins up a local database UI dashboard at `http://localhost:4000/`.

### Connecting Flutter to Local Emulators:
To ensure the app connects to your local machine emulators instead of production Firestore when debugging:
Modify [lib/core/firebase_bootstrap.dart](file:///c:/Users/Acer/Desktop/Programming/cots-capstone/lib/core/firebase_bootstrap.dart):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

Future<void> ensureFirebaseInitialized() async {
  if (deferFirebaseUntilFirstUse || Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // POINT TO LOCAL EMULATORS IN DEBUG MODE
  if (kDebugMode) {
    const localHost = '10.0.2.2'; // '10.0.2.2' maps to localhost on Android Emulators
    
    FirebaseFirestore.instance.useFirestoreEmulator(localHost, 8080);
    await FirebaseAuth.instance.useAuthEmulator(localHost, 9099);
    FirebaseStorage.instance.useStorageEmulator(localHost, 9199);
    
    debugPrint('Connected to local Firebase Emulator Suite.');
  }
}
```

---

## 4. Best Practices for Team Collaboration

- **Never Commit `google-services.json` or `GoogleService-Info.plist` modifications directly.** The `connect_firebase.ps1` script will handle updating these files locally. 
- **Secure Security Rules first.** All team members must keep local changes to `firebase/firestore.rules` and `firebase/storage.rules` synchronized. Deploy database rules updates via Firebase CLI:
  ```bash
  firebase deploy --only firestore:rules
  ```
- **Sync Mock Data:** When testing local emulator databases, use the export/import commands so the entire team works with identical mock zones:
  ```bash
  # Start emulators and load mock data
  firebase emulators:start --import=./firebase/mock_data
  
  # Export newly created zones to share with the team
  firebase emulators:export ./firebase/mock_data
  ```
