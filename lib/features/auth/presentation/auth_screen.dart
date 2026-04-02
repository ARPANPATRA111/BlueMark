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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _busy = false;
  AppUserRole _selectedRole = AppUserRole.student;

  @override
  void dispose() {
    _nameController.dispose();
    _tenantController.dispose();
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
                          ? 'Create your account with your institution tenant code.'
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
                      TextFormField(
                        controller: _tenantController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Institution Tenant Code',
                          hintText: 'Example: ABC_COLLEGE',
                        ),
                        validator: (value) {
                          if (!_isRegisterMode) {
                            return null;
                          }
                          final input = (value ?? '').trim().toUpperCase();
                          final valid = RegExp(r'^[A-Z0-9_-]{3,30}$').hasMatch(input);
                          if (!valid) {
                            return 'Use 3-30 chars (A-Z, 0-9, _ or -)';
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
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
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
      if (_isRegisterMode) {
        await firebase.registerWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          tenantId: _tenantController.text.trim().toUpperCase(),
          role: _selectedRole,
        );
      } else {
        await firebase.signInWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isRegisterMode ? 'Account created successfully.' : 'Signed in successfully.'),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }
}
