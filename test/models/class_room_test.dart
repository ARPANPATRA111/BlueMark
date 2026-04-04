import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/models/class_room.dart';

void main() {
  test('returns readable class label', () {
    const room = ClassRoom(id: 'CSE-A-DBMS', subject: 'DBMS', section: 'CSE-A');
    expect(room.label, 'DBMS (CSE-A)');
  });

  test('serializes and deserializes class room', () {
    const room = ClassRoom(id: 'IT-A-ML', subject: 'Machine Learning', section: 'IT-A');
    final restored = ClassRoom.fromJson(room.toJson());

    expect(restored.id, room.id);
    expect(restored.subject, room.subject);
    expect(restored.section, room.section);
  });
}
