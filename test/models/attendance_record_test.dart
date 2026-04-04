import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/attendance_record.dart';

void main() {
  test('serializes attendance record with students', () {
    final record = AttendanceRecord(
      id: 'CSE-A-DBMS-1234',
      classId: 'CSE-A-DBMS',
      classLabel: 'DBMS (CSE-A)',
      createdAt: DateTime(2026, 3, 31, 10, 0),
      teacherId: 'teacher_1',
      students: [
        AttendanceStudent(
          rollNumber: 'CSE23A001',
          name: 'Student 1',
          rssi: -60,
          detectedAt: DateTime(2026, 3, 31, 9, 59),
        ),
        AttendanceStudent(
          rollNumber: 'CSE23A002',
          name: 'Student 2',
          rssi: -63,
          detectedAt: DateTime(2026, 3, 31, 9, 59),
        ),
      ],
      synced: false,
    );

    final restored = AttendanceRecord.fromJson(record.toJson());

    expect(restored.id, record.id);
    expect(restored.classId, record.classId);
    expect(restored.teacherId, record.teacherId);
    expect(restored.presentCount, 2);
    expect(restored.students.first.rollNumber, 'CSE23A001');
  });

  test('copyWith updates sync values', () {
    final original = AttendanceRecord(
      id: 'id_1',
      classId: 'class_1',
      classLabel: 'Class',
      createdAt: DateTime(2026, 3, 31, 10),
      teacherId: 'teacher',
      students: const [],
      synced: false,
    );

    final updated = original.copyWith(synced: true, cloudDocId: 'cloud_1');

    expect(updated.synced, isTrue);
    expect(updated.cloudDocId, 'cloud_1');
  });
}
