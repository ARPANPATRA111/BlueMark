import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attendance/repository/attendance_repository.dart';
import '../../models/active_attendance_session.dart';
import '../../models/app_user.dart';
import '../../models/app_user_role.dart';
import '../../models/class_room.dart';
import '../../models/student_profile.dart';
import '../../models/tenant_student.dart';
import '../../services/ble_service.dart';
import '../../services/firebase_service.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';
import '../../services/permission_service.dart';
import '../../services/app_settings_service.dart';

final hiveServiceProvider = Provider<HiveService>((ref) => HiveService.instance);
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService.instance);
final bleServiceProvider = Provider<BleService>((ref) => BleService.instance);
final permissionServiceProvider = Provider<PermissionService>((ref) => PermissionService());
final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) => AppSettingsService.instance);
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(firebaseServiceProvider).authStateChanges();
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.read(firebaseServiceProvider).watchCurrentAppUser();
});

final activeAttendanceSessionProvider = StreamProvider<ActiveAttendanceSession?>((ref) {
  return ref.read(firebaseServiceProvider).watchLatestActiveSession();
});

final tenantUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.read(firebaseServiceProvider).watchTenantUsers();
});

final tenantStudentsProvider = StreamProvider<List<TenantStudent>>((ref) {
  return ref.read(firebaseServiceProvider).watchTenantStudents();
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    hiveService: ref.read(hiveServiceProvider),
    firebaseService: ref.read(firebaseServiceProvider),
    connectivity: ref.read(connectivityProvider),
  );
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final hive = ref.read(hiveServiceProvider);
  final firebase = ref.read(firebaseServiceProvider);
  final repository = ref.read(attendanceRepositoryProvider);
  final settings = ref.read(appSettingsServiceProvider);
  final notifications = ref.read(notificationServiceProvider);

  await hive.init();
  await settings.init();
  await firebase.init();
  await notifications.init();
  await repository.startAutoSync();
});

class AppRoleController extends StateNotifier<AppUserRole> {
  AppRoleController(this._hive) : super(_hive.getRole());

  final HiveService _hive;

  Future<void> setRole(AppUserRole role) async {
    state = role;
    await _hive.saveRole(role);
  }
}

final appRoleProvider = StateNotifierProvider<AppRoleController, AppUserRole>((ref) {
  return AppRoleController(ref.read(hiveServiceProvider));
});

final studentProfileProvider = StateProvider<StudentProfile?>((ref) {
  return ref.read(hiveServiceProvider).getStudentProfile();
});

final studentReadyProvider = StateProvider<bool>((ref) {
  return ref.read(hiveServiceProvider).getStudentReady();
});

final classRoomsProvider = StateProvider<List<ClassRoom>>((ref) {
  return ref.read(hiveServiceProvider).getClassRooms();
});

final studentDirectoryProvider = StateProvider<Map<String, String>>((ref) {
  return ref.read(hiveServiceProvider).getStudentDirectory();
});
