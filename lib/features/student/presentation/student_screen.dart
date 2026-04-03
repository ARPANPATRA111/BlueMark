import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/active_attendance_session.dart';
import '../../../models/app_user_role.dart';
import '../../../models/student_attendance_status.dart';
import '../../../models/student_profile.dart';
import '../../../services/ble_service.dart';
import 'student_timeline_screen.dart';

class StudentScreen extends ConsumerStatefulWidget {
  const StudentScreen({super.key});

  @override
  ConsumerState<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends ConsumerState<StudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rollController = TextEditingController();
  final _nameController = TextEditingController();

  String? _photoPath;
  bool _registering = false;
  bool _togglingReady = false;
  StudentAdvertiseStatus? _advertiseStatus;
  Timer? _advertiseStatusTimer;
  StreamSubscription<StudentAttendanceStatus?>? _attendanceStatusSubscription;
  StreamSubscription<ActiveAttendanceSession?>? _activeSessionSubscription;
  StudentAttendanceStatus? _latestAttendanceStatus;
  ActiveAttendanceSession? _activeSession;
  String? _lastNotifiedRecordId;
  int _healthFailureStreak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(studentProfileProvider);
      final ready = ref.read(studentReadyProvider);
      if (profile != null && ready) {
        _bindAttendanceStatus(profile.rollNumber);
        _startAdvertiseStatusPolling();
        _startAdvertising(profile).catchError((error) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to restore ready mode: $error')),
          );
        });
      }
      if (profile != null) {
        _bindActiveSession();
      }
    });
  }

  @override
  void dispose() {
    _advertiseStatusTimer?.cancel();
    _attendanceStatusSubscription?.cancel();
    _activeSessionSubscription?.cancel();
    _rollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studentProfileProvider);
    final ready = ref.watch(studentReadyProvider);
    final firebaseEnabled = ref.watch(firebaseServiceProvider).isEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Mode'),
        actions: [
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.secondaryContainer,
            ),
            child: Text(
              'Register once. Then keep readiness ON and your attendance is detected automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 10),
          _buildPlatformRequirementCard(),
          const SizedBox(height: 16),
          if (profile == null) _buildRegistrationCard() else ...[
            _buildProfileCard(profile, ready),
            const SizedBox(height: 12),
            _buildAttendanceStatusCard(profile, ready),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformRequirementCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline_rounded),
        title: const Text('Android BLE Requirement'),
        subtitle: const Text(
          'For reliable discovery on Android, Bluetooth must be ON and Location Services (device GPS toggle) must be ON. This is an Android BLE scan policy requirement, not just an app setting.',
        ),
      ),
    );
  }

  Widget _buildRegistrationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student Registration', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextFormField(
                controller: _rollController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                  hintText: 'Example: CSE23A001',
                ),
                validator: (value) {
                  final input = (value ?? '').trim().toUpperCase();
                  if (input.isEmpty) {
                    return 'Roll Number is required';
                  }
                  final valid = RegExp(r'^[A-Z0-9_-]{4,24}$').hasMatch(input);
                  if (!valid) {
                    return 'Use 4-24 chars (A-Z, 0-9, _ or -)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Example: Priya Sharma',
                ),
                validator: (value) {
                  final input = (value ?? '').trim();
                  if (input.isEmpty) {
                    return 'Name is required';
                  }
                  if (input.length < 3) {
                    return 'Name is too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _photoPath == null ? 'No photo selected (optional)' : 'Photo selected',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _registering ? null : _pickPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Pick Photo'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _registering ? null : _register,
                icon: _registering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_reg_rounded),
                label: const Text('Register Student'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(StudentProfile profile, bool ready) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      profile.photoPath != null ? FileImage(File(profile.photoPath!)) : null,
                  child: profile.photoPath == null
                      ? Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('Roll: ${profile.rollNumber}'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Attendance timeline',
                  icon: const Icon(Icons.timeline_rounded),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentTimelineScreen(rollNumber: profile.rollNumber),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              value: ready,
              onChanged: _togglingReady ? null : (value) => _onReadyChanged(profile, value),
              title: const Text('I am ready to be marked'),
              subtitle: const Text('When ON, the app broadcasts your presence over BLE.'),
            ),
            const SizedBox(height: 8),
            if (_togglingReady)
              const LinearProgressIndicator(minHeight: 3)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: ready
                      ? Colors.green.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  ready
                      ? 'Background mode active. Keep Bluetooth ON.'
                      : 'Ready mode is OFF. You will not be auto-detected.',
                ),
              ),
            const SizedBox(height: 8),
            _buildBroadcastHealth(ready),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastHealth(bool ready) {
    if (!ready) {
      return const SizedBox.shrink();
    }

    final status = _advertiseStatus;
    final state = status?.state ?? 'checking';
    final isActive = status?.isAdvertising == true;

    final icon = isActive
        ? Icons.bluetooth_connected_rounded
        : (state == 'error' ? Icons.error_outline_rounded : Icons.bluetooth_searching_rounded);
    final color = isActive
        ? Colors.green
        : (state == 'error' ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isActive
                  ? 'Broadcast health: active and discoverable'
                  : 'Broadcast health: $state${status?.lastError != null ? ' (${status!.lastError})' : ''}',
            ),
          ),
          IconButton(
            tooltip: 'Refresh status',
            onPressed: _refreshAdvertiseStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton(
            onPressed: () async {
              final granted = await ref.read(permissionServiceProvider).requestIgnoreBatteryOptimization();
              if (!granted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please disable battery restrictions for reliable background BLE.')),
                );
              }
            },
            child: const Text('Battery Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatusCard(StudentProfile profile, bool ready) {
    final firebase = ref.read(firebaseServiceProvider);
    if (!firebase.isEnabled) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_rounded),
          title: const Text('Attendance status sync unavailable'),
          subtitle: const Text(
            'Cloud sync is not configured on this build. Student-side marked status appears after Firebase setup.',
          ),
        ),
      );
    }

    final status = _latestAttendanceStatus;
    final activeSession = _activeSession;

    if (!ready) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.pause_circle_outline_rounded),
          title: Text('Tracking is currently OFF'),
          subtitle: Text('Turn ON readiness to allow live attendance tracking.'),
        ),
      );
    }

    if (activeSession != null) {
      final markedForActiveSession =
          status != null && status.sessionId.isNotEmpty && status.sessionId == activeSession.id;

      if (markedForActiveSession) {
        return Card(
          color: Colors.green.withValues(alpha: 0.1),
          child: ListTile(
            leading: const Icon(Icons.verified_rounded, color: Colors.green),
            title: const Text('Attendance Marked: Present'),
            subtitle: Text(
              'Teacher: ${status.teacherName.isEmpty ? status.teacherId : status.teacherName}\nSubject: ${status.classLabel}\nMarked at: ${DateFormatters.dateTime(status.markedAt)}',
            ),
          ),
        );
      }

      return Card(
        color: Colors.orange.withValues(alpha: 0.12),
        child: ListTile(
          leading: const Icon(Icons.radar_rounded, color: Colors.orange),
          title: const Text('Attendance Tracking In Progress'),
          subtitle: Text(
            'Teacher: ${activeSession.teacherName}\nSubject: ${activeSession.classLabel}\nStatus: You are being tracked but not marked yet.',
          ),
        ),
      );
    }

    if (status == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.hourglass_empty_rounded),
          title: Text('No Active Attendance Session Right Now'),
          subtitle: Text('Keep readiness ON. This card will update live when your class attendance starts.'),
        ),
      );
    }

    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: ListTile(
        leading: const Icon(Icons.verified_rounded, color: Colors.green),
        title: const Text('Latest Attendance Status: Present'),
        subtitle: Text(
          'Teacher: ${status.teacherName.isEmpty ? status.teacherId : status.teacherName}\nSubject: ${status.classLabel}\n${DateFormatters.dateTime(status.markedAt)}',
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1200);
    if (file == null) {
      return;
    }
    setState(() {
      _photoPath = file.path;
    });
  }

  Future<void> _register() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _registering = true;
    });

    try {
      final roll = _rollController.text.trim().toUpperCase();
      final hive = ref.read(hiveServiceProvider);
      final current = ref.read(studentProfileProvider);
      final alreadyExists = hive.isStudentRollRegistered(roll);
      if (alreadyExists && (current == null || current.rollNumber.toUpperCase() != roll)) {
        throw Exception('This roll number is already registered on this device network cache.');
      }

      final profile = StudentProfile(
        rollNumber: roll,
        name: _normalizeName(_nameController.text),
        photoPath: _photoPath,
        createdAt: DateTime.now(),
      );

      await ref.read(attendanceRepositoryProvider).registerStudent(profile);
      ref.read(studentProfileProvider.notifier).state = profile;
      ref.read(studentDirectoryProvider.notifier).state = ref.read(hiveServiceProvider).getStudentDirectory();
      _bindAttendanceStatus(profile.rollNumber);
      _bindActiveSession();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration complete. Turn on readiness to auto-mark attendance.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _registering = false;
        });
      }
    }
  }

  Future<void> _onReadyChanged(StudentProfile profile, bool value) async {
    setState(() {
      _togglingReady = true;
    });

    try {
      if (value) {
        final permissionResult = await ref.read(permissionServiceProvider).requestStudentPermissions();
        if (!permissionResult.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(permissionResult.message)));
          }
          return;
        }
        await _startAdvertising(profile);
        _bindAttendanceStatus(profile.rollNumber);
        _startAdvertiseStatusPolling();
      } else {
        await ref.read(bleServiceProvider).stopStudentAdvertising();
        _stopAdvertiseStatusPolling();
        _advertiseStatus = const StudentAdvertiseStatus(isAdvertising: false, state: 'stopped');
      }

      await ref.read(hiveServiceProvider).saveStudentReady(value);
      ref.read(studentReadyProvider.notifier).state = value;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to change readiness: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _togglingReady = false;
        });
      }
    }
  }

  Future<void> _startAdvertising(StudentProfile profile) async {
    final settings = await ref.read(appSettingsServiceProvider).getSettings();
    await ref.read(bleServiceProvider).startStudentAdvertising(
          profile,
          securityKey: settings.securityKey,
        );
    await _refreshAdvertiseStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BLE broadcast started. Keep app in recent apps for best reliability.')),
      );
    }
  }

  void _startAdvertiseStatusPolling() {
    _advertiseStatusTimer?.cancel();
    _advertiseStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshAdvertiseStatus();
    });
    _refreshAdvertiseStatus();
  }

  void _stopAdvertiseStatusPolling() {
    _advertiseStatusTimer?.cancel();
    _advertiseStatusTimer = null;
  }

  Future<void> _refreshAdvertiseStatus() async {
    final status = await ref.read(bleServiceProvider).getStudentAdvertisingStatus();
    if (!mounted) {
      return;
    }

    final profile = ref.read(studentProfileProvider);
    final ready = ref.read(studentReadyProvider);
    if (ready && profile != null && !status.isAdvertising) {
      _healthFailureStreak += 1;
      if (_healthFailureStreak >= 2) {
        try {
          final settings = await ref.read(appSettingsServiceProvider).getSettings();
          await ref.read(bleServiceProvider).startStudentAdvertising(
                profile,
                securityKey: settings.securityKey,
              );
          _healthFailureStreak = 0;
        } catch (_) {}
      }
    } else if (status.isAdvertising) {
      _healthFailureStreak = 0;
    }

    setState(() {
      _advertiseStatus = status;
    });
  }

  void _bindAttendanceStatus(String rollNumber) {
    _attendanceStatusSubscription?.cancel();

    final firebase = ref.read(firebaseServiceProvider);
    if (!firebase.isEnabled) {
      return;
    }

    _attendanceStatusSubscription = firebase.watchStudentAttendanceStatus(rollNumber).listen((status) async {
      if (!mounted) {
        return;
      }

      setState(() {
        _latestAttendanceStatus = status;
      });

      if (status == null || status.recordId == _lastNotifiedRecordId) {
        return;
      }

      final settings = await ref.read(appSettingsServiceProvider).getSettings();
      if (!settings.studentNotificationsEnabled) {
        return;
      }

      _lastNotifiedRecordId = status.recordId;
      await ref.read(notificationServiceProvider).showAttendanceMarked(
            classLabel: status.classLabel,
            markedAt: DateFormatters.dateTime(status.markedAt),
            teacherName: status.teacherName,
          );
    });
  }

  void _bindActiveSession() {
    _activeSessionSubscription?.cancel();

    final firebase = ref.read(firebaseServiceProvider);
    if (!firebase.isEnabled) {
      return;
    }

    _activeSessionSubscription = firebase.watchLatestActiveSession().listen((session) {
      if (!mounted) {
        return;
      }

      setState(() {
        _activeSession = session;
      });
    });
  }

  String _normalizeName(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    final words = trimmed.split(' ');
    final normalized = words
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
    return normalized;
  }
}
