# COTS Monitor

COTS Monitor is a Flutter capstone mobile application for monitoring crown-of-thorns
starfish at dive sites in Samal, Davao Gulf, Philippines. Divers submit geolocated
photos, an on-device detector identifies COTS, and Experts review detections and
coordinate monitoring with Administrators.

## Submission links

- **Source code:** [creermegan-dev/cots-capstone](https://github.com/creermegan-dev/cots-capstone)
- **Current submission branch:** [supabase-migration](https://github.com/creermegan-dev/cots-capstone/tree/supabase-migration)
- **Android application:** [GitHub Releases](https://github.com/creermegan-dev/cots-capstone/releases)
- **Browser demo:** Appetize setup pending; no demo URL has been published yet.
- **Custom domain:** Not applicable.

The application is installed on an Android device. The Releases page distributes
the APK; it is not a browser-hosted application. Instructor acceptance of an APK
link for the live-application requirement should be confirmed. Version **1.0.3+4**
is being prepared; the final APK still needs rebuilding and publishing.

## Features

- Diver, Expert, and Administrator accounts with role-based access.
- Email verification and verification when signing in on a new device.
- On-device COTS detection, labeled photo overlays, and per-COTS Expert review.
- Photo location checks and maps of monitoring sites and submitted records.
- Capture and removal records, grouped photo submissions, and monthly visits.
- Site partnerships, site handovers, and reassignment workflows.
- Monthly site levels, notifications, dashboards, analytics, and report exports.
- Local pending submissions that synchronize when connectivity returns.

Supabase provides the current authentication, database, and evidence-storage
backend. Firebase remains in the source as a legacy rollback path. The default
detector is a YOLO11s ONNX export stored under the historical filename
`assets/models/yolov8_best.onnx`; see [model documentation](assets/models/README.md).

## Install the Android app

Requires Android **7.0 (API 24)** or later. The universal evaluation APK includes
ARM64, ARMv7, and x86-64 native libraries.

1. Open [Releases](https://github.com/creermegan-dev/cots-capstone/releases) on an
   Android device and select the latest published evaluation release.
2. Download the `.apk` under **Assets**, rather than the source-code ZIP.
3. Open the APK and allow installation from your browser or file manager if
   Android requests it. Install only the APK published by this repository.
4. Open **COTS Monitor** and sign in or create an account using an email address
   you can access. New-device sign-in requires an emailed verification code.

Field submissions require a verified Diver account. Arrange Expert or
Administrator access with the project team; account passwords and verification
codes are not published in this repository. Internet access is needed for account
verification, synchronization, and online data. Camera, photo, and location
permissions support detection and photo-location checks.

This APK is for capstone evaluation. The current Android build uses the existing
development signing configuration. Store distribution requires a private release
signing setup. Keep the signing identity consistent when updating an installation;
uninstalling or clearing app data can remove unsynchronized local submissions.

## Run from source

The submission was prepared with Flutter **3.44.0** and Dart **3.12.0**. Install
Flutter and Android SDK tooling, then run these commands from the repository root:

```powershell
flutter pub get
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with an Android device listed by `flutter devices`. Android is
the mobile submission target; other platform folders do not imply that every
feature has been verified on those platforms.

The default configuration connects to the capstone Supabase project using its
public client configuration. To use a separately configured backend:

```powershell
flutter run -d DEVICE_ID --dart-define=SUPABASE_URL=YOUR_PROJECT_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY
```

Only public client keys belong in an app build. Keep service-role keys, database
passwords, user credentials, and private signing keys outside source control.
Backend migrations, policies, and functions are in `supabase/`; they are not
automatically deployed by running Flutter. Existing setup notes are in
[docs/SUPABASE_STEP1.md](docs/SUPABASE_STEP1.md) and
[docs/SUPABASE_STEP2.md](docs/SUPABASE_STEP2.md).

## Checks and APK build

```powershell
flutter analyze --no-pub --no-fatal-infos
flutter test test/supabase_config_test.dart
flutter test --dart-define=USE_FIREBASE=true
flutter build apk --release
```

The configuration test checks the normal Supabase defaults. The full suite uses
the Firebase rollback flag because older repository fixtures exercise that path;
it does not validate the hosted backend. Database tests are under
`supabase/tests/database/` and require their own local database setup.

Latest checks on 2026-11-09: 412 Flutter tests plus the separate Supabase-default
configuration test passed; analysis reported no errors or warnings, with 35
informational notices remaining. The database suite passed 840 checks across 31
files in an isolated local Supabase database. Phone acceptance testing remains
separate from these automated checks.

The database utilities in `tool/supabase_*.bat` pin Supabase CLI 3.0.0. These
backup and diagnostic scripts explicitly target the linked hosted project when
manually run. Backup files and diagnostic logs stay local. Running Flutter does
not run these scripts or deploy database changes.

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Upload the
APK to a GitHub Release associated with the exact source commit used to build it.
Do not commit APKs, database backups, or build output to the source tree. Automated
checks do not replace testing sign-in, photo detection, location, submissions, and
role permissions on an Android phone against the intended backend.

## Project layout

| Directory | Contents |
| --- | --- |
| `lib/features/` | Authentication and Diver, Expert, and Administrator screens |
| `lib/models/`, `lib/services/`, `lib/providers/` | Data models, backend integrations, and application state |
| `lib/core/`, `lib/widgets/` | Shared configuration, themes, and UI components |
| `assets/` | Bundled images, ONNX models, and monitoring-site map data |
| `supabase/` | Database migrations, policies, Edge Functions, and database tests |
| `test/` | Flutter unit and widget tests |
| `docs/`, `tool/`, `scripts/` | Setup documentation and development utilities |
