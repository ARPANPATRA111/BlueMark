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
  });

  final String uid;
  final String tenantId;
  final AppUserRole role;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final bool isActive;

  AppUser copyWith({
    String? uid,
    String? tenantId,
    AppUserRole? role,
    String? displayName,
    String? email,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      tenantId: tenantId ?? this.tenantId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
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
    );
  }
}
