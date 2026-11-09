import 'package:cots_monitor/features/user/scan_detection_page.dart';
import 'package:cots_monitor/models/photo_location_rule.dart';
import 'package:cots_monitor/services/area_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 1, 12, 0);

  PhotoLocationProblem check({
    bool photoGps = false,
    bool location = true,
    bool inside = true,
    DateTime? taken,
  }) =>
      PhotoLocationRule.check(
        hasPhotoGps: photoGps,
        hasLocation: location,
        insideArea: inside,
        dateTaken: taken,
        now: now,
      );

  test('a photo with its own GPS inside an area is fine, however old', () {
    expect(check(photoGps: true, taken: DateTime(2026, 3, 1)),
        PhotoLocationProblem.none);
  });

  test('phone GPS stands in only for photos taken within the last 2 hours', () {
    expect(check(taken: now.subtract(const Duration(minutes: 119))),
        PhotoLocationProblem.none);
    expect(check(taken: now.subtract(const Duration(minutes: 121))),
        PhotoLocationProblem.tooOld);
    expect(check(taken: null), PhotoLocationProblem.tooOld);
    expect(check(taken: now.add(const Duration(minutes: 5))),
        PhotoLocationProblem.none);
  });

  test('no location at all, or outside every area, cannot be submitted', () {
    expect(check(location: false, taken: now), PhotoLocationProblem.noLocation);
    expect(check(photoGps: true, inside: false),
        PhotoLocationProblem.outsideArea);
  });

  test('a location problem blocks the photo like a failed analysis', () {
    expect(
      scanPhotoNeedsAttention(
        isFollowUp: true,
        analysisFailed: false,
        detectedCount: 2,
        locationProblem: true,
      ),
      isTrue,
    );
    expect(
      scanPhotoNeedsAttention(
        isFollowUp: true,
        analysisFailed: false,
        detectedCount: 2,
      ),
      isFalse,
    );
  });

  test('messages are plain and say what to do', () {
    expect(PhotoLocationRule.message(PhotoLocationProblem.tooOld),
        contains('over 2 hours ago'));
    expect(PhotoLocationRule.message(PhotoLocationProblem.noLocation),
        contains('Try again'));
    expect(PhotoLocationRule.message(PhotoLocationProblem.none), isEmpty);
  });

  test('the database refusal for a missing location becomes a plain message',
      () {
    expect(
      AreaMessages.forError(StateError(
          'COTS_AREA_NO_LOCATION: A location is required. Turn on location, or use a photo that has GPS.')),
      AreaMessages.noLocation,
    );
  });
}
