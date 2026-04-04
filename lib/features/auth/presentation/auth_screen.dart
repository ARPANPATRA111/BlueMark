import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../models/app_user_role.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tenantController = TextEditingController();
  final _rollController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final _designationController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _busy = false;
  AppUserRole _selectedRole = AppUserRole.student;

  @override
  void dispose() {
    _nameController.dispose();
    _tenantController.dispose();
    _rollController.dispose();
    _employeeIdController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Institution Sign In',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegisterMode
                        ? 'Create your account with role-specific details.'
                          : 'Use your institutional account to continue.',
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(value: false, label: Text('Sign In')),
                        ButtonSegment<bool>(value: true, label: Text('Register')),
                      ],
                      selected: <bool>{_isRegisterMode},
                      onSelectionChanged: _busy
                          ? null
                          : (selection) {
                              setState(() {
                                _isRegisterMode = selection.first;
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    if (_isRegisterMode) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: (value) {
                          if (!_isRegisterMode) {
                            return null;
                          }
                          final input = (value ?? '').trim();
                          if (input.length < 3) {
                            return 'Enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AppUserRole>(
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: AppUserRole.student,
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: AppUserRole.teacher,
                            child: Text('Teacher'),
                          ),
                          DropdownMenuItem(
                            value: AppUserRole.admin,
                            child: Text('Institution Admin'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedRole = value;
                                });
                              },
                      ),
                        const SizedBox(height: 12),
                        if (_selectedRole == AppUserRole.student) ...[
                          TextFormField(
                            controller: _tenantController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Institution Tenant Code',
                              hintText: 'Example: ABC_COLLEGE',
                            ),
                            validator: _validateTenant,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _rollController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Roll Number',
                              hintText: 'Example: CSE23A001',
                            ),
                            validator: (value) {
                              if (!_isRegisterMode || _selectedRole != AppUserRole.student) {
                                return null;
                              }
                              final input = (value ?? '').trim().toUpperCase();
                              final valid = RegExp(r'^[A-Z0-9_-]{4,24}$').hasMatch(input);
                              if (!valid) {
                                return 'Use 4-24 chars (A-Z, 0-9, _ or -)';
                              }
                              return null;
                            },
                          ),
                        ] else ...[
                          if (_selectedRole == AppUserRole.teacher) ...[
                            TextFormField(
                              controller: _employeeIdController,
                              decoration: const InputDecoration(
                                labelText: 'Employee ID',
                                hintText: 'Example: TCH-1042',
                              ),
                              validator: (value) {
                                if (!_isRegisterMode || _selectedRole != AppUserRole.teacher) {
                                  return null;
                                }
                                if ((value ?? '').trim().length < 3) {
                                  return 'Enter a valid employee ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _departmentController,
                              decoration: const InputDecoration(
                                labelText: 'Department',
                                hintText: 'Example: Computer Science',
                              ),
                              validator: (value) {
                                if (!_isRegisterMode || _selectedRole != AppUserRole.teacher) {
                                  return null;
                                }
                                if ((value ?? '').trim().length < 2) {
                                  return 'Enter your department';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Teacher accounts require admin approval before teacher access is enabled.',
                            ),
                          ] else if (_selectedRole == AppUserRole.admin) ...[
                            TextFormField(
                              controller: _designationController,
                              decoration: const InputDecoration(
                                labelText: 'Designation',
                                hintText: 'Example: Principal',
                              ),
                              validator: (value) {
                                if (!_isRegisterMode || _selectedRole != AppUserRole.admin) {
                                  return null;
                                }
                                if ((value ?? '').trim().length < 2) {
                                  return 'Enter designation';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tenantController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Institution Tenant Code (Optional)',
                              hintText: 'Leave empty to auto-generate from email domain',
                            ),
                            validator: _validateTenant,
                          ),
                        ],
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                        onChanged: (_) {
                          if (_isRegisterMode && _selectedRole != AppUserRole.student) {
                            setState(() {});
                          }
                        },
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final input = (value ?? '').trim();
                        final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input);
                        if (!valid) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) {
                        final input = (value ?? '');
                        if (input.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_isRegisterMode ? Icons.person_add_alt_1_rounded : Icons.login_rounded),
                        label: Text(_isRegisterMode ? 'Create Account' : 'Sign In'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isRegisterMode && _selectedRole != AppUserRole.student) ...[
                      Text(
                        'Tenant code preview: ${_previewTenantCode(_emailController.text, _tenantController.text)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Note: Android BLE scanning often requires Bluetooth ON and Location Services ON due system restrictions.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final firebase = ref.read(firebaseServiceProvider);
      final email = _emailController.text.trim();
      if (_isRegisterMode) {
        final tenantCode = _selectedRole == AppUserRole.student
            ? _normalizeTenantCode(_tenantController.text)
            : _resolveTenantForStaff(
                email: email,
                optionalTenantInput: _tenantController.text,
              );

        await firebase.registerWithEmailPassword(
          email: email,
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          tenantId: tenantCode,
          role: _selectedRole,
          studentRollNumber: _selectedRole == AppUserRole.student ? _rollController.text : null,
          teacherEmployeeId: _selectedRole == AppUserRole.teacher ? _employeeIdController.text : null,
          teacherDepartment: _selectedRole == AppUserRole.teacher ? _departmentController.text : null,
          adminDesignation: _selectedRole == AppUserRole.admin ? _designationController.text : null,
        );
      } else {
        await firebase.signInWithEmailPassword(
          email: email,
          password: _passwordController.text,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRegisterMode
                ? (_selectedRole == AppUserRole.teacher
                    ? 'Account created. Wait for admin approval to access teacher console.'
                    : 'Account created successfully.')
                : 'Signed in successfully.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      final raw = error.toString();
      final clean = raw.startsWith('Exception: ') ? raw.substring('Exception: '.length) : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(clean)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String? _validateTenant(String? value) {
    if (!_isRegisterMode) {
      return null;
    }

    final input = _normalizeTenantCode(value ?? '');
    if (_selectedRole == AppUserRole.student && input.isEmpty) {
      return 'Institution code is required for student registration';
    }

    if (input.isNotEmpty && !_isValidTenantCode(input)) {
      return 'Use 3-30 chars (A-Z, 0-9, _ or -)';
    }

    return null;
  }

  String _resolveTenantForStaff({
    required String email,
    required String optionalTenantInput,
  }) {
    final provided = _normalizeTenantCode(optionalTenantInput);
    if (provided.isNotEmpty) {
      return provided;
    }

    final derived = _deriveTenantCodeFromEmail(email);
    if (derived.isEmpty) {
      throw Exception('Unable to derive institution code from email. Enter tenant code manually.');
    }

    return derived;
  }

  String _previewTenantCode(String email, String optionalTenantInput) {
    final provided = _normalizeTenantCode(optionalTenantInput);
    if (provided.isNotEmpty) {
      return provided;
    }

    final derived = _deriveTenantCodeFromEmail(email);
    return derived.isEmpty ? 'Waiting for valid email' : derived;
  }

  String _deriveTenantCodeFromEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    if (!trimmed.contains('@')) {
      return '';
    }

    final domain = trimmed.split('@').last;
    final cleaned = domain
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toUpperCase();

    if (!_isValidTenantCode(cleaned)) {
      return '';
    }

    return cleaned;
  }

  String _normalizeTenantCode(String value) => value.trim().toUpperCase();

  bool _isValidTenantCode(String value) {
    return RegExp(r'^[A-Z0-9_-]{3,30}$').hasMatch(value);
  }
}
