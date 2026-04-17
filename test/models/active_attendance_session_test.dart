import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/active_attendance_session.dart';

void main() {
  group('ActiveAttendanceSession', () {
    final session = ActiveAttendanceSession(
      id: 'session-1',
      classId: 'CSE-A-DBMS',
      classLabel: 'DBMS (CSE-A)',
      teacherId: 'teacher-1',
      teacherName: 'Dr. Smith',
      startedAt: DateTime(2026, 4, 15, 10, 0),
      isActive: true,
    );

    test('toJson serializes all fields', () {
      final json = session.toJson();
      expect(json['id'], 'session-1');
      expect(json['classId'], 'CSE-A-DBMS');
      expect(json['classLabel'], 'DBMS (CSE-A)');
      expect(json['teacherId'], 'teacher-1');
      expect(json['teacherName'], 'Dr. Smith');
      expect(json['isActive'], isTrue);
      expect(json['startedAt'], isA<String>());
    });

    test('fromJson round-trips correctly', () {
      final restored = ActiveAttendanceSession.fromJson(session.toJson());
      expect(restored.id, session.id);
      expect(restored.classId, session.classId);
      expect(restored.classLabel, session.classLabel);
      expect(restored.teacherId, session.teacherId);
      expect(restored.teacherName, session.teacherName);
      expect(restored.isActive, session.isActive);
      expect(restored.startedAt.year, 2026);
      expect(restored.startedAt.month, 4);
    });

    test('fromJson handles missing fields gracefully', () {
      final minimal = ActiveAttendanceSession.fromJson(<String, dynamic>{});
      expect(minimal.id, isEmpty);
      expect(minimal.classId, isEmpty);
      expect(minimal.isActive, isFalse);
    });

    test('fromJson parses ISO 8601 date strings', () {
      final json = <String, dynamic>{
        'id': 'x',
        'classId': 'c',
        'classLabel': 'l',
        'teacherId': 't',
        'teacherName': 'n',
        'startedAt': '2026-04-15T10:00:00.000',
        'isActive': true,
      };
      final parsed = ActiveAttendanceSession.fromJson(json);
      expect(parsed.startedAt.year, 2026);
      expect(parsed.startedAt.month, 4);
      expect(parsed.startedAt.day, 15);
    });
  });
}
