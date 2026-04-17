import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/app_runtime_settings.dart';

void main() {
  group('AppRuntimeSettings', () {
    const defaults = AppRuntimeSettings(
      minRssi: -92,
      staleSeconds: 18,
      compactMode: false,
      securityKey: 'default-key',
      sessionDuplicateWindowMinutes: 45,
      studentNotificationsEnabled: true,
    );

    test('copyWith updates only specified fields', () {
      final updated = defaults.copyWith(minRssi: -80, compactMode: true);
      expect(updated.minRssi, -80);
      expect(updated.compactMode, isTrue);
      expect(updated.staleSeconds, 18);
      expect(updated.securityKey, 'default-key');
      expect(updated.sessionDuplicateWindowMinutes, 45);
      expect(updated.studentNotificationsEnabled, isTrue);
    });

    test('copyWith with no arguments returns identical values', () {
      final copy = defaults.copyWith();
      expect(copy.minRssi, defaults.minRssi);
      expect(copy.staleSeconds, defaults.staleSeconds);
      expect(copy.compactMode, defaults.compactMode);
      expect(copy.securityKey, defaults.securityKey);
      expect(copy.sessionDuplicateWindowMinutes, defaults.sessionDuplicateWindowMinutes);
      expect(copy.studentNotificationsEnabled, defaults.studentNotificationsEnabled);
    });

    test('all fields can be overridden at once', () {
      final custom = defaults.copyWith(
        minRssi: -60,
        staleSeconds: 10,
        compactMode: true,
        securityKey: 'new-key',
        sessionDuplicateWindowMinutes: 30,
        studentNotificationsEnabled: false,
      );
      expect(custom.minRssi, -60);
      expect(custom.staleSeconds, 10);
      expect(custom.compactMode, isTrue);
      expect(custom.securityKey, 'new-key');
      expect(custom.sessionDuplicateWindowMinutes, 30);
      expect(custom.studentNotificationsEnabled, isFalse);
    });
  });
}
