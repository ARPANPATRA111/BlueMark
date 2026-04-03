import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/app_runtime_settings.dart';

class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const _minRssiKey = 'settings.minRssi';
  static const _staleSecondsKey = 'settings.staleSeconds';
  static const _compactModeKey = 'settings.compactMode';
  static const _securityKey = 'settings.securityKey';
  static const _duplicateWindowKey = 'settings.duplicateWindowMins';
  static const _studentNotifKey = 'settings.studentNotifications';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<AppRuntimeSettings> getSettings() async {
    await init();
    final prefs = _prefs!;

    return AppRuntimeSettings(
      minRssi: prefs.getInt(_minRssiKey) ?? -92,
      staleSeconds: prefs.getInt(_staleSecondsKey) ?? AppConstants.detectionStaleSeconds,
      compactMode: prefs.getBool(_compactModeKey) ?? false,
      securityKey: prefs.getString(_securityKey) ?? AppConstants.defaultSecurityKey,
      sessionDuplicateWindowMinutes: prefs.getInt(_duplicateWindowKey) ?? 20,
      studentNotificationsEnabled: prefs.getBool(_studentNotifKey) ?? true,
    );
  }

  Future<void> saveSettings(AppRuntimeSettings value) async {
    await init();
    final prefs = _prefs!;
    await prefs.setInt(_minRssiKey, value.minRssi);
    await prefs.setInt(_staleSecondsKey, value.staleSeconds);
    await prefs.setBool(_compactModeKey, value.compactMode);
    await prefs.setString(_securityKey, value.securityKey.trim());
    await prefs.setInt(_duplicateWindowKey, value.sessionDuplicateWindowMinutes);
    await prefs.setBool(_studentNotifKey, value.studentNotificationsEnabled);
  }
}
