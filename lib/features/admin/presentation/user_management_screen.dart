import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../models/app_user_role.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(tenantUsersProvider);
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    final canManage = currentUser?.role == AppUserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found for this tenant.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(user.email),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<AppUserRole>(
                              initialValue: user.role,
                              decoration: const InputDecoration(labelText: 'Role'),
                              items: const [
                                DropdownMenuItem(
                                  value: AppUserRole.admin,
                                  child: Text('Institution Admin'),
                                ),
                                DropdownMenuItem(
                                  value: AppUserRole.teacher,
                                  child: Text('Teacher'),
                                ),
                                DropdownMenuItem(
                                  value: AppUserRole.student,
                                  child: Text('Student'),
                                ),
                              ],
                              onChanged: canManage
                                  ? (value) async {
                                      if (value == null || value == user.role) {
                                        return;
                                      }

                                      try {
                                        await ref.read(firebaseServiceProvider).updateTenantUserRole(
                                              userId: user.uid,
                                              role: value,
                                            );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Updated role for ${user.displayName}.')),
                                          );
                                        }
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to update role: $error')),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: user.isActive,
                              title: const Text('Active'),
                              onChanged: canManage
                                  ? (value) async {
                                      try {
                                        await ref.read(firebaseServiceProvider).setTenantUserActive(
                                              userId: user.uid,
                                              isActive: value,
                                            );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Updated status for ${user.displayName}.')),
                                          );
                                        }
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to update active status: $error')),
                                          );
                                        }
                                      }
                                    }
                                  : null,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load users: $error')),
      ),
    );
  }
}
