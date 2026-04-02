class AttendanceStudent {
  const AttendanceStudent({
    required this.rollNumber,
    required this.name,
    required this.rssi,
    required this.detectedAt,
    this.source = 'auto',
    this.markReason,
  });

  final String rollNumber;
  final String name;
  final int rssi;
  final DateTime detectedAt;
  final String source;
  final String? markReason;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rollNumber': rollNumber,
      'name': name,
      'rssi': rssi,
      'detectedAt': detectedAt.toIso8601String(),
      'source': source,
      'markReason': markReason,
    };
  }

  factory AttendanceStudent.fromJson(Map<dynamic, dynamic> json) {
    return AttendanceStudent(
      rollNumber: (json['rollNumber'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      rssi: int.tryParse((json['rssi'] ?? 0).toString()) ?? 0,
      detectedAt: DateTime.tryParse((json['detectedAt'] ?? '').toString()) ?? DateTime.now(),
      source: (json['source'] ?? 'auto').toString(),
      markReason: json['markReason']?.toString(),
    );
  }
}

class AttendanceAuditLog {
  const AttendanceAuditLog({
    required this.action,
    required this.changedAt,
    required this.changedBy,
    this.rollNumber,
    this.reason,
  });

  final String action;
  final DateTime changedAt;
  final String changedBy;
  final String? rollNumber;
  final String? reason;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'action': action,
      'changedAt': changedAt.toIso8601String(),
      'changedBy': changedBy,
      'rollNumber': rollNumber,
      'reason': reason,
    };
  }

  factory AttendanceAuditLog.fromJson(Map<dynamic, dynamic> json) {
    return AttendanceAuditLog(
      action: (json['action'] ?? '').toString(),
      changedAt: DateTime.tryParse((json['changedAt'] ?? '').toString()) ?? DateTime.now(),
      changedBy: (json['changedBy'] ?? '').toString(),
      rollNumber: json['rollNumber']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    this.sessionId = '',
    required this.classId,
    required this.classLabel,
    required this.createdAt,
    required this.teacherId,
    required this.students,
    this.auditLogs = const <AttendanceAuditLog>[],
    required this.synced,
    this.cloudDocId,
  });

  final String id;
  final String sessionId;
  final String classId;
  final String classLabel;
  final DateTime createdAt;
  final String teacherId;
  final List<AttendanceStudent> students;
  final List<AttendanceAuditLog> auditLogs;
  final bool synced;
  final String? cloudDocId;

  int get presentCount => students.length;

  AttendanceRecord copyWith({
    String? id,
    String? sessionId,
    String? classId,
    String? classLabel,
    DateTime? createdAt,
    String? teacherId,
    List<AttendanceStudent>? students,
    List<AttendanceAuditLog>? auditLogs,
    bool? synced,
    String? cloudDocId,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      classId: classId ?? this.classId,
      classLabel: classLabel ?? this.classLabel,
      createdAt: createdAt ?? this.createdAt,
      teacherId: teacherId ?? this.teacherId,
      students: students ?? this.students,
      auditLogs: auditLogs ?? this.auditLogs,
      synced: synced ?? this.synced,
      cloudDocId: cloudDocId ?? this.cloudDocId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sessionId': sessionId,
      'classId': classId,
      'classLabel': classLabel,
      'createdAt': createdAt.toIso8601String(),
      'teacherId': teacherId,
      'students': students.map((e) => e.toJson()).toList(),
      'auditLogs': auditLogs.map((e) => e.toJson()).toList(),
      'synced': synced,
      'cloudDocId': cloudDocId,
    };
  }

  factory AttendanceRecord.fromJson(Map<dynamic, dynamic> json) {
    final rawStudents = (json['students'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => AttendanceStudent.fromJson(e as Map<dynamic, dynamic>))
        .toList();
    final logs = (json['auditLogs'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((e) => AttendanceAuditLog.fromJson(e))
        .toList(growable: false);

    return AttendanceRecord(
      id: (json['id'] ?? '').toString(),
      sessionId: (json['sessionId'] ?? '').toString(),
      classId: (json['classId'] ?? '').toString(),
      classLabel: (json['classLabel'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      teacherId: (json['teacherId'] ?? '').toString(),
      students: rawStudents,
      auditLogs: logs,
      synced: (json['synced'] ?? false) == true,
      cloudDocId: json['cloudDocId']?.toString(),
    );
  }
}
