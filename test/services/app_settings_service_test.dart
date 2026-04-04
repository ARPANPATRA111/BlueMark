import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bluetooth_attendance_tracker/services/app_settings_service.dart';

void main() {
  test('persists and loads runtime settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = AppSettingsService.instance;

    final settings = await service.getSettings();
    final updated = settings.copyWith(
      minRssi: -80,
      staleSeconds: 16,
      compactMode: true,
      securityKey: 'unit-test-key',
      sessionDuplicateWindowMinutes: 30,
      studentNotificationsEnabled: false,
    );

    await service.saveSettings(updated);
    final loaded = await service.getSettings();

    expect(loaded.minRssi, -80);
    expect(loaded.staleSeconds, 16);
    expect(loaded.compactMode, isTrue);
    expect(loaded.securityKey, 'unit-test-key');
    expect(loaded.sessionDuplicateWindowMinutes, 30);
    expect(loaded.studentNotificationsEnabled, isFalse);
  });
}
