import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../models/tenant_student.dart';

class StudentManagementScreen extends ConsumerStatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  ConsumerState<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends ConsumerState<StudentManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rollController = TextEditingController();
  final _nameController = TextEditingController();
  final _sectionController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _rollController.dispose();
    _nameController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(tenantStudentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Directory Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add / Update Student', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _rollController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Roll Number'),
                      validator: (value) {
                        final input = (value ?? '').trim().toUpperCase();
                        final valid = RegExp(r'^[A-Z0-9_-]{4,24}$').hasMatch(input);
                        if (!valid) {
                          return 'Use 4-24 chars (A-Z, 0-9, _ or -)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) {
                        if ((value ?? '').trim().length < 3) {
                          return 'Enter a valid name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _sectionController,
                      decoration: const InputDecoration(
                        labelText: 'Section',
                        hintText: 'Example: CSE-A',
                      ),
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
                      label: const Text('Save Student'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Registered students', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          studentsAsync.when(
            data: (students) {
              if (students.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.people_outline_rounded),
                    title: Text('No students found in this tenant yet.'),
                  ),
                );
              }

              return Column(
                children: students.map((student) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.badge_rounded),
                      title: Text('${student.name} (${student.rollNumber})'),
                      subtitle: Text(student.section.isEmpty ? 'Section not set' : 'Section: ${student.section}'),
                      trailing: const Icon(Icons.edit_rounded),
                      onTap: () {
                        setState(() {
                          _rollController.text = student.rollNumber;
                          _nameController.text = student.name;
                          _sectionController.text = student.section;
                        });
                      },
                    ),
                  );
                }).toList(growable: false),
              );
            },
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: const Text('Unable to load students'),
                subtitle: Text('$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final student = TenantStudent(
        rollNumber: _rollController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        section: _sectionController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await ref.read(firebaseServiceProvider).upsertTenantStudent(student);
      await ref.read(hiveServiceProvider).upsertStudentDirectory(
            rollNumber: student.rollNumber,
            name: student.name,
          );
      ref.read(studentDirectoryProvider.notifier).state = ref.read(hiveServiceProvider).getStudentDirectory();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${student.rollNumber} successfully.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save student: $error')),
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
