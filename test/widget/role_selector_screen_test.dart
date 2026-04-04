import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/features/auth/presentation/role_selector_screen.dart';

void main() {
  testWidgets('renders role selection options', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RoleSelectorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bluetooth Attendance Tracker'), findsOneWidget);
    expect(find.text('Teacher (Host)'), findsOneWidget);

    final studentFinder = find.text('Student (Client)');
    if (studentFinder.evaluate().isEmpty) {
      await tester.drag(find.byType(GridView), const Offset(0, -220));
      await tester.pumpAndSettle();
    }

    expect(find.text('Student (Client)'), findsOneWidget);
  });
}
