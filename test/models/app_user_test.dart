import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/app_user.dart';
import 'package:bluetooth_attendance_tracker/models/app_user_role.dart';

void main() {
  group('AppUser', () {
    final user = AppUser(
      uid: 'uid-1',
      tenantId: 'DEMO_INSTITUTE',
      role: AppUserRole.teacher,
      displayName: 'Jane Teacher',
      email: 'jane@example.com',
      createdAt: DateTime(2026, 4, 15),
      isActive: true,
      requestedRole: 'teacher',
      teacherApproved: true,
      employeeId: 'EMP001',
      department: 'CSE',
    );

    test('toJson serializes all fields', () {
      final json = user.toJson();
      expect(json['uid'], 'uid-1');
      expect(json['tenantId'], 'DEMO_INSTITUTE');
      expect(json['role'], 'teacher');
      expect(json['displayName'], 'Jane Teacher');
      expect(json['email'], 'jane@example.com');
      expect(json['isActive'], isTrue);
      expect(json['requestedRole'], 'teacher');
      expect(json['teacherApproved'], isTrue);
      expect(json['employeeId'], 'EMP001');
      expect(json['department'], 'CSE');
    });

    test('fromJson round-trips correctly', () {
      final restored = AppUser.fromJson(user.toJson());
      expect(restored.uid, user.uid);
      expect(restored.tenantId, user.tenantId);
      expect(restored.role, user.role);
      expect(restored.displayName, user.displayName);
      expect(restored.email, user.email);
      expect(restored.isActive, user.isActive);
      expect(restored.employeeId, user.employeeId);
    });

    test('copyWith updates only specified fields', () {
      final updated = user.copyWith(displayName: 'Updated Name', isActive: false);
      expect(updated.displayName, 'Updated Name');
      expect(updated.isActive, isFalse);
      expect(updated.uid, user.uid);
      expect(updated.tenantId, user.tenantId);
      expect(updated.role, user.role);
    });

    test('fromJson handles student role with roll number', () {
      final studentJson = <String, dynamic>{
        'uid': 's1',
        'tenantId': 'T1',
        'role': 'student',
        'displayName': 'Student A',
        'email': 'student@example.com',
        'createdAt': '2026-04-15T00:00:00.000',
        'isActive': true,
        'rollNumber': 'CSE23A001',
      };
      final student = AppUser.fromJson(studentJson);
      expect(student.role, AppUserRole.student);
      expect(student.rollNumber, 'CSE23A001');
    });

    test('fromJson handles unknown role gracefully', () {
      final json = <String, dynamic>{
        'uid': 'x',
        'tenantId': 'T',
        'role': 'nonexistent_role',
        'displayName': 'X',
        'email': 'x@x.com',
        'createdAt': '2026-01-01T00:00:00.000',
      };
      final parsed = AppUser.fromJson(json);
      expect(parsed.role, AppUserRole.unknown);
    });
  });
}
