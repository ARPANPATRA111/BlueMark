class AppRuntimeSettings {
  const AppRuntimeSettings({
    required this.minRssi,
    required this.staleSeconds,
    required this.compactMode,
    required this.securityKey,
    required this.sessionDuplicateWindowMinutes,
    required this.studentNotificationsEnabled,
  });

  final int minRssi;
  final int staleSeconds;
  final bool compactMode;
  final String securityKey;
  final int sessionDuplicateWindowMinutes;
  final bool studentNotificationsEnabled;

  AppRuntimeSettings copyWith({
    int? minRssi,
    int? staleSeconds,
    bool? compactMode,
    String? securityKey,
    int? sessionDuplicateWindowMinutes,
    bool? studentNotificationsEnabled,
  }) {
    return AppRuntimeSettings(
      minRssi: minRssi ?? this.minRssi,
      staleSeconds: staleSeconds ?? this.staleSeconds,
      compactMode: compactMode ?? this.compactMode,
      securityKey: securityKey ?? this.securityKey,
      sessionDuplicateWindowMinutes:
          sessionDuplicateWindowMinutes ?? this.sessionDuplicateWindowMinutes,
      studentNotificationsEnabled:
          studentNotificationsEnabled ?? this.studentNotificationsEnabled,
    );
  }
}
