import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionResult {
  const PermissionResult({
    required this.isGranted,
    required this.message,
    this.missingPermissions = const <Permission>[],
  });

  final bool isGranted;
  final String message;
  final List<Permission> missingPermissions;
}

class PermissionService {
  Future<PermissionResult> requestStudentPermissions() async {
    final result = await _request(
      <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        if (Platform.isAndroid) Permission.locationWhenInUse,
        if (Platform.isAndroid) Permission.notification,
      ],
      successMessage: 'All required permissions granted for student broadcast mode.',
    );

    return _validateAndroidRuntimeServices(result);
  }

  Future<PermissionResult> requestTeacherPermissions() async {
    final result = await _request(
      <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        if (Platform.isAndroid) Permission.locationWhenInUse,
        if (Platform.isAndroid) Permission.notification,
      ],
      successMessage: 'All required permissions granted for attendance scan mode.',
    );

    return _validateAndroidRuntimeServices(result);
  }

  Future<PermissionResult> _request(
    List<Permission> permissions, {
    required String successMessage,
  }) async {
    final statuses = await permissions.request();

    final denied = <Permission>[];
    final permanentlyDenied = <Permission>[];

    for (final permission in permissions) {
      final status = statuses[permission] ?? PermissionStatus.denied;
      if (!status.isGranted) {
        denied.add(permission);
      }
      if (status.isPermanentlyDenied) {
        permanentlyDenied.add(permission);
      }
    }

    if (denied.isEmpty) {
      return PermissionResult(isGranted: true, message: successMessage);
    }

    if (permanentlyDenied.isNotEmpty) {
      return PermissionResult(
        isGranted: false,
        missingPermissions: denied,
        message:
            'Some permissions are permanently denied. Open app settings and allow Bluetooth + location permissions.',
      );
    }

    return PermissionResult(
      isGranted: false,
      missingPermissions: denied,
      message: 'Bluetooth permissions are required to continue.',
    );
  }

  Future<bool> requestIgnoreBatteryOptimization() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<PermissionResult> _validateAndroidRuntimeServices(PermissionResult current) async {
    if (!current.isGranted || !Platform.isAndroid) {
      return current;
    }

    final locationServiceStatus = await Permission.locationWhenInUse.serviceStatus;
    if (locationServiceStatus != ServiceStatus.enabled) {
      return const PermissionResult(
        isGranted: false,
        message:
            'Android BLE scanning requires Location Services ON (device GPS toggle) and Bluetooth ON. Please enable both and retry.',
      );
    }

    return current;
  }
}
