class StudentProfile {
  const StudentProfile({
    required this.rollNumber,
    required this.name,
    this.photoPath,
    required this.createdAt,
  });

  final String rollNumber;
  final String name;
  final String? photoPath;
  final DateTime createdAt;

  StudentProfile copyWith({
    String? rollNumber,
    String? name,
    String? photoPath,
    DateTime? createdAt,
  }) {
    return StudentProfile(
      rollNumber: rollNumber ?? this.rollNumber,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rollNumber': rollNumber,
      'name': name,
      'photoPath': photoPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StudentProfile.fromJson(Map<dynamic, dynamic> json) {
    return StudentProfile(
      rollNumber: (json['rollNumber'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      photoPath: json['photoPath']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
