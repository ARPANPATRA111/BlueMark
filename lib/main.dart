import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_home_screen.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/role_selector_screen.dart';
import 'features/student/presentation/student_screen.dart';
import 'features/teacher/presentation/teacher_home_screen.dart';
import 'models/app_user_role.dart';

bool _isFirestorePermissionDenied(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('cloud_firestore/permission-denied') ||
      text.contains('permission-denied');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BluetoothAttendanceApp()));
}

class BluetoothAttendanceApp extends ConsumerWidget {
  const BluetoothAttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: bootstrap.when(
        data: (_) => const _RoleRouter(),
        loading: () => const _LoadingScreen(),
        error: (error, _) => _isFirestorePermissionDenied(error)
            ? const _RoleRouter()
            : _BootstrapErrorScreen(error: error),
      ),
    );
  }
}

class _RoleRouter extends ConsumerWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebase = ref.watch(firebaseServiceProvider);
    if (!firebase.isEnabled) {
      final role = ref.watch(appRoleProvider);
      switch (role) {
        case AppUserRole.admin:
          return const TeacherHomeScreen();
        case AppUserRole.teacher:
          return const TeacherHomeScreen();
        case AppUserRole.pendingTeacher:
          return const _TeacherApprovalPendingScreen();
        case AppUserRole.student:
          return const StudentScreen();
        case AppUserRole.unknown:
          return const RoleSelectorScreen();
      }
    }

    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (firebaseUser) {
        if (firebaseUser == null) {
          return const AuthScreen();
        }

        final appUserState = ref.watch(currentAppUserProvider);
        return appUserState.when(
          data: (appUser) {
            if (appUser == null || !appUser.isActive) {
              return const _ProfileMissingScreen();
            }

            switch (appUser.role) {
              case AppUserRole.admin:
                return const AdminHomeScreen();
              case AppUserRole.teacher:
                return const TeacherHomeScreen();
              case AppUserRole.pendingTeacher:
                return const _TeacherApprovalPendingScreen();
              case AppUserRole.student:
                return const StudentScreen();
              case AppUserRole.unknown:
                return const AuthScreen();
            }
          },
          loading: () => const _LoadingScreen(),
          error: (error, _) => _isFirestorePermissionDenied(error)
              ? const _ProfileMissingScreen()
              : _BootstrapErrorScreen(error: error),
        );
      },
      loading: () => const _LoadingScreen(),
      error: (error, _) => _isFirestorePermissionDenied(error)
          ? const AuthScreen()
          : _BootstrapErrorScreen(error: error),
    );
  }
}

class _ProfileMissingScreen extends ConsumerWidget {
  const _ProfileMissingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.manage_accounts_rounded, size: 46),
              const SizedBox(height: 12),
              Text(
                'Account profile is missing or inactive',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please contact your institution admin or sign in again with a provisioned account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => ref.read(firebaseServiceProvider).signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _TeacherApprovalPendingScreen extends ConsumerWidget {
  const _TeacherApprovalPendingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pending_actions_rounded, size: 46),
              const SizedBox(height: 12),
              Text(
                'Teacher access pending approval',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account was created successfully. Please ask your institution admin to approve your teacher request from User Management.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => ref.read(firebaseServiceProvider).signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(
                'Initialization failed',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
