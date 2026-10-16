---
name: cots-capstone-guidelines
description: Develop, fix, or review the COTS Monitor Flutter capstone using its existing architecture, detection pipeline, Firebase contracts, GIS behavior, and UI conventions. Use for work in this project.
---

# COTS Monitor guidelines

All paths are relative to the project root. Inspect current implementations before editing; preserve the requested scope and pre-existing user changes.

## Flutter and Dart

- Follow `pubspec.yaml` SDK/dependency constraints and `analysis_options.yaml` Flutter lints. Avoid unrelated dependency upgrades.
- Match nearby naming and imports; use null-safe types and appropriate const widgets. Check mounted state after asynchronous work and dispose owned controllers, subscriptions, camera, and inference resources.
- Provide loading, empty, error, and retry states. Do not represent failed inference or data access as successful empty results.

## Existing architecture

- `lib/main.dart` configures Material 3, routes, the root scaffold messenger, and Provider/ChangeNotifier state from `lib/providers/`.
- Screens live under `lib/features/{auth,landing,user,admin,expert}/`. Preserve `AuthWrapper` routing for guests, experts, admins, and field users.
- Reuse `lib/models/` for domain objects/serialization, `lib/services/` for repositories and processing, `lib/core/` for shared setup/tokens, and `lib/widgets/` for shared UI.
- Extend existing services and components; keep new business/persistence logic out of widget build methods. Do not impose a new architecture or state-management package for an unrelated task.

## COTS detection and YOLO

- Trace `lib/features/user/scan_detection_page.dart` and services `cots_yolo_detector.dart`, `yolo_image_preprocess.dart`, and `yolo_postprocess.dart`.
- The active asset is `assets/models/yolov8_best.onnx`, registered in `pubspec.yaml`, using `flutter_onnxruntime`. Preserve orientation correction, 640-square letterboxing, RGB /255 NCHW input, source-coordinate remapping, and non-maximum suppression.
- The decoder supports YOLOv8 and RT-DETR layouts. Check actual tensor shapes and coordinate conventions before replacing models; consult `assets/models/README.md` and fully rebuild after replacement.
- Reuse `CotsDetectionResult`, `ProcessedDetectionPayload`, `CotsSizeEstimator`, and `CotsDetectionImageOverlay`. Keep stored boxes, dimensions, counts, and overlays consistent; present size estimates as estimates.
- Use `CotsConfidencePolicy`: per-COTS 80-100% auto-acceptance, 20-79% expert validation, below 20% retake/rejection. Preserve record aggregation and expert decisions rather than substituting average confidence. Decoder filtering is separate from review thresholds.
- Do not replace real inference with synthetic boxes or demo counts. Existing synthetic legacy fallbacks are compatibility behavior, not detection evidence.

## Firebase and data

- Use existing repositories, services, serializers, and `RecordCollection` names. `ScanRecordRepository` merges captures, removal records, and legacy scan records; preserve collection identity, legacy reads, and capture/removal links.
- Preserve `lib/core/firebase_bootstrap.dart` platform handling: Windows defers native initialization and uses `windows_*_rest_service.dart` implementations. Keep SDK and REST authentication, serialization, and errors aligned when changing contracts.
- Capture/removal image stores use compressed JPEG/base64 Firestore documents through `ScanImageFirestoreCodec`, with legacy image support. Do not assume all images use Firebase Storage. Preserve compression limits and document overhead; keep image bytes separate from record metadata.
- Preserve ownership, timestamps, detection payloads, and verification fields. Inspect `firebase/firestore.rules`, `firebase/firestore.indexes.json`, and `firebase/storage.rules` for query/write changes. Keep expert verification and admin assignment permissions distinct.
- Do not weaken rules to hide client errors, log tokens/private data, or incidentally deploy rules, migrate live records, or replace Firebase configuration.

## GIS and maps

- Reuse `flutter_map`, `latlong2`, `DavaoGulfGeography`, `ZoneAssignmentService`, and existing user/admin map components. Coordinates use latitude, longitude order.
- Preserve EXIF GPS parsing, the scan flow's device-location fallback, and location provenance. Handle denied permissions and missing coordinates without inventing positions.
- Preserve polygon matching, bounded nearest-area fallback, null/Unassigned outcomes, and municipality/barangay/zone/site identifiers. Nearshore polygons are approximate monitoring areas, not surveyed boundaries.
- Reuse `cots_marine_sector_palette.dart` and `MarineSectorMapLabel` so legends, labels, filters, and details agree.

## UI/UX consistency

- Use the relevant tokens from `lib/core/cots_colors.dart`, `lib/core/user_shell_theme.dart`, or `lib/features/admin/theme/admin_theme.dart`; preserve their distinct contexts.
- Reuse auth controls, back buttons, submitted-image widgets, overlays, and admin cards/tables before creating equivalents.
- Follow existing responsive chrome, admin breakpoints, user navigation, typography, spacing, and status labels. Check small/wide layouts, contrast, touch targets, and long or missing content.

## Reuse and scope

- Search existing helpers and callers before adding code. Prefer focused edits; add files only for concrete responsibilities that do not fit existing files.
- Avoid duplicate services, speculative abstractions, placeholders, unrelated formatting, generated artifacts, and unnecessary documentation. Change assets, platform configuration, or dependencies only when the task requires it.

## Testing and completion

- For Dart changes, format touched files, run `flutter analyze`, and run relevant `flutter test` targets. Run the full suite for shared behavior changes; distinguish existing failures from regressions.
- Existing tests cover user serialization in `test/widget_test.dart` and assignments in `test/intervention_assignment_model_test.dart`. Add meaningful tests for changed confidence boundaries, serialization, geographic logic, or other behavior when warranted.
- For codec changes, run `dart run tool/verify_scan_image_codec.dart`. For inference changes, check representative photos, orientation, empty detections, and overlay alignment on a supported runtime.
- For persistence changes, check affected native/Windows paths without writing to production merely to test. For UI changes, inspect the affected flow and responsive sizes. Documentation-only changes need content/path validation, not an app build.
- Review the final diff for unrelated edits. Report changes, checks actually run, and blocked checks; never claim unperformed validation.
