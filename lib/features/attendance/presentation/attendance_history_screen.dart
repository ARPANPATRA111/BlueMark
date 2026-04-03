import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatters.dart';
import '../../../core/providers/app_providers.dart';

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(attendanceRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Reports')),
      body: FutureBuilder(
        future: repository.getAttendanceHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load records: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final records = snapshot.data ?? const [];
          if (records.isEmpty) {
            return const Center(
              child: Text('No attendance records yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.classLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Icon(
                            record.synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                            color: record.synced ? Colors.green : Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(DateFormatters.dateTime(record.createdAt)),
                      const SizedBox(height: 8),
                      Text('Present: ${record.presentCount}'),
                      if (record.sessionId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Session: ${record.sessionId}'),
                      ],
                      if (record.auditLogs.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Audit entries: ${record.auditLogs.length}'),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                            label: Text(DateFormatters.date(record.createdAt)),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            avatar: const Icon(Icons.timer_rounded, size: 16),
                            label: Text(DateFormatters.time(record.createdAt)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: -8,
                        children: record.students
                            .map((student) => Chip(label: Text(student.rollNumber)))
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemCount: records.length,
          );
        },
      ),
    );
  }
}
