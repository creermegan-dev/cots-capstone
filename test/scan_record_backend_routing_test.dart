import 'package:cots_monitor/services/scan_record_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanRecordBackendRouter', () {
    test('Supabase configuration wins on Android and Windows', () {
      expect(
        ScanRecordBackendRouter.select(
          supabaseConfigured: true,
          useWindowsFirebaseRest: false,
        ),
        ScanRecordBackend.supabase,
      );
      expect(
        ScanRecordBackendRouter.select(
          supabaseConfigured: true,
          useWindowsFirebaseRest: true,
        ),
        ScanRecordBackend.supabase,
      );
    });

    test('Supabase route does not invoke Firebase record sources', () {
      var supabaseCalls = 0;
      var windowsFirebaseCalls = 0;
      var firebaseSdkCalls = 0;

      String route({required bool windows}) {
        return ScanRecordBackendRouter.route(
          supabaseConfigured: true,
          useWindowsFirebaseRest: windows,
          supabase: () {
            supabaseCalls++;
            return 'supabase';
          },
          windowsFirebaseRest: () {
            windowsFirebaseCalls++;
            return 'windows-firebase';
          },
          firebaseSdk: () {
            firebaseSdkCalls++;
            return 'firebase-sdk';
          },
        );
      }

      expect(route(windows: false), 'supabase');
      expect(route(windows: true), 'supabase');
      expect(supabaseCalls, 2);
      expect(windowsFirebaseCalls, 0);
      expect(firebaseSdkCalls, 0);
    });

    test('Firebase rollback retains native and Windows routes', () {
      String route({required bool windows}) {
        return ScanRecordBackendRouter.route(
          supabaseConfigured: false,
          useWindowsFirebaseRest: windows,
          supabase: () => 'supabase',
          windowsFirebaseRest: () => 'windows-firebase',
          firebaseSdk: () => 'firebase-sdk',
        );
      }

      expect(route(windows: false), 'firebase-sdk');
      expect(route(windows: true), 'windows-firebase');
    });

    test('selected record-loading failures remain visible', () async {
      final failure = StateError('Supabase record load failed');
      final stream = ScanRecordBackendRouter.route<Stream<List<int>>>(
        supabaseConfigured: true,
        useWindowsFirebaseRest: true,
        supabase: () => Stream.error(failure),
        windowsFirebaseRest: () => Stream.value(const [1]),
        firebaseSdk: () => Stream.value(const [2]),
      );

      await expectLater(stream, emitsError(same(failure)));
    });
  });
}
