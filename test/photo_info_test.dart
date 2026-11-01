import 'package:cots_monitor/features/admin/screens/admin_record_details_screen.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/models/photo_source.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Photo Information section (claude/agreed_workflow_decisions.md): show
/// where the location and the time really came from; no made-up values.

CaptureModel _capture({
  double? lat = 7.29261,
  double? lng = 125.703,
  String locationSource = 'exif',
  String timeSource = 'exif',
}) =>
    CaptureModel(
      id: 'cap-1',
      uid: 'diver-a',
      submittedBy: 'Diver Alpha',
      imageName: 'reef.jpg',
      aiDetectedCount: 1,
      confidence: 0.95,
      captureSource: 'GoPro Underwater Image',
      zone: 'Brgy. Cagangohan',
      notes: '',
      submittedAt: DateTime(2026, 10, 31, 10, 5),
      dateTaken: DateTime(2026, 10, 31, 9, 40),
      latitude: lat,
      longitude: lng,
      locationSource: locationSource,
      timeSource: timeSource,
    );

void main() {
  test('location sources read like people talk', () {
    expect(PhotoSource.locationLabel('exif'), 'Photo GPS');
    expect(PhotoSource.locationLabel('device_surface'), 'Phone GPS (at the surface)');
    expect(PhotoSource.locationLabel('manual_surface'), 'Typed in');
    expect(PhotoSource.locationLabel('unavailable'), 'Not available');
    expect(PhotoSource.locationLabel(''), 'Not recorded');
  });

  test('the date taken says where it came from', () {
    expect(PhotoSource.dateTaken('Oct 31, 2026 9:40 AM', 'exif'),
        'Oct 31, 2026 9:40 AM (from photo)');
    expect(PhotoSource.dateTaken('Oct 31, 2026 9:40 AM', 'device'),
        'Oct 31, 2026 9:40 AM (from phone clock)');
    expect(PhotoSource.dateTaken('Oct 5, 2026', 'manual'),
        'Oct 5, 2026 (entered by Diver)');
    expect(PhotoSource.dateTaken('Oct 31, 2026 9:40 AM', ''),
        'Oct 31, 2026 9:40 AM');
    expect(PhotoSource.dateTaken('Unknown', 'exif'), 'Unknown');
  });

  test('a photo without its own date is saved as "from phone clock"', () {
    final when = DateTime(2026, 10, 31, 9, 40);
    expect(SupabaseRecordService.timeSourceFor(dateTaken: when, timeFromPhoto: true), 'exif');
    expect(SupabaseRecordService.timeSourceFor(dateTaken: when, timeFromPhoto: false), 'device');
    expect(SupabaseRecordService.timeSourceFor(dateTaken: null, timeFromPhoto: true), 'device');
    // Submissions queued by older builds keep the old behaviour.
    expect(SupabaseRecordService.timeSourceFor(dateTaken: when), 'exif');
    expect(SupabaseRecordService.gpsSourceFor(hasGps: true, gpsFromPhoto: false),
        'device_surface');
  });

  test('the sources travel from the photo to the Expert page', () {
    final row = ScanRecordModel.fromCapture(
            _capture(locationSource: 'device_surface', timeSource: 'device'))
        .toAdminTableRow(1);
    expect(row.locationSource, 'device_surface');
    expect(row.timeSource, 'device');
    final approved = row.copyWith(adminConfirmed: true);
    expect(approved.locationSource, 'device_surface');
    expect(approved.timeSource, 'device');

    final data = AdminRecordDetailsData.fromTableRow(row);
    expect(data.locationAccuracy, 'Phone GPS (at the surface)');
    expect(data.dateCaptured, 'Oct 31, 2026 9:40 AM (from phone clock)');
    expect(data.coordinates, contains('7.292610'));
  });

  test('no GPS shows "Not available", never made-up coordinates', () {
    final row = ScanRecordModel.fromCapture(
            _capture(lat: null, lng: null, locationSource: 'unavailable'))
        .toAdminTableRow(1);
    final data = AdminRecordDetailsData.fromTableRow(row);
    expect(data.coordinates, 'Not available');
    expect(data.locationAccuracy, 'Not available');
  });

  test('a monthly visit: typed coordinates and the date the Diver picked', () {
    final visit = FollowUpSurveyModel.fromMap({
      'area_name': 'Zone A',
      'barangay': 'Cagangohan',
      'submitted_by': 'Diver Alpha',
      'survey_calendar_date': '2026-10-05',
      'gps': {'latitude': 7.2926, 'longitude': 125.703},
      'status': 'completed',
    }, id: 'visit-1');
    final record = ScanRecordModel.fromFollowUpSurvey(visit);
    expect(record.locationSource, 'manual_surface');
    expect(record.timeSource, 'manual');
    final row = record.toAdminTableRow(1);
    expect(row.dateCaptured, 'Oct 5, 2026');
    expect(AdminRecordDetailsData.fromTableRow(row).dateCaptured,
        'Oct 5, 2026 (entered by Diver)');
    expect(
        ScanRecordModel.fromFollowUpSurvey(FollowUpSurveyModel.fromMap({
          'survey_calendar_date': '2026-10-05',
          'status': 'completed',
        }, id: 'visit-2'))
            .locationSource,
        'unavailable');
  });

  test('old Firebase records say "Not recorded"', () {
    final row = ScanRecordModel.fromCapture(
            _capture(locationSource: '', timeSource: ''))
        .toAdminTableRow(1);
    final data = AdminRecordDetailsData.fromTableRow(row);
    expect(data.locationAccuracy, 'Not recorded');
    expect(data.dateCaptured, 'Oct 31, 2026 9:40 AM');
  });
}
