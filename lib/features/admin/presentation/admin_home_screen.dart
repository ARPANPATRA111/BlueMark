import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../features/teacher/presentation/teacher_home_screen.dart';
import 'student_management_screen.dart';
import 'user_management_screen.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  Future<Map<String, int>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ref.read(firebaseServiceProvider).fetchTenantStats();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institution Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh stats',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _statsFuture = ref.read(firebaseServiceProvider).fetchTenantStats();
              });
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(firebaseServiceProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          userAsync.when(
            data: (user) {
              if (user == null) {
                return const SizedBox.shrink();
              }

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.account_circle_rounded),
                  title: Text(user.displayName),
                  subtitle: Text('Tenant: ${user.tenantId} • ${user.email}'),
                ),
              );
            },
            loading: () => const Card(
              child: ListTile(
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Loading profile...'),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: const Text('Unable to load profile'),
                subtitle: Text('$error'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, int>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                );
              }

              final stats = snapshot.data ?? const <String, int>{};
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StatChip(label: 'Users', value: stats['users'] ?? 0),
                      _StatChip(label: 'Students', value: stats['students'] ?? 0),
                      _StatChip(label: 'Attendance', value: stats['attendance'] ?? 0),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              );
            },
            icon: const Icon(Icons.supervisor_account_rounded),
            label: const Text('User Management'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StudentManagementScreen()),
              );
            },
            icon: const Icon(Icons.badge_rounded),
            label: const Text('Student Directory Management'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
              );
            },
            icon: const Icon(Icons.class_rounded),
            label: const Text('Open Teacher Attendance Console'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.analytics_rounded, size: 16),
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
