import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/student_attendance_status.dart';

void main() {
  group('StudentAttendanceStatus', () {
    final status = StudentAttendanceStatus(
      rollNumber: 'CSE23A001',
      recordId: 'rec-1',
      sessionId: 'sess-1',
      classId: 'CSE-A-DBMS',
      classLabel: 'DBMS (CSE-A)',
      markedAt: DateTime(2026, 4, 15, 10, 30),
      teacherId: 'teacher-1',
      teacherName: 'Dr. Smith',
      isPresent: true,
    );

    test('toJson serializes all fields', () {
      final json = status.toJson();
      expect(json['rollNumber'], 'CSE23A001');
      expect(json['recordId'], 'rec-1');
      expect(json['sessionId'], 'sess-1');
      expect(json['classId'], 'CSE-A-DBMS');
      expect(json['classLabel'], 'DBMS (CSE-A)');
      expect(json['teacherId'], 'teacher-1');
      expect(json['teacherName'], 'Dr. Smith');
      expect(json['isPresent'], isTrue);
      expect(json['markedAt'], isA<String>());
    });

    test('fromJson round-trips correctly', () {
      final restored = StudentAttendanceStatus.fromJson(status.toJson());
      expect(restored.rollNumber, status.rollNumber);
      expect(restored.recordId, status.recordId);
      expect(restored.sessionId, status.sessionId);
      expect(restored.classId, status.classId);
      expect(restored.classLabel, status.classLabel);
      expect(restored.teacherId, status.teacherId);
      expect(restored.teacherName, status.teacherName);
      expect(restored.isPresent, status.isPresent);
      expect(restored.markedAt.year, 2026);
    });

    test('fromJson handles missing fields', () {
      final minimal = StudentAttendanceStatus.fromJson(<String, dynamic>{});
      expect(minimal.rollNumber, isEmpty);
      expect(minimal.recordId, isEmpty);
      expect(minimal.isPresent, isFalse);
    });
  });
}
