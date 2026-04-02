import 'active_attendance_session.dart';
import 'student_attendance_status.dart';

class StudentTrackingState {
  const StudentTrackingState({
    required this.isReady,
    required this.activeSession,
    required this.latestStatus,
  });

  final bool isReady;
  final ActiveAttendanceSession? activeSession;
  final StudentAttendanceStatus? latestStatus;

  bool get isCurrentlyTracked {
    return isReady && activeSession != null;
  }

  bool get isMarkedForActiveSession {
    final session = activeSession;
    final status = latestStatus;
    if (session == null || status == null) {
      return false;
    }
    return status.recordId == session.id;
  }
}
