import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/tenant_student.dart';

void main() {
  group('TenantStudent', () {
    final student = TenantStudent(
      rollNumber: 'CSE23A001',
      name: 'Alice',
      section: 'CSE-A',
      linkedUserId: 'user-1',
      updatedAt: DateTime(2026, 4, 15),
    );

    test('toJson serializes all fields', () {
      final json = student.toJson();
      expect(json['rollNumber'], 'CSE23A001');
      expect(json['name'], 'Alice');
      expect(json['section'], 'CSE-A');
      expect(json['linkedUserId'], 'user-1');
      expect(json['updatedAt'], isA<String>());
    });

    test('fromJson round-trips correctly', () {
      final restored = TenantStudent.fromJson(student.toJson());
      expect(restored.rollNumber, student.rollNumber);
      expect(restored.name, student.name);
      expect(restored.section, student.section);
      expect(restored.linkedUserId, student.linkedUserId);
      expect(restored.updatedAt.year, 2026);
    });

    test('fromJson handles null linkedUserId', () {
      final json = <String, dynamic>{
        'rollNumber': 'CSE23A002',
        'name': 'Bob',
        'section': 'CSE-A',
        'updatedAt': '2026-04-15T00:00:00.000',
      };
      final parsed = TenantStudent.fromJson(json);
      expect(parsed.linkedUserId, isNull);
    });

    test('fromJson handles missing fields', () {
      final empty = TenantStudent.fromJson(<String, dynamic>{});
      expect(empty.rollNumber, isEmpty);
      expect(empty.name, isEmpty);
      expect(empty.section, isEmpty);
      expect(empty.linkedUserId, isNull);
    });
  });
}
