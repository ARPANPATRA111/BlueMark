class ActiveAttendanceSession {
  const ActiveAttendanceSession({
    required this.id,
    required this.classId,
    required this.classLabel,
    required this.teacherId,
    required this.teacherName,
    required this.startedAt,
    required this.isActive,
  });

  final String id;
  final String classId;
  final String classLabel;
  final String teacherId;
  final String teacherName;
  final DateTime startedAt;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'classId': classId,
      'classLabel': classLabel,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'startedAt': startedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ActiveAttendanceSession.fromJson(Map<dynamic, dynamic> json) {
    final rawStartedAt = json['startedAt'];
    DateTime startedAt;
    if (rawStartedAt is DateTime) {
      startedAt = rawStartedAt;
    } else {
      try {
        final dynamic value = rawStartedAt;
        final converted = value.toDate();
        startedAt = converted is DateTime
            ? converted
            : DateTime.tryParse((rawStartedAt ?? '').toString()) ?? DateTime.now();
      } catch (_) {
        startedAt = DateTime.tryParse((rawStartedAt ?? '').toString()) ?? DateTime.now();
      }
    }

    return ActiveAttendanceSession(
      id: (json['id'] ?? '').toString(),
      classId: (json['classId'] ?? '').toString(),
      classLabel: (json['classLabel'] ?? '').toString(),
      teacherId: (json['teacherId'] ?? '').toString(),
      teacherName: (json['teacherName'] ?? '').toString(),
      startedAt: startedAt,
      isActive: json['isActive'] == true,
    );
  }
}
