import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/core/utils/date_formatters.dart';

void main() {
  test('formats date, time and datetime in readable format', () {
    final value = DateTime(2026, 3, 31, 14, 5);

    expect(DateFormatters.date(value), '31 Mar 2026');
    expect(DateFormatters.time(value), isNotEmpty);
    expect(DateFormatters.dateTime(value), contains('31 Mar 2026'));
  });
}
