import 'app_user_role.dart';

DateTime _parseDate(dynamic raw) {
  if (raw is DateTime) {
    return raw;
  }

  if (raw != null) {
    try {
      final dynamic value = raw;
      final converted = value.toDate();
      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {}
  }

  final asString = (raw ?? '').toString();
  return DateTime.tryParse(asString) ?? DateTime.now();
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.tenantId,
    required this.role,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.isActive = true,
    this.requestedRole,
    this.teacherApproved = true,
    this.rollNumber,
    this.employeeId,
    this.department,
    this.designation,
  });

  final String uid;
  final String tenantId;
  final AppUserRole role;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final bool isActive;
  final String? requestedRole;
  final bool teacherApproved;
  final String? rollNumber;
  final String? employeeId;
  final String? department;
  final String? designation;

  AppUser copyWith({
    String? uid,
    String? tenantId,
    AppUserRole? role,
    String? displayName,
    String? email,
    DateTime? createdAt,
    bool? isActive,
    String? requestedRole,
    bool? teacherApproved,
    String? rollNumber,
    String? employeeId,
    String? department,
    String? designation,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      tenantId: tenantId ?? this.tenantId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      requestedRole: requestedRole ?? this.requestedRole,
      teacherApproved: teacherApproved ?? this.teacherApproved,
      rollNumber: rollNumber ?? this.rollNumber,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      designation: designation ?? this.designation,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'tenantId': tenantId,
      'role': role.name,
      'displayName': displayName,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'requestedRole': requestedRole,
      'teacherApproved': teacherApproved,
      'rollNumber': rollNumber,
      'employeeId': employeeId,
      'department': department,
      'designation': designation,
    };
  }

  factory AppUser.fromJson(Map<dynamic, dynamic> json) {
    return AppUser(
      uid: (json['uid'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      role: AppUserRoleX.fromValue((json['role'] ?? '').toString()),
      displayName: (json['displayName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      createdAt: _parseDate(json['createdAt']),
      isActive: json['isActive'] != false,
      requestedRole: json['requestedRole']?.toString(),
      teacherApproved: json['teacherApproved'] != false,
      rollNumber: json['rollNumber']?.toString(),
      employeeId: json['employeeId']?.toString(),
      department: json['department']?.toString(),
      designation: json['designation']?.toString(),
    );
  }
}
