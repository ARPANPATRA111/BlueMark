import 'package:hive_flutter/hive_flutter.dart';

import '../core/utils/app_logger.dart';
import '../models/app_user_role.dart';
import '../models/attendance_record.dart';
import '../models/class_room.dart';
import '../models/student_attendance_status.dart';
import '../models/student_profile.dart';

class HiveService {
  HiveService._();

  static final HiveService instance = HiveService._();

  static const String _settingsBoxName = 'settings_box';
  static const String _studentBoxName = 'student_box';
  static const String _classBoxName = 'class_box';
  static const String _attendanceBoxName = 'attendance_box';
  static const String _studentDirectoryBoxName = 'student_directory_box';

  static const String _roleKey = 'role';
  static const String _studentProfileKey = 'student_profile';
  static const String _studentReadyKey = 'student_ready';
  static const String _classListKey = 'class_list';
  static const String _timelinePrefix = 'timeline_';
  static const String _activeSessionPrefix = 'active_session_';

  late final Box<dynamic> _settingsBox;
  late final Box<dynamic> _studentBox;
  late final Box<dynamic> _classBox;
  late final Box<dynamic> _attendanceBox;
  late final Box<dynamic> _studentDirectoryBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await Hive.initFlutter();
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);
    _studentBox = await Hive.openBox<dynamic>(_studentBoxName);
    _classBox = await Hive.openBox<dynamic>(_classBoxName);
    _attendanceBox = await Hive.openBox<dynamic>(_attendanceBoxName);
    _studentDirectoryBox = await Hive.openBox<dynamic>(_studentDirectoryBoxName);

    if (_classBox.get(_classListKey) == null) {
      await saveClassRooms(_defaultClassRooms);
    }

    _initialized = true;
    AppLogger.hive('Hive initialized – 5 boxes opened');
  }

  AppUserRole getRole() {
    final raw = _settingsBox.get(_roleKey)?.toString();
    return AppUserRoleX.fromValue(raw);
  }

  Future<void> saveRole(AppUserRole role) async {
    await _settingsBox.put(_roleKey, role.name);
  }

  StudentProfile? getStudentProfile() {
    final raw = _studentBox.get(_studentProfileKey);
    if (raw is Map) {
      return StudentProfile.fromJson(raw);
    }
    return null;
  }

  Future<void> saveStudentProfile(StudentProfile profile) async {
    await _studentBox.put(_studentProfileKey, profile.toJson());
    await upsertStudentDirectory(rollNumber: profile.rollNumber, name: profile.name);
  }

  bool isStudentRollRegistered(String rollNumber) {
    final current = getStudentProfile();
    if (current != null && current.rollNumber.toUpperCase() == rollNumber.trim().toUpperCase()) {
      return true;
    }
    return _studentDirectoryBox.containsKey(rollNumber.trim().toUpperCase());
  }

  bool getStudentReady() {
    return _studentBox.get(_studentReadyKey, defaultValue: false) == true;
  }

  Future<void> saveStudentReady(bool value) async {
    await _studentBox.put(_studentReadyKey, value);
  }

  List<ClassRoom> getClassRooms() {
    final raw = _classBox.get(_classListKey);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => ClassRoom.fromJson(e))
          .toList(growable: false);
    }
    return _defaultClassRooms;
  }

  Future<void> saveClassRooms(List<ClassRoom> classes) async {
    await _classBox.put(_classListKey, classes.map((e) => e.toJson()).toList(growable: false));
  }

  Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    await _attendanceBox.put(record.id, record.toJson());
  }

  List<AttendanceRecord> getAttendanceHistory() {
    final records = _attendanceBox.values
        .whereType<Map>()
        .map((e) => AttendanceRecord.fromJson(e))
        .toList();

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  List<AttendanceRecord> getPendingAttendance() {
    return getAttendanceHistory().where((e) => !e.synced).toList(growable: false);
  }

  Future<void> markAttendanceSynced(String id, {String? cloudDocId}) async {
    final raw = _attendanceBox.get(id);
    if (raw is! Map) {
      return;
    }

    final current = AttendanceRecord.fromJson(raw);
    final updated = current.copyWith(synced: true, cloudDocId: cloudDocId);
    await _attendanceBox.put(id, updated.toJson());
  }

  Future<void> saveActiveSession({
    required String classId,
    required String sessionId,
    required DateTime startedAt,
  }) async {
    await _settingsBox.put('$_activeSessionPrefix$classId', <String, dynamic>{
      'sessionId': sessionId,
      'startedAt': startedAt.toIso8601String(),
    });
  }

  Map<String, dynamic>? getActiveSession(String classId) {
    final raw = _settingsBox.get('$_activeSessionPrefix$classId');
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    return null;
  }

  Future<void> clearActiveSession(String classId) async {
    await _settingsBox.delete('$_activeSessionPrefix$classId');
  }

  Future<void> saveStudentTimeline(
    String rollNumber,
    List<StudentAttendanceStatus> records,
  ) async {
    await _studentBox.put(
      '$_timelinePrefix${rollNumber.trim().toUpperCase()}',
      records.map((e) => e.toJson()).toList(growable: false),
    );
  }

  List<StudentAttendanceStatus> getStudentTimeline(String rollNumber) {
    final raw = _studentBox.get('$_timelinePrefix${rollNumber.trim().toUpperCase()}');
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((e) => StudentAttendanceStatus.fromJson(e))
        .toList(growable: false);
  }

  Map<String, String> getStudentDirectory() {
    final map = <String, String>{};
    for (final key in _studentDirectoryBox.keys) {
      final name = _studentDirectoryBox.get(key)?.toString();
      if (name != null && name.isNotEmpty) {
        map[key.toString()] = name;
      }
    }
    return map;
  }

  Future<void> upsertStudentDirectory({
    required String rollNumber,
    required String name,
  }) async {
    if (rollNumber.trim().isEmpty || name.trim().isEmpty) {
      return;
    }
    await _studentDirectoryBox.put(rollNumber.trim().toUpperCase(), name.trim());
  }

  Future<void> mergeStudentDirectory(Map<String, String> records) async {
    if (records.isEmpty) {
      return;
    }
    await _studentDirectoryBox.putAll(records.map((key, value) {
      return MapEntry(key.trim().toUpperCase(), value.trim());
    }));
  }

  static const List<ClassRoom> _defaultClassRooms = <ClassRoom>[
    ClassRoom(id: 'CSE-A-DBMS', subject: 'DBMS', section: 'CSE-A'),
    ClassRoom(id: 'CSE-A-OS', subject: 'Operating Systems', section: 'CSE-A'),
    ClassRoom(id: 'CSE-B-CN', subject: 'Computer Networks', section: 'CSE-B'),
    ClassRoom(id: 'IT-A-ML', subject: 'Machine Learning', section: 'IT-A'),
    ClassRoom(id: 'ECE-A-DSP', subject: 'Digital Signal Processing', section: 'ECE-A'),
  ];
}
