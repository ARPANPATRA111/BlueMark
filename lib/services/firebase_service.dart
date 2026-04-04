import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/active_attendance_session.dart';
import '../models/app_user.dart';
import '../models/app_user_role.dart';
import '../models/attendance_record.dart';
import '../models/student_attendance_status.dart';
import '../models/student_profile.dart';
import '../models/tenant_student.dart';

class _FirebaseContext {
  const _FirebaseContext({
    required this.uid,
    required this.tenantId,
    required this.role,
    required this.displayName,
  });

  final String uid;
  final String tenantId;
  final AppUserRole role;
  final String displayName;
}

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();
  static const String demoAdminEmail = 'demo.admin@bluemark.app';
  static const String demoAdminPassword = 'BlueMark@12345';
  static const String demoAdminTenantCode = 'DEMO_INSTITUTE';
  static const String demoAdminName = 'Demo Institute Admin';

  bool _enabled = false;

  bool get isEnabled => _enabled;

  User? get currentAuthUser => _enabled ? FirebaseAuth.instance.currentUser : null;

  String get teacherId {
    return currentAuthUser?.uid ?? 'offline_teacher';
  }

  Stream<User?> authStateChanges() {
    if (!_enabled) {
      return Stream<User?>.value(null);
    }
    return FirebaseAuth.instance.authStateChanges();
  }

  Future<void> init() async {
    if (_enabled) {
      return;
    }

    try {
      await Firebase.initializeApp();
      _enabled = true;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Firebase init failed: ${error.code} ${error.message}\n$stackTrace');
      _enabled = false;
    } catch (error, stackTrace) {
      debugPrint('Firebase init skipped: $error\n$stackTrace');
      _enabled = false;
    }
  }

  Future<void> ensureDummyAdminAccount() async {
    if (!_enabled) {
      return;
    }

    if (FirebaseAuth.instance.currentUser != null) {
      return;
    }

    try {
      final created = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: demoAdminEmail,
        password: demoAdminPassword,
      );

      final user = created.user;
      if (user != null) {
        await user.updateDisplayName(demoAdminName);
        await _upsertDummyAdminProfile(user.uid);
      }
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        try {
          final existing = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: demoAdminEmail,
            password: demoAdminPassword,
          );
          final user = existing.user;
          if (user != null) {
            await _upsertDummyAdminProfile(user.uid);
          }
          await FirebaseAuth.instance.signOut();
        } on FirebaseAuthException catch (_) {}
        return;
      }

      if (error.code == 'network-request-failed') {
        return;
      }
    }
  }

  Future<void> _upsertDummyAdminProfile(String uid) {
    return _userDoc(uid).set(<String, dynamic>{
      'uid': uid,
      'tenantId': demoAdminTenantCode,
      'role': AppUserRole.admin.name,
      'requestedRole': AppUserRole.admin.name,
      'teacherApproved': true,
      'displayName': demoAdminName,
      'email': demoAdminEmail,
      'designation': 'System Admin',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (!_enabled) {
      throw Exception('Firebase is not configured on this build.');
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyAuthMessage(error, isRegistration: false));
    }
  }

  Future<void> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    required String tenantId,
    required AppUserRole role,
    String? studentRollNumber,
    String? teacherEmployeeId,
    String? teacherDepartment,
    String? adminDesignation,
  }) async {
    if (!_enabled) {
      throw Exception('Firebase is not configured on this build.');
    }

    final AppUserRole effectiveRole =
        role == AppUserRole.teacher ? AppUserRole.pendingTeacher : role;

    final UserCredential credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyAuthMessage(error, isRegistration: true));
    }

    final user = credential.user;
    if (user == null) {
      throw Exception('User creation failed.');
    }

    if (displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }

    final normalizedTenant = tenantId.trim().toUpperCase();
    final profile = AppUser(
      uid: user.uid,
      tenantId: normalizedTenant,
      role: effectiveRole,
      displayName: displayName.trim(),
      email: email.trim().toLowerCase(),
      createdAt: DateTime.now(),
      isActive: true,
      requestedRole: role.name,
      teacherApproved: effectiveRole != AppUserRole.pendingTeacher,
      rollNumber: studentRollNumber?.trim().toUpperCase(),
      employeeId: teacherEmployeeId?.trim(),
      department: teacherDepartment?.trim(),
      designation: adminDesignation?.trim(),
    );

    await _userDoc(user.uid).set(<String, dynamic>{
      ...profile.toJson(),
      'approvedAt': effectiveRole == AppUserRole.pendingTeacher ? null : FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    if (!_enabled) {
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  Future<AppUser?> fetchCurrentAppUser() async {
    if (!_enabled) {
      return null;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return null;
    }

    final snap = await _userDoc(authUser.uid).get();
    final data = snap.data();
    if (data == null) {
      return null;
    }

    return AppUser.fromJson(data);
  }

  Stream<AppUser?> watchCurrentAppUser() {
    if (!_enabled) {
      return Stream<AppUser?>.value(null);
    }

    return FirebaseAuth.instance.authStateChanges().asyncExpand((authUser) {
      if (authUser == null) {
        return Stream<AppUser?>.value(null);
      }

      return _userDoc(authUser.uid).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) {
          return null;
        }
        return AppUser.fromJson(data);
      });
    });
  }

  Stream<List<AppUser>> watchTenantUsers() async* {
    final context = await _contextOrNull();
    if (context == null || context.role != AppUserRole.admin) {
      yield const <AppUser>[];
      return;
    }

    final query = _usersCollection
        .where('tenantId', isEqualTo: context.tenantId)
        .orderBy('displayName')
        .limit(500);

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromJson(doc.data())).toList(growable: false);
    });
  }

  Future<void> updateTenantUserRole({
    required String userId,
    required AppUserRole role,
  }) async {
    final context = await _contextOrNull();
    if (context == null || context.role != AppUserRole.admin) {
      throw Exception('Only institution admins can modify user roles.');
    }

    final payload = <String, dynamic>{
      'role': role.name,
      'requestedRole': role == AppUserRole.pendingTeacher ? AppUserRole.teacher.name : role.name,
      'teacherApproved': role == AppUserRole.teacher,
      'approvedAt': role == AppUserRole.teacher ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _userDoc(userId).set(payload, SetOptions(merge: true));
  }

  String _friendlyAuthMessage(
    FirebaseAuthException error, {
    required bool isRegistration,
  }) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Network error occurred. Please check internet access and retry.';
      case 'invalid-api-key':
        return 'Firebase API key is invalid for this build. Update local Firebase config.';
      case 'invalid-credential':
        return isRegistration
            ? 'Registration failed due to invalid auth configuration. Contact admin.'
            : 'Invalid email or password.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'operation-not-allowed':
        return 'Email/password auth is disabled in Firebase project settings.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<void> setTenantUserActive({
    required String userId,
    required bool isActive,
  }) async {
    final context = await _contextOrNull();
    if (context == null || context.role != AppUserRole.admin) {
      throw Exception('Only institution admins can activate/deactivate users.');
    }

    await _userDoc(userId).set(<String, dynamic>{
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> registerStudentProfile(StudentProfile profile) async {
    final context = await _contextOrNull();
    if (context == null) {
      return;
    }

    final roll = profile.rollNumber.toUpperCase();
    final doc = _tenantCollection(context.tenantId, AppConstants.studentCollection).doc(roll);

    await doc.set(<String, dynamic>{
      'rollNumber': roll,
      'name': profile.name,
      'section': '',
      'tenantId': context.tenantId,
      'linkedUserId': context.role == AppUserRole.student ? context.uid : null,
      'photoPath': profile.photoPath,
      'lastAttendanceStatus': null,
      'lastAttendanceRecordId': null,
      'lastAttendanceSessionId': null,
      'lastAttendanceMarkedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (context.role == AppUserRole.student) {
      await _userDoc(context.uid).set(<String, dynamic>{
        'rollNumber': roll,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<String?> syncAttendanceRecord(AttendanceRecord record) async {
    final context = await _contextOrNull();
    if (context == null) {
      return null;
    }

    final collection = _tenantCollection(context.tenantId, AppConstants.attendanceCollection);
    final docRef = record.cloudDocId != null && record.cloudDocId!.isNotEmpty
        ? collection.doc(record.cloudDocId)
        : collection.doc(record.id);

    await docRef.set(<String, dynamic>{
      'id': record.id,
      'tenantId': context.tenantId,
      'sessionId': record.sessionId,
      'classId': record.classId,
      'classLabel': record.classLabel,
      'teacherId': context.uid,
      'teacherName': context.displayName,
      'createdAt': record.createdAt.toIso8601String(),
      'presentCount': record.presentCount,
      'students': record.students.map((e) => e.toJson()).toList(growable: false),
      'auditLogs': record.auditLogs.map((e) => e.toJson()).toList(growable: false),
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _publishAttendanceReceipts(record, context: context);
    await closeActiveSession(
      classId: record.classId,
      expectedSessionId: record.sessionId,
    );

    return docRef.id;
  }

  Future<void> _publishAttendanceReceipts(
    AttendanceRecord record, {
    required _FirebaseContext context,
  }) async {
    final firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();
    var pendingWrites = 0;

    Future<void> flushBatch() async {
      if (pendingWrites == 0) {
        return;
      }
      await batch.commit();
      batch = firestore.batch();
      pendingWrites = 0;
    }

    for (final student in record.students) {
      final roll = student.rollNumber.toUpperCase();
      final receiptId = '${record.id}_$roll';

      final receiptRef = _tenantCollection(context.tenantId, AppConstants.attendanceReceiptCollection).doc(receiptId);
      batch.set(receiptRef, <String, dynamic>{
        'id': receiptId,
        'tenantId': context.tenantId,
        'attendanceId': record.id,
        'sessionId': record.sessionId,
        'rollNumber': roll,
        'studentName': student.name,
        'classId': record.classId,
        'classLabel': record.classLabel,
        'teacherId': context.uid,
        'teacherName': context.displayName,
        'status': 'present',
        'markedAt': record.createdAt.toIso8601String(),
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      pendingWrites += 1;

      final studentRef = _tenantCollection(context.tenantId, AppConstants.studentCollection).doc(roll);
      batch.set(studentRef, <String, dynamic>{
        'rollNumber': roll,
        'name': student.name,
        'lastAttendanceStatus': 'present',
        'lastAttendanceRecordId': record.id,
        'lastAttendanceSessionId': record.sessionId,
        'lastAttendanceClassId': record.classId,
        'lastAttendanceClassLabel': record.classLabel,
        'lastAttendanceTeacherId': context.uid,
        'lastAttendanceTeacherName': context.displayName,
        'lastAttendanceMarkedAt': record.createdAt.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      pendingWrites += 1;

      if (pendingWrites >= 300) {
        await flushBatch();
      }
    }

    await flushBatch();
  }

  Stream<StudentAttendanceStatus?> watchStudentAttendanceStatus(String rollNumber) async* {
    final context = await _contextOrNull();
    if (context == null) {
      yield null;
      return;
    }

    final doc = _tenantCollection(context.tenantId, AppConstants.studentCollection).doc(rollNumber.toUpperCase());

    yield* doc.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      final lastRecordId = (data['lastAttendanceRecordId'] ?? '').toString();
      final status = (data['lastAttendanceStatus'] ?? '').toString().toLowerCase();
      final markedAtRaw = (data['lastAttendanceMarkedAt'] ?? '').toString();
      final markedAt = DateTime.tryParse(markedAtRaw);

      if (lastRecordId.isEmpty || status != 'present' || markedAt == null) {
        return null;
      }

      return StudentAttendanceStatus(
        rollNumber: rollNumber.toUpperCase(),
        recordId: lastRecordId,
        sessionId: (data['lastAttendanceSessionId'] ?? '').toString(),
        classId: (data['lastAttendanceClassId'] ?? '').toString(),
        classLabel: (data['lastAttendanceClassLabel'] ?? 'Unknown Class').toString(),
        markedAt: markedAt,
        teacherId: (data['lastAttendanceTeacherId'] ?? '').toString(),
        teacherName: (data['lastAttendanceTeacherName'] ?? '').toString(),
        isPresent: true,
      );
    });
  }

  Stream<List<StudentAttendanceStatus>> watchStudentAttendanceTimeline(String rollNumber) async* {
    final context = await _contextOrNull();
    if (context == null) {
      yield const <StudentAttendanceStatus>[];
      return;
    }

    final query = _tenantCollection(context.tenantId, AppConstants.attendanceReceiptCollection)
        .where('rollNumber', isEqualTo: rollNumber.toUpperCase())
        .orderBy('markedAt', descending: true)
        .limit(120);

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StudentAttendanceStatus(
          rollNumber: (data['rollNumber'] ?? rollNumber).toString().toUpperCase(),
          recordId: (data['attendanceId'] ?? doc.id).toString(),
          sessionId: (data['sessionId'] ?? '').toString(),
          classId: (data['classId'] ?? '').toString(),
          classLabel: (data['classLabel'] ?? 'Unknown Class').toString(),
          markedAt: DateTime.tryParse((data['markedAt'] ?? '').toString()) ?? DateTime.now(),
          teacherId: (data['teacherId'] ?? '').toString(),
          teacherName: (data['teacherName'] ?? '').toString(),
          isPresent: (data['status'] ?? 'present').toString().toLowerCase() == 'present',
        );
      }).toList(growable: false);
    });
  }

  Future<Map<String, String>> fetchStudentDirectory({int limit = 500}) async {
    final context = await _contextOrNull();
    if (context == null) {
      return <String, String>{};
    }

    final snapshot = await _tenantCollection(context.tenantId, AppConstants.studentCollection)
        .limit(limit)
        .get();

    final map = <String, String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final roll = (data['rollNumber'] ?? doc.id).toString().toUpperCase();
      final name = (data['name'] ?? 'Unknown').toString();
      if (roll.isNotEmpty && name.isNotEmpty) {
        map[roll] = name;
      }
    }
    return map;
  }

  Future<void> upsertActiveSession({
    required String sessionId,
    required String classId,
    required String classLabel,
    required DateTime startedAt,
  }) async {
    final context = await _contextOrNull();
    if (context == null) {
      return;
    }

    if (context.role != AppUserRole.teacher && context.role != AppUserRole.admin) {
      return;
    }

    final doc = _tenantCollection(context.tenantId, AppConstants.activeSessionCollection).doc(classId);
    await doc.set(<String, dynamic>{
      'id': sessionId,
      'classId': classId,
      'classLabel': classLabel,
      'teacherId': context.uid,
      'teacherName': context.displayName,
      'isActive': true,
      'startedAt': startedAt.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> closeActiveSession({
    required String classId,
    String? expectedSessionId,
  }) async {
    final context = await _contextOrNull();
    if (context == null) {
      return;
    }

    final doc = _tenantCollection(context.tenantId, AppConstants.activeSessionCollection).doc(classId);
    if (expectedSessionId != null && expectedSessionId.isNotEmpty) {
      final existing = await doc.get();
      final currentId = (existing.data()?['id'] ?? '').toString();
      if (currentId.isNotEmpty && currentId != expectedSessionId) {
        return;
      }
    }

    await doc.set(<String, dynamic>{
      'isActive': false,
      'endedAt': DateTime.now().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<ActiveAttendanceSession?> watchLatestActiveSession() async* {
    final context = await _contextOrNull();
    if (context == null) {
      yield null;
      return;
    }

    final query = _tenantCollection(context.tenantId, AppConstants.activeSessionCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('startedAt', descending: true)
        .limit(1);

    yield* query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return ActiveAttendanceSession.fromJson(snapshot.docs.first.data());
    });
  }

  Stream<List<TenantStudent>> watchTenantStudents({int limit = 600}) async* {
    final context = await _contextOrNull();
    if (context == null) {
      yield const <TenantStudent>[];
      return;
    }

    if (context.role == AppUserRole.student) {
      yield const <TenantStudent>[];
      return;
    }

    final query = _tenantCollection(context.tenantId, AppConstants.studentCollection)
        .orderBy('rollNumber')
        .limit(limit);

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TenantStudent.fromJson(doc.data())).toList(growable: false);
    });
  }

  Future<void> upsertTenantStudent(TenantStudent student) async {
    final context = await _contextOrNull();
    if (context == null) {
      return;
    }

    if (context.role != AppUserRole.admin && context.role != AppUserRole.teacher) {
      throw Exception('Only admins and teachers can manage student directory records.');
    }

    final normalizedRoll = student.rollNumber.trim().toUpperCase();
    final doc = _tenantCollection(context.tenantId, AppConstants.studentCollection).doc(normalizedRoll);
    await doc.set(<String, dynamic>{
      'rollNumber': normalizedRoll,
      'name': student.name.trim(),
      'section': student.section.trim(),
      'linkedUserId': student.linkedUserId,
      'tenantId': context.tenantId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, int>> fetchTenantStats() async {
    final context = await _contextOrNull();
    if (context == null) {
      return const <String, int>{
        'users': 0,
        'students': 0,
        'attendance': 0,
      };
    }

    final usersFuture = _usersCollection.where('tenantId', isEqualTo: context.tenantId).count().get();
    final studentsFuture = _tenantCollection(context.tenantId, AppConstants.studentCollection).count().get();
    final attendanceFuture = _tenantCollection(context.tenantId, AppConstants.attendanceCollection).count().get();

    final results = await Future.wait([usersFuture, studentsFuture, attendanceFuture]);
    return <String, int>{
      'users': results[0].count ?? 0,
      'students': results[1].count ?? 0,
      'attendance': results[2].count ?? 0,
    };
  }

  Future<_FirebaseContext?> _contextOrNull() async {
    if (!_enabled) {
      return null;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return null;
    }

    final userSnapshot = await _userDoc(authUser.uid).get();
    final data = userSnapshot.data();
    if (data == null) {
      return null;
    }

    final tenantId = (data['tenantId'] ?? '').toString();
    if (tenantId.isEmpty) {
      return null;
    }

    return _FirebaseContext(
      uid: authUser.uid,
      tenantId: tenantId,
      role: AppUserRoleX.fromValue((data['role'] ?? '').toString()),
      displayName: (data['displayName'] ?? authUser.email ?? 'Teacher').toString(),
    );
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return FirebaseFirestore.instance.collection(AppConstants.usersCollection);
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _usersCollection.doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _tenantCollection(String tenantId, String subCollection) {
    return FirebaseFirestore.instance
        .collection(AppConstants.tenantsCollection)
        .doc(tenantId)
        .collection(subCollection);
  }
}
