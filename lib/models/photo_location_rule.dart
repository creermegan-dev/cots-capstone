/// Stage 7 (agreed 2026-11-01, option B): every photo needs a location.
///
/// 1. The photo's own GPS (saved by the camera) is used when it has one.
/// 2. Otherwise the phone's GPS (taken at the surface when the photo is
///    added) is used, but only for photos taken within the last hour, so the
///    phone is still near the dive site.
/// 3. A photo with no location, or whose location is outside every
///    monitoring area (on land or in deep water), cannot be submitted.
enum PhotoLocationProblem { none, tooOld, noLocation, outsideArea }

abstract final class PhotoLocationRule {
  /// How old a photo without its own GPS may be (phone GPS fallback).
  static const maxAgeWithoutPhotoGps = Duration(hours: 1);

  static const tooOldMessage =
      'This photo has no GPS and was taken over an hour ago (or has no date), '
      "so its location can't be confirmed. Use a photo with GPS, or take it at "
      'the dive site.';
  static const noLocationMessage =
      "This photo has no GPS and the phone's location is not available. Turn "
      'on location for COTS Monitor, then tap Try again.';
  static const outsideAreaMessage =
      "This photo's location is outside every monitoring area (on land or in "
      'deep water). Use a photo taken at the dive site.';

  static const locationRequiredBanner =
      'Location is required. COTS Monitor uses the GPS saved in your photos, '
      "or your phone's location at the surface right after the dive.";
  static const photoLocationPermissionTitle = 'Allow photo locations';
  static const photoLocationPermissionMessage =
      'COTS Monitor needs permission to read the GPS saved in your photos. '
      'Open settings, then allow access to all photos (Photos and videos) so '
      'their location can be read.';

  /// Whether the phone's GPS may stand in for a photo with no GPS of its own.
  static bool phoneGpsAllowed({DateTime? dateTaken, required DateTime now}) {
    if (dateTaken == null) return false;
    final age = now.difference(dateTaken);
    // A small negative age (camera clock slightly ahead) is fine.
    return age <= maxAgeWithoutPhotoGps &&
        age >= -const Duration(minutes: 10);
  }

  /// The problem with a photo's location, or [PhotoLocationProblem.none].
  static PhotoLocationProblem check({
    required bool hasPhotoGps,
    required bool hasLocation,
    required bool insideArea,
    DateTime? dateTaken,
    required DateTime now,
  }) {
    if (!hasPhotoGps && !phoneGpsAllowed(dateTaken: dateTaken, now: now)) {
      return PhotoLocationProblem.tooOld;
    }
    if (!hasLocation) return PhotoLocationProblem.noLocation;
    if (!insideArea) return PhotoLocationProblem.outsideArea;
    return PhotoLocationProblem.none;
  }

  static String message(PhotoLocationProblem problem) => switch (problem) {
        PhotoLocationProblem.tooOld => tooOldMessage,
        PhotoLocationProblem.noLocation => noLocationMessage,
        PhotoLocationProblem.outsideArea => outsideAreaMessage,
        PhotoLocationProblem.none => '',
      };
}
