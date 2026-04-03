import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/student_attendance_status.dart';

class StudentTimelineScreen extends ConsumerStatefulWidget {
  const StudentTimelineScreen({super.key, required this.rollNumber});

  final String rollNumber;

  @override
  ConsumerState<StudentTimelineScreen> createState() => _StudentTimelineScreenState();
}

class _StudentTimelineScreenState extends ConsumerState<StudentTimelineScreen> {
  String _classFilter = 'ALL';
  late Future<List<StudentAttendanceStatus>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(refreshCloud: true);
  }

  Future<List<StudentAttendanceStatus>> _load({required bool refreshCloud}) {
    return ref.read(attendanceRepositoryProvider).getStudentTimeline(
          widget.rollNumber,
          refreshCloud: refreshCloud,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance Timeline')),
      body: RefreshIndicator(
        onRefresh: () async {
          final next = _load(refreshCloud: true);
          setState(() {
            _future = next;
          });
          await next;
        },
        child: FutureBuilder<List<StudentAttendanceStatus>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Unable to load timeline: ${snapshot.error}'),
                ),
              );
            }

            final all = snapshot.data ?? const [];
            final classes = <String>{'ALL', ...all.map((e) => e.classLabel)}.toList(growable: false);
            final filtered = _classFilter == 'ALL'
                ? all
                : all.where((e) => e.classLabel == _classFilter).toList(growable: false);

            if (all.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 130),
                  Icon(Icons.history_toggle_off_rounded, size: 52),
                  SizedBox(height: 10),
                  Center(child: Text('No attendance history yet.')),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: classes.map((classLabel) {
                      final selected = _classFilter == classLabel;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: selected,
                          label: Text(classLabel),
                          onSelected: (_) {
                            setState(() {
                              _classFilter = classLabel;
                            });
                          },
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
                const SizedBox(height: 12),
                ...filtered.map((item) {
                  final teacher = item.teacherName.isEmpty ? item.teacherId : item.teacherName;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.verified_rounded, color: Colors.green),
                      title: Text(item.classLabel),
                      subtitle: Text('Teacher: $teacher\n${DateFormatters.dateTime(item.markedAt)}'),
                      trailing: const Text('Present'),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
