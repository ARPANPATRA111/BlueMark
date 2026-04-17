import 'dart:developer' as developer;

/// Structured logging utility for the app.
///
/// Uses `dart:developer` log which integrates with DevTools and is
/// automatically stripped in release builds by the Dart compiler.
class AppLogger {
  const AppLogger._();

  static void info(String tag, String message) {
    developer.log(message, name: tag, level: 800);
  }

  static void warning(String tag, String message) {
    developer.log('[WARN] $message', name: tag, level: 900);
  }

  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      '[ERROR] $message',
      name: tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void ble(String message) => info('BLE', message);
  static void bleError(String message, [Object? error, StackTrace? stackTrace]) =>
      AppLogger.error('BLE', message, error, stackTrace);

  static void firebase(String message) => info('Firebase', message);
  static void firebaseError(String message, [Object? error, StackTrace? stackTrace]) =>
      AppLogger.error('Firebase', message, error, stackTrace);

  static void hive(String message) => info('Hive', message);

  static void attendance(String message) => info('Attendance', message);
  static void attendanceError(String message, [Object? error, StackTrace? stackTrace]) =>
      AppLogger.error('Attendance', message, error, stackTrace);

  static void lifecycle(String message) => info('Lifecycle', message);
}
