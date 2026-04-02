class ClassRoom {
  const ClassRoom({
    required this.id,
    required this.subject,
    required this.section,
  });

  final String id;
  final String subject;
  final String section;

  String get label => '$subject ($section)';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subject': subject,
      'section': section,
    };
  }

  factory ClassRoom.fromJson(Map<dynamic, dynamic> json) {
    return ClassRoom(
      id: (json['id'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
    );
  }
}
