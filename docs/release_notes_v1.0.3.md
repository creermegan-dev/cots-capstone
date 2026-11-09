# COTS Monitor v1.0.3 - Capstone evaluation

Android version: **1.0.3 (build 4)**.

Preparation status: the final APK must be rebuilt from the finalized source
commit before this release is published. The Appetize browser demo is also pending.

Requires Android **7.0 (API 24)** or later. The universal APK includes ARM64,
ARMv7, and x86-64 native libraries.

## Included development progress

- Supabase-backed authentication, trusted-device email verification, records,
  and private evidence storage, with the Firebase rollback source retained.
- On-device COTS detection, per-COTS review, grouped photo records, and photo
  location checks.
- Samal monitoring-site maps, site partnerships, handovers, monthly visits,
  and reassignment workflows.
- Monthly site levels and history, staff dashboards, analytics, notifications,
  and report exports.
- Recent record-detail, profile-photo, local-time display, site-coverage,
  offline-submission, and responsive-layout improvements.

## Installation and access

Download the Android `.apk` attached to this release, open it on an Android
device, and follow the installation prompts. Sign in using an authorized account
or register with an email address you can access. Email verification is required
on a new device. Field submissions require a verified Diver account; coordinate
Expert and Administrator evaluation access privately with the project team.

This is an installable mobile application. The release URL is an application
download link, not a browser-hosted version. A custom domain is not applicable.

## Evaluation notes

- This is a capstone evaluation build using the existing development signing
  configuration, not a Play Store production release.
- Account verification and synchronization require the hosted backend and an
  internet connection. Pending local submissions should be synchronized before
  uninstalling the application or clearing its data.
- Practice monitoring sites remain available in this version. Photo-location
  rules still apply; arbitrary photos outside the configured sites cannot be
  submitted as field evidence.
- Detection confidence is not an accuracy measurement. Expert review and field
  verification remain part of the monitoring workflow.

## Validation on 2026-11-09

- Supabase-default configuration test: **1 passed**.
- Full Flutter suite with the Firebase rollback flag: **412 passed**. Map widget
  fixtures logged tile-request failures, so these tests do not verify live tiles.
- `flutter analyze --no-pub --no-fatal-infos`: **0 errors and 0 warnings**;
  35 existing informational notices remain.
- Local database suite: **840 checks across 31 files passed**, including privacy,
  permissions, monthly site levels, notifications, and evidence completion.
- Final APK rebuilt from commit `cf9dd44d365303618ba08dddcbe4579ba0e92a44`; version 1.0.3, build 4,
  minimum API 24; Android v2 signature verification passed.
- GitHub confirmed the uploaded APK SHA-256 matches the local verified build.
- Background cron scheduling was not exercised in the isolated local database.
- Android phone acceptance testing and hosted-database tests were not run during
  this release preparation. No backend migrations were deployed.

## Release assets

- `COTS-Monitor-v1.0.3-android.apk` (193,455,650 bytes).
- `SHA256SUMS.txt` contains the verified APK checksum.

SHA-256: `ad0ac8d063a576a408a8cc9c711b6db99976bd9a31022e2bd47730c39f4b6c09`.

Browser demo: [Run COTS Monitor](https://appetize.io/app/b_i3fjcp3fuphgq3yupuzinpqaq4). Launch and navigation to
registration verified on a cloud Pixel 7 / Android 13. Authenticated detection,
camera, and GPS workflows were not tested in the browser. Free-plan session and
monthly usage limits apply.
