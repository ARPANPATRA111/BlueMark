import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../models/attendance_record.dart';
import '../../../models/class_room.dart';
import '../../../models/student_attendance_status.dart';
import '../../../models/student_profile.dart';
import '../../../services/ble_service.dart';
import '../../../services/firebase_service.dart';
import '../../../services/hive_service.dart';

class AttendanceSessionResult {
  const AttendanceSessionResult({
    required this.sessionId,
    required this.startedAt,
    required this.duplicateDetected,
    this.duplicateRecord,
  });

  final String sessionId;
  final DateTime startedAt;
  final bool duplicateDetected;
  final AttendanceRecord? duplicateRecord;
}

class AttendanceRepository {
  AttendanceRepository({
    required HiveService hiveService,
    required FirebaseService firebaseService,
    required Connectivity connectivity,
  })  : _hive = hiveService,
        _firebase = firebaseService,
        _connectivity = connectivity;

  final HiveService _hive;
  final FirebaseService _firebase;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _syncSubscription;

  Future<void> startAutoSync() async {
    await syncPendingRecords();
    _syncSubscription ??= _connectivity.onConnectivityChanged.listen((results) async {
      final hasNetwork = results.any((result) => result != ConnectivityResult.none);
      if (hasNetwork) {
        await syncPendingRecords();
      }
    });
  }

  Future<void> stopAutoSync() async {
    await _syncSubscription?.cancel();
    _syncSubscription = null;
  }

  Future<AttendanceSessionResult> startSession({
    required ClassRoom classRoom,
    required int duplicateWindowMinutes,
    bool force = false,
  }) async {
    final active = _hive.getActiveSession(classRoom.id);
    if (active != null) {
      final sessionId = (active['sessionId'] ?? '').toString();
      final startedAt = DateTime.tryParse((active['startedAt'] ?? '').toString());
      if (sessionId.isNotEmpty && startedAt != null) {
        return AttendanceSessionResult(
          sessionId: sessionId,
          startedAt: startedAt,
          duplicateDetected: false,
        );
      }
    }

    AttendanceRecord? duplicate;
    if (!force) {
      final latestClassRecord = _hive
          .getAttendanceHistory()
          .where((r) => r.classId == classRoom.id)
          .cast<AttendanceRecord?>()
          .firstWhere((_) => true, orElse: () => null);

      if (latestClassRecord != null) {
        final age = DateTime.now().difference(latestClassRecord.createdAt).inMinutes;
        if (age <= duplicateWindowMinutes) {
          duplicate = latestClassRecord;
        }
      }
    }

    if (duplicate != null && !force) {
      return AttendanceSessionResult(
        sessionId: duplicate.sessionId,
        startedAt: duplicate.createdAt,
        duplicateDetected: true,
        duplicateRecord: duplicate,
      );
    }

    final sessionId = '${classRoom.id}-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999).toString().padLeft(4, '0')}';
    final startedAt = DateTime.now();

    await _hive.saveActiveSession(
      classId: classRoom.id,
      sessionId: sessionId,
      startedAt: startedAt,
    );

    await _firebase.upsertActiveSession(
      sessionId: sessionId,
      classId: classRoom.id,
      classLabel: classRoom.label,
      startedAt: startedAt,
    );

    return AttendanceSessionResult(
      sessionId: sessionId,
      startedAt: startedAt,
      duplicateDetected: duplicate != null,
      duplicateRecord: duplicate,
    );
  }

  Future<void> endSession(String classId) async {
    await _hive.clearActiveSession(classId);
    await _firebase.closeActiveSession(classId: classId);
  }

  Future<AttendanceRecord> saveAttendance({
    required ClassRoom classRoom,
    required String sessionId,
    List<DetectedStudent> detectedStudents = const <DetectedStudent>[],
    List<AttendanceStudent>? students,
    List<AttendanceAuditLog> auditLogs = const <AttendanceAuditLog>[],
  }) async {
    final teacherId = _firebase.teacherId;
    final now = DateTime.now();

    final resolvedStudents = students ??
        detectedStudents
            .map(
              (item) => AttendanceStudent(
                rollNumber: item.rollNumber,
                name: _hive.getStudentDirectory()[item.rollNumber] ?? 'Unknown',
                rssi: item.rssi,
                detectedAt: item.lastSeen,
              ),
            )
            .toList(growable: false);

    final id = '${classRoom.id}-${now.millisecondsSinceEpoch}-${Random().nextInt(9999).toString().padLeft(4, '0')}';

    final record = AttendanceRecord(
      id: id,
      sessionId: sessionId,
      classId: classRoom.id,
      classLabel: classRoom.label,
      createdAt: now,
      teacherId: teacherId,
      students: resolvedStudents,
      auditLogs: auditLogs,
      synced: false,
    );

    await _hive.saveAttendanceRecord(record);
    await endSession(classRoom.id);
    await syncPendingRecords();
    return record;
  }

  Future<List<AttendanceRecord>> getAttendanceHistory() async {
    return _hive.getAttendanceHistory();
  }

  Future<void> registerStudent(StudentProfile profile) async {
    await _hive.saveStudentProfile(profile);
    await _firebase.registerStudentProfile(profile);
  }

  Future<void> refreshStudentDirectory() async {
    final cloudDirectory = await _firebase.fetchStudentDirectory();
    await _hive.mergeStudentDirectory(cloudDirectory);
  }

  Future<void> syncPendingRecords() async {
    final pending = _hive.getPendingAttendance();
    if (pending.isNotEmpty) {
      for (final record in pending) {
        try {
          final cloudId = await _firebase.syncAttendanceRecord(record);
          if (cloudId != null) {
            await _hive.markAttendanceSynced(record.id, cloudDocId: cloudId);
          }
        } catch (_) {}
      }
    }

    try {
      await refreshStudentDirectory();
    } catch (_) {}
  }

  Future<List<StudentAttendanceStatus>> getStudentTimeline(
    String rollNumber, {
    bool refreshCloud = true,
  }) async {
    final local = _hive.getStudentTimeline(rollNumber);
    if (!refreshCloud || !_firebase.isEnabled) {
      return local;
    }

    try {
      final cloud = await _firebase.watchStudentAttendanceTimeline(rollNumber).first;
      if (cloud.isNotEmpty) {
        await _hive.saveStudentTimeline(rollNumber, cloud);
        return cloud;
      }
    } catch (_) {}

    return local;
  }
}
