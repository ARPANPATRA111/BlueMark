import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/app_user_role.dart';

void main() {
  group('AppUserRoleX.fromValue', () {
    test('returns admin for admin value', () {
      expect(AppUserRoleX.fromValue('admin'), AppUserRole.admin);
    });

    test('returns teacher for teacher value', () {
      expect(AppUserRoleX.fromValue('teacher'), AppUserRole.teacher);
    });

    test('returns student for student value', () {
      expect(AppUserRoleX.fromValue('student'), AppUserRole.student);
    });

    test('returns unknown for invalid value', () {
      expect(AppUserRoleX.fromValue('other'), AppUserRole.unknown);
      expect(AppUserRoleX.fromValue(null), AppUserRole.unknown);
    });
  });

  test('has stable labels', () {
    expect(AppUserRole.admin.label, 'Institution Admin');
    expect(AppUserRole.teacher.label, 'Teacher');
    expect(AppUserRole.student.label, 'Student');
    expect(AppUserRole.unknown.label, 'Select Role');
  });
}
