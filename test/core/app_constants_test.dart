import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('app name is BlueMark', () {
      expect(AppConstants.appName, 'BlueMark');
    });

    group('BLE constants', () {
      test('service UUID follows standard format', () {
        expect(AppConstants.bleServiceUuid, contains('-'));
        expect(AppConstants.bleServiceUuid.length, 36);
      });

      test('manufacturer ID is 0x0A77', () {
        expect(AppConstants.bleManufacturerId, 0x0A77);
      });

      test('prefixes are set', () {
        expect(AppConstants.bleNamePrefix, 'STU:');
        expect(AppConstants.blePayloadPrefix, 'BAT:');
      });

      test('rolling token window is 20 seconds', () {
        expect(AppConstants.bleRollingTokenWindowSeconds, 20);
      });
    });

    group('Scan/Detection thresholds', () {
      test('minRssi is negative', () {
        expect(AppConstants.defaultMinRssi, lessThan(0));
      });

      test('maxTrackedStudents is reasonable', () {
        expect(AppConstants.maxTrackedStudents, greaterThan(0));
        expect(AppConstants.maxTrackedStudents, lessThanOrEqualTo(1000));
      });

      test('stale seconds is positive', () {
        expect(AppConstants.detectionStaleSeconds, greaterThan(0));
      });

      test('health poll interval is positive', () {
        expect(AppConstants.healthPollIntervalSeconds, greaterThan(0));
      });

      test('health failure threshold is positive', () {
        expect(AppConstants.healthFailureThreshold, greaterThan(0));
      });
    });

    group('Firestore constants', () {
      test('batch size is positive', () {
        expect(AppConstants.firestoreBatchSize, greaterThan(0));
      });

      test('collection names are non-empty', () {
        expect(AppConstants.usersCollection, isNotEmpty);
        expect(AppConstants.tenantsCollection, isNotEmpty);
        expect(AppConstants.attendanceCollection, isNotEmpty);
        expect(AppConstants.attendanceReceiptCollection, isNotEmpty);
        expect(AppConstants.studentCollection, isNotEmpty);
        expect(AppConstants.classCollection, isNotEmpty);
        expect(AppConstants.activeSessionCollection, isNotEmpty);
      });
    });
  });
}
