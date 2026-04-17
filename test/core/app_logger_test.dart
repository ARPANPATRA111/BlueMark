import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/core/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    // AppLogger delegates to dart:developer.log which is a no-op in test.
    // These tests verify the API compiles and doesn't throw.

    test('info does not throw', () {
      expect(() => AppLogger.info('Test', 'message'), returnsNormally);
    });

    test('warning does not throw', () {
      expect(() => AppLogger.warning('Test', 'warn message'), returnsNormally);
    });

    test('error does not throw', () {
      expect(
        () => AppLogger.error('Test', 'error message', Exception('test'), StackTrace.current),
        returnsNormally,
      );
    });

    test('convenience methods do not throw', () {
      expect(() => AppLogger.ble('scan started'), returnsNormally);
      expect(() => AppLogger.bleError('scan failed', Exception('fail')), returnsNormally);
      expect(() => AppLogger.firebase('init done'), returnsNormally);
      expect(() => AppLogger.firebaseError('auth fail'), returnsNormally);
      expect(() => AppLogger.hive('boxes opened'), returnsNormally);
      expect(() => AppLogger.attendance('record saved'), returnsNormally);
      expect(() => AppLogger.attendanceError('sync failed'), returnsNormally);
      expect(() => AppLogger.lifecycle('app resumed'), returnsNormally);
    });
  });
}
