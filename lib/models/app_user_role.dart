enum AppUserRole { unknown, admin, teacher, pendingTeacher, student }

extension AppUserRoleX on AppUserRole {
  static AppUserRole fromValue(String? value) {
    switch (value) {
      case 'admin':
        return AppUserRole.admin;
      case 'teacher':
        return AppUserRole.teacher;
      case 'pendingTeacher':
        return AppUserRole.pendingTeacher;
      case 'student':
        return AppUserRole.student;
      default:
        return AppUserRole.unknown;
    }
  }

  String get label {
    switch (this) {
      case AppUserRole.admin:
        return 'Institution Admin';
      case AppUserRole.teacher:
        return 'Teacher';
      case AppUserRole.pendingTeacher:
        return 'Teacher (Pending Approval)';
      case AppUserRole.student:
        return 'Student';
      case AppUserRole.unknown:
        return 'Select Role';
    }
  }
}
