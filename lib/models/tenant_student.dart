class TenantStudent {
  const TenantStudent({
    required this.rollNumber,
    required this.name,
    required this.section,
    this.linkedUserId,
    required this.updatedAt,
  });

  final String rollNumber;
  final String name;
  final String section;
  final String? linkedUserId;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rollNumber': rollNumber,
      'name': name,
      'section': section,
      'linkedUserId': linkedUserId,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TenantStudent.fromJson(Map<dynamic, dynamic> json) {
    final rawDate = json['updatedAt'];
    DateTime updatedAt;
    if (rawDate is DateTime) {
      updatedAt = rawDate;
    } else {
      try {
        final dynamic value = rawDate;
        final converted = value.toDate();
        updatedAt = converted is DateTime
            ? converted
            : DateTime.tryParse((rawDate ?? '').toString()) ?? DateTime.now();
      } catch (_) {
        updatedAt = DateTime.tryParse((rawDate ?? '').toString()) ?? DateTime.now();
      }
    }

    return TenantStudent(
      rollNumber: (json['rollNumber'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      linkedUserId: json['linkedUserId']?.toString(),
      updatedAt: updatedAt,
    );
  }
}
