import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/app_runtime_settings.dart';
import '../../../models/attendance_record.dart';
import '../../../models/class_room.dart';
import '../../../services/ble_service.dart';

class _ManualEntry {
  const _ManualEntry({
    required this.rollNumber,
    required this.name,
    required this.reason,
  });

  final String rollNumber;
  final String name;
  final String reason;
}

class LiveAttendanceScreen extends ConsumerStatefulWidget {
  const LiveAttendanceScreen({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  ConsumerState<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends ConsumerState<LiveAttendanceScreen> {
  StreamSubscription<List<DetectedStudent>>? _scanSubscription;
  Timer? _refreshTicker;

  List<DetectedStudent> _detected = const [];
  final Set<String> _excludedAutoRolls = <String>{};
  final Map<String, _ManualEntry> _manualEntries = <String, _ManualEntry>{};

  bool _starting = true;
  bool _marking = false;
  String? _error;
  int _secondsElapsed = 0;
  AppRuntimeSettings? _settings;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _startAttendanceFlow();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _refreshTicker?.cancel();
    ref.read(bleServiceProvider).stopTeacherScan();
    unawaited(ref.read(attendanceRepositoryProvider).endSession(widget.classRoom.id));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentDirectory = ref.watch(studentDirectoryProvider);
    final compactMode = _settings?.compactMode == true;
    final finalCount = _detected.where((e) => !_excludedAutoRolls.contains(e.rollNumber)).length + _manualEntries.length;
    final diagnostics = ref.read(bleServiceProvider).diagnostics;

    return Scaffold(
      appBar: AppBar(
        title: Text('Live: ${widget.classRoom.label}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 12),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _buildDiagnosticsCard(diagnostics),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Detected Students (${_detected.length})', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  avatar: const Icon(Icons.timer_outlined, size: 17),
                  label: const Text('Auto-refresh 3s'),
                ),
              ],
            ),
            if (_manualEntries.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Manual additions: ${_manualEntries.length}'),
            ],
            if (_excludedAutoRolls.isNotEmpty) Text('Excluded auto detections: ${_excludedAutoRolls.length}'),
            const SizedBox(height: 8),
            Expanded(
              child: _detected.isEmpty
                  ? const Center(
                      child: Text('No students detected yet. Keep phones nearby and Bluetooth ON.'),
                    )
                  : ListView.separated(
                      itemBuilder: (context, index) {
                        final student = _detected[index];
                        final name = studentDirectory[student.rollNumber] ?? 'Unknown Student';
                        final excluded = _excludedAutoRolls.contains(student.rollNumber);
                        return ListTile(
                          dense: compactMode,
                          visualDensity: compactMode ? VisualDensity.compact : VisualDensity.standard,
                          leading: Icon(
                            excluded ? Icons.remove_circle_outline : Icons.check_circle,
                            color: excluded ? Colors.orange : Colors.green,
                          ),
                          title: Text(name),
                          subtitle: Text('Roll: ${student.rollNumber} • RSSI: ${student.rssi}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: excluded
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(excluded ? 'Excluded' : 'Present'),
                          ),
                        );
                      },
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemCount: _detected.length,
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_starting || _marking || _error != null) ? null : _openReviewSheet,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Review & Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_starting || _marking || _error != null || finalCount == 0)
                        ? null
                        : _markAndSave,
                    icon: _marking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt_rounded),
                    label: Text(finalCount == 0 ? 'Waiting For Students...' : 'Mark & Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Text(
                'Final present count: $finalCount',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final windowLeft = (AppConstants.scanWindowSeconds - _secondsElapsed).clamp(0, AppConstants.scanWindowSeconds);
    final sessionId = _sessionId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _starting ? 'Starting BLE scan...' : 'Scanning in progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Auto-refresh every 3 seconds • Recommended capture window: ${windowLeft}s left',
            ),
            if (sessionId != null && sessionId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Session: $sessionId', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_secondsElapsed / AppConstants.scanWindowSeconds).clamp(0, 1),
              minHeight: 5,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  avatar: const Icon(Icons.bluetooth_rounded, size: 17),
                  label: const Text('BLE active'),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  avatar: const Icon(Icons.people_alt_rounded, size: 17),
                  label: Text('${_detected.length} present'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard(BleDiagnostics diagnostics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.radar_rounded, size: 16),
              label: Text('Batches: ${diagnostics.scanBatches}'),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.graphic_eq_rounded, size: 16),
              label: Text('Packets: ${diagnostics.advertisementsSeen}'),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.signal_cellular_alt_rounded, size: 16),
              label: Text('RSSI >= ${diagnostics.minRssiThreshold}'),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.timer_rounded, size: 16),
              label: Text('Stale: ${diagnostics.staleSeconds}s'),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.history_rounded, size: 16),
              label: Text(
                diagnostics.lastPacketAt == null
                    ? 'Last packet: -'
                    : 'Last packet: ${DateFormatters.time(diagnostics.lastPacketAt!)}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startAttendanceFlow() async {
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final permission = await ref.read(permissionServiceProvider).requestTeacherPermissions();
      if (!permission.isGranted) {
        throw BleException(permission.message);
      }

      final settings = await ref.read(appSettingsServiceProvider).getSettings();
      _settings = settings;

      final repository = ref.read(attendanceRepositoryProvider);
      var session = await repository.startSession(
        classRoom: widget.classRoom,
        duplicateWindowMinutes: settings.sessionDuplicateWindowMinutes,
      );

      if (session.duplicateDetected) {
        final proceed = await _showDuplicateDialog(session.duplicateRecord);
        if (!proceed) {
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }

        session = await repository.startSession(
          classRoom: widget.classRoom,
          duplicateWindowMinutes: settings.sessionDuplicateWindowMinutes,
          force: true,
        );
      }

      _sessionId = session.sessionId;

      await ref.read(attendanceRepositoryProvider).refreshStudentDirectory();
      ref.read(studentDirectoryProvider.notifier).state = ref.read(hiveServiceProvider).getStudentDirectory();

      final ble = ref.read(bleServiceProvider);
      await ble.startTeacherScan(
        minRssiThreshold: settings.minRssi,
        staleSeconds: settings.staleSeconds,
        securityKey: settings.securityKey,
      );

      _scanSubscription = ble.detectedStudentsStream.listen((students) {
        if (!mounted) {
          return;
        }
        setState(() {
          _detected = students;
          _excludedAutoRolls.removeWhere((roll) => !_detected.any((s) => s.rollNumber == roll));
        });
      });

      _refreshTicker = Timer.periodic(const Duration(seconds: AppConstants.scanRefreshIntervalSeconds), (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _secondsElapsed += AppConstants.scanRefreshIntervalSeconds;
          _detected = ref.read(bleServiceProvider).latestDetectedStudents;
          _excludedAutoRolls.removeWhere((roll) => !_detected.any((s) => s.rollNumber == roll));
        });
        _recoverScanIfNeeded();
      });
    } catch (error) {
      await ref.read(attendanceRepositoryProvider).endSession(widget.classRoom.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _recoverScanIfNeeded() async {
    final ble = ref.read(bleServiceProvider);
    final settings = _settings;
    if (settings == null || ble.isTeacherScanning) {
      return;
    }

    AppLogger.ble('Auto-recovering teacher scan');
    try {
      await ble.startTeacherScan(
        minRssiThreshold: settings.minRssi,
        staleSeconds: settings.staleSeconds,
        securityKey: settings.securityKey,
      );
    } catch (e) {
      AppLogger.bleError('Scan auto-recovery failed', e);
    }
  }

  Future<void> _openReviewSheet() async {
    final studentDirectory = ref.read(studentDirectoryProvider);

    final autoEntries = _detected
        .map(
          (s) => AttendanceStudent(
            rollNumber: s.rollNumber,
            name: studentDirectory[s.rollNumber] ?? 'Unknown Student',
            rssi: s.rssi,
            detectedAt: s.lastSeen,
            source: 'auto',
          ),
        )
        .toList(growable: false);

    final localExcluded = Set<String>.from(_excludedAutoRolls);
    final localManual = Map<String, _ManualEntry>.from(_manualEntries);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Review & Edit Attendance', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          Text('Auto detections', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          ...autoEntries.map((entry) {
                            final included = !localExcluded.contains(entry.rollNumber);
                            return CheckboxListTile(
                              value: included,
                              title: Text('${entry.name} (${entry.rollNumber})'),
                              subtitle: Text('RSSI: ${entry.rssi}'),
                              onChanged: (v) {
                                setModalState(() {
                                  if (v == true) {
                                    localExcluded.remove(entry.rollNumber);
                                  } else {
                                    localExcluded.add(entry.rollNumber);
                                  }
                                });
                              },
                            );
                          }),
                          const Divider(height: 24),
                          Text('Manual additions', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          if (localManual.isEmpty)
                            const Text('No manual entries yet.')
                          else
                            ...localManual.values.map((entry) {
                              return ListTile(
                                leading: const Icon(Icons.edit_note_rounded),
                                title: Text('${entry.name} (${entry.rollNumber})'),
                                subtitle: Text('Reason: ${entry.reason}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () {
                                    setModalState(() {
                                      localManual.remove(entry.rollNumber);
                                    });
                                  },
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _addManualStudent(context, setModalState, localManual),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Add Manual Student'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _excludedAutoRolls
                                  ..clear()
                                  ..addAll(localExcluded);
                                _manualEntries
                                  ..clear()
                                  ..addAll(localManual);
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Apply Changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addManualStudent(
    BuildContext context,
    StateSetter setModalState,
    Map<String, _ManualEntry> manualMap,
  ) async {
    final rollController = TextEditingController();
    final nameController = TextEditingController();
    final reasonController = TextEditingController(text: 'Teacher manual override');

    final added = await showDialog<_ManualEntry>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Manual Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: rollController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Roll Number'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name (optional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final roll = rollController.text.trim().toUpperCase();
                final reason = reasonController.text.trim();
                if (roll.isEmpty || reason.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  _ManualEntry(
                    rollNumber: roll,
                    name: nameController.text.trim().isEmpty ? 'Manual Student' : nameController.text.trim(),
                    reason: reason,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    rollController.dispose();
    nameController.dispose();
    reasonController.dispose();

    if (added == null) {
      return;
    }

    setModalState(() {
      manualMap[added.rollNumber] = added;
    });
  }

  Future<void> _markAndSave() async {
    setState(() {
      _marking = true;
    });

    try {
      final sessionId = _sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('Session is not initialized. Please restart attendance scan.');
      }

      final teacherId = ref.read(firebaseServiceProvider).teacherId;
      final studentDirectory = ref.read(studentDirectoryProvider);

      final finalStudents = <AttendanceStudent>[
        ..._detected
            .where((item) => !_excludedAutoRolls.contains(item.rollNumber))
            .map(
              (item) => AttendanceStudent(
                rollNumber: item.rollNumber,
                name: studentDirectory[item.rollNumber] ?? 'Unknown Student',
                rssi: item.rssi,
                detectedAt: item.lastSeen,
                source: 'auto',
              ),
            ),
        ..._manualEntries.values.map(
          (item) => AttendanceStudent(
            rollNumber: item.rollNumber,
            name: item.name,
            rssi: 0,
            detectedAt: DateTime.now(),
            source: 'manual',
            markReason: item.reason,
          ),
        ),
      ];

      if (finalStudents.isEmpty) {
        throw Exception('No students selected to mark present.');
      }

      final auditLogs = <AttendanceAuditLog>[
        ..._excludedAutoRolls.map(
          (roll) => AttendanceAuditLog(
            action: 'exclude_auto_detection',
            changedAt: DateTime.now(),
            changedBy: teacherId,
            rollNumber: roll,
            reason: 'Excluded during review',
          ),
        ),
        ..._manualEntries.values.map(
          (entry) => AttendanceAuditLog(
            action: 'manual_addition',
            changedAt: DateTime.now(),
            changedBy: teacherId,
            rollNumber: entry.rollNumber,
            reason: entry.reason,
          ),
        ),
      ];

      final repository = ref.read(attendanceRepositoryProvider);
      AppLogger.attendance('Saving attendance: session=$sessionId students=${finalStudents.length} audits=${auditLogs.length}');
      final record = await repository.saveAttendance(
        classRoom: widget.classRoom,
        sessionId: sessionId,
        students: finalStudents,
        auditLogs: auditLogs,
      );

      await ref.read(bleServiceProvider).stopTeacherScan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance saved: ${record.presentCount} students marked present.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      AppLogger.attendanceError('Save attendance failed', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save attendance: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _marking = false;
        });
      }
    }
  }

  Future<bool> _showDuplicateDialog(AttendanceRecord? existingRecord) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Duplicate Attendance Warning'),
          content: Text(
            existingRecord == null
                ? 'Attendance for this class was recently marked. Start a new session anyway?'
                : 'Attendance was already marked at ${DateFormatters.dateTime(existingRecord.createdAt)} for this class. Start a new session anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start New Session'),
            ),
          ],
        );
      },
    );

    return result == true;
  }
}
