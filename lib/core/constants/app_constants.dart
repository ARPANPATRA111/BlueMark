class AppConstants {
  const AppConstants._();

  static const String appName = 'Bluetooth Attendance Tracker';

  static const String bleServiceUuid = '0000A77E-0000-1000-8000-00805F9B34FB';
  static const int bleManufacturerId = 0x0A77;
  static const String bleAdvertiseChannel = 'attendance_ble_advertiser';
  static const String bleNamePrefix = 'STU:';
  static const String blePayloadPrefix = 'BAT:';
  static const int bleRollingTokenWindowSeconds = 20;
  static const String defaultSecurityKey = 'bat-secure-default-v1';

  static const int detectionStaleSeconds = 18;
  static const int scanWindowSeconds = 15;

  static const String usersCollection = 'users';
  static const String tenantsCollection = 'tenants';
  static const String attendanceCollection = 'attendance';
  static const String attendanceReceiptCollection = 'attendance_receipts';
  static const String studentCollection = 'students';
  static const String classCollection = 'classes';
  static const String activeSessionCollection = 'active_sessions';
}
