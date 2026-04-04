import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/student_profile.dart';

void main() {
  test('serializes and deserializes student profile', () {
    final original = StudentProfile(
      rollNumber: 'CSE23A001',
      name: 'Ananya Rao',
      photoPath: '/tmp/p.jpg',
      createdAt: DateTime(2026, 3, 31, 9, 30),
    );

    final json = original.toJson();
    final restored = StudentProfile.fromJson(json);

    expect(restored.rollNumber, original.rollNumber);
    expect(restored.name, original.name);
    expect(restored.photoPath, original.photoPath);
    expect(restored.createdAt, original.createdAt);
  });
}
