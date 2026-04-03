import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../models/app_runtime_settings.dart';

class TeacherSettingsScreen extends ConsumerStatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  ConsumerState<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends ConsumerState<TeacherSettingsScreen> {
  AppRuntimeSettings? _settings;
  late final TextEditingController _securityKeyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _securityKeyController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _securityKeyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await ref.read(appSettingsServiceProvider).getSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = value;
      _securityKeyController.text = value.securityKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sliderTile(
            title: 'Minimum RSSI',
            subtitle: 'Ignore weak devices below this signal threshold',
            valueLabel: settings.minRssi.toString(),
            min: -100,
            max: -55,
            divisions: 45,
            value: settings.minRssi.toDouble(),
            onChanged: (v) => _update(settings.copyWith(minRssi: v.round())),
          ),
          const SizedBox(height: 10),
          _sliderTile(
            title: 'Stale Timeout (seconds)',
            subtitle: 'Remove students if no packet arrives in this window',
            valueLabel: settings.staleSeconds.toString(),
            min: 8,
            max: 40,
            divisions: 32,
            value: settings.staleSeconds.toDouble(),
            onChanged: (v) => _update(settings.copyWith(staleSeconds: v.round())),
          ),
          const SizedBox(height: 10),
          _sliderTile(
            title: 'Duplicate Window (minutes)',
            subtitle: 'Warn if attendance for same class was taken recently',
            valueLabel: settings.sessionDuplicateWindowMinutes.toString(),
            min: 5,
            max: 90,
            divisions: 85,
            value: settings.sessionDuplicateWindowMinutes.toDouble(),
            onChanged: (v) =>
                _update(settings.copyWith(sessionDuplicateWindowMinutes: v.round())),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Institution Security Key', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _securityKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Security key',
                      hintText: 'Shared secret for BLE signature verification',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use the same key on all teacher and student devices from your institution.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: settings.compactMode,
            title: const Text('Compact List Mode'),
            subtitle: const Text('Show tighter student lists for large classrooms'),
            onChanged: (v) => _update(settings.copyWith(compactMode: v)),
          ),
          SwitchListTile.adaptive(
            value: settings.studentNotificationsEnabled,
            title: const Text('Student Notifications Enabled'),
            subtitle: const Text('Allow local notification when attendance is marked'),
            onChanged: (v) => _update(settings.copyWith(studentNotificationsEnabled: v)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  Widget _sliderTile({
    required String title,
    required String subtitle,
    required String valueLabel,
    required double min,
    required double max,
    required int divisions,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                Text(valueLabel),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  void _update(AppRuntimeSettings value) {
    setState(() {
      _settings = value;
    });
  }

  Future<void> _save() async {
    final current = _settings;
    if (current == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final next = current.copyWith(
        securityKey: _securityKeyController.text.trim().isEmpty
            ? current.securityKey
            : _securityKeyController.text.trim(),
      );
      await ref.read(appSettingsServiceProvider).saveSettings(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = next;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}
