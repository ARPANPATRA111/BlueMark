class StudentAttendanceStatus {
  const StudentAttendanceStatus({
    required this.rollNumber,
    required this.recordId,
    required this.sessionId,
    required this.classId,
    required this.classLabel,
    required this.markedAt,
    required this.teacherId,
    required this.teacherName,
    required this.isPresent,
  });

  final String rollNumber;
  final String recordId;
  final String sessionId;
  final String classId;
  final String classLabel;
  final DateTime markedAt;
  final String teacherId;
  final String teacherName;
  final bool isPresent;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rollNumber': rollNumber,
      'recordId': recordId,
      'sessionId': sessionId,
      'classId': classId,
      'classLabel': classLabel,
      'markedAt': markedAt.toIso8601String(),
      'teacherId': teacherId,
      'teacherName': teacherName,
      'isPresent': isPresent,
    };
  }

  factory StudentAttendanceStatus.fromJson(Map<dynamic, dynamic> json) {
    return StudentAttendanceStatus(
      rollNumber: (json['rollNumber'] ?? '').toString(),
      recordId: (json['recordId'] ?? '').toString(),
      sessionId: (json['sessionId'] ?? '').toString(),
      classId: (json['classId'] ?? '').toString(),
      classLabel: (json['classLabel'] ?? '').toString(),
      markedAt: DateTime.tryParse((json['markedAt'] ?? '').toString()) ?? DateTime.now(),
      teacherId: (json['teacherId'] ?? '').toString(),
      teacherName: (json['teacherName'] ?? '').toString(),
      isPresent: (json['isPresent'] ?? false) == true,
    );
  }
}
