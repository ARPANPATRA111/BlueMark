import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../admin/presentation/student_management_screen.dart';
import '../../../models/app_user_role.dart';
import '../../../models/class_room.dart';
import '../../attendance/presentation/attendance_history_screen.dart';
import 'live_attendance_screen.dart';
import 'teacher_settings_screen.dart';

class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classRoomsProvider);
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final firebaseEnabled = ref.watch(firebaseServiceProvider).isEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Students',
            icon: const Icon(Icons.badge_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StudentManagementScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Attendance reports',
            icon: const Icon(Icons.assessment_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync_rounded),
            onPressed: () => _syncNow(context, ref),
          ),
          IconButton(
            tooltip: 'Attendance settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TeacherSettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: firebaseEnabled ? 'Sign out' : 'Switch role',
            icon: Icon(firebaseEnabled ? Icons.logout_rounded : Icons.switch_account_rounded),
            onPressed: () {
              if (firebaseEnabled) {
                ref.read(firebaseServiceProvider).signOut();
              } else {
                ref.read(appRoleProvider.notifier).setRole(AppUserRole.unknown);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _syncNow(context, ref, showMessage: false),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready For Attendance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select a class and tap Start Attendance. Nearby student devices are auto-detected in 10-15 seconds.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (appUser != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Signed in as ${appUser.displayName} (${appUser.tenantId})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.bluetooth_searching_rounded, size: 18),
                        label: const Text('BLE auto scan'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        avatar: const Icon(Icons.offline_bolt_rounded, size: 18),
                        label: const Text('Offline first'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...classes.map((classRoom) => _ClassCard(classRoom: classRoom)),
          ],
        ),
      ),
    );
  }

  Future<void> _syncNow(
    BuildContext context,
    WidgetRef ref, {
    bool showMessage = true,
  }) async {
    try {
      await ref.read(attendanceRepositoryProvider).syncPendingRecords();
      ref.read(studentDirectoryProvider.notifier).state = ref.read(hiveServiceProvider).getStudentDirectory();
      if (showMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete.')),
        );
      }
    } catch (error) {
      if (showMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $error')),
        );
      }
    }
  }
}

class _ClassCard extends ConsumerWidget {
  const _ClassCard({required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _colorForClass(context, classRoom.id).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.class_rounded, color: _colorForClass(context, classRoom.id)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(classRoom.subject, style: Theme.of(context).textTheme.titleMedium),
                  Text('Section: ${classRoom.section}'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LiveAttendanceScreen(classRoom: classRoom),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Attendance'),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForClass(BuildContext context, String classId) {
    final palette = <MaterialColor>[
      Colors.teal,
      Colors.indigo,
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.pink,
      Colors.cyan,
    ];
    final index = classId.hashCode.abs() % palette.length;
    final base = palette[index];
    if (Theme.of(context).brightness == Brightness.dark) {
      return base.shade200;
    }
    return base.shade700;
  }
}
