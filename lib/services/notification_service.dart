import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showAttendanceMarked({
    required String classLabel,
    required String markedAt,
    String? teacherName,
  }) async {
    await init();

    const android = AndroidNotificationDetails(
      'attendance_updates',
      'Attendance Updates',
      channelDescription: 'Shows attendance status updates for students',
      importance: Importance.high,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 2147483000,
      'Attendance Marked Present',
      '${teacherName != null && teacherName.trim().isNotEmpty ? 'Teacher: $teacherName • ' : ''}$classLabel • $markedAt',
      details,
    );
  }
}
