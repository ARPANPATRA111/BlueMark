import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/constants/app_constants.dart';
import 'ble_payload_codec.dart';
import '../models/student_profile.dart';

class BleException implements Exception {
  BleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DetectedStudent {
  const DetectedStudent({
    required this.rollNumber,
    required this.rssi,
    required this.lastSeen,
    required this.sourceId,
  });

  final String rollNumber;
  final int rssi;
  final DateTime lastSeen;
  final String sourceId;

  DetectedStudent copyWith({
    String? rollNumber,
    int? rssi,
    DateTime? lastSeen,
    String? sourceId,
  }) {
    return DetectedStudent(
      rollNumber: rollNumber ?? this.rollNumber,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      sourceId: sourceId ?? this.sourceId,
    );
  }
}

class StudentAdvertiseStatus {
  const StudentAdvertiseStatus({
    required this.isAdvertising,
    required this.state,
    this.lastError,
  });

  final bool isAdvertising;
  final String state;
  final String? lastError;

  factory StudentAdvertiseStatus.fromJson(Map<dynamic, dynamic> json) {
    return StudentAdvertiseStatus(
      isAdvertising: json['isAdvertising'] == true,
      state: (json['state'] ?? 'unknown').toString(),
      lastError: json['lastError']?.toString(),
    );
  }
}

class BleDiagnostics {
  const BleDiagnostics({
    required this.scanBatches,
    required this.advertisementsSeen,
    required this.lastPacketAt,
    required this.detectedStudents,
    required this.minRssiThreshold,
    required this.staleSeconds,
    required this.isScanning,
  });

  final int scanBatches;
  final int advertisementsSeen;
  final DateTime? lastPacketAt;
  final int detectedStudents;
  final int minRssiThreshold;
  final int staleSeconds;
  final bool isScanning;
}

class BleService {
  BleService._();

  static final BleService instance = BleService._();
  static const MethodChannel _advertiseChannel = MethodChannel(AppConstants.bleAdvertiseChannel);

  final Guid _serviceGuid = Guid(AppConstants.bleServiceUuid);
  final Map<String, DetectedStudent> _detectedByRoll = <String, DetectedStudent>{};
  final StreamController<List<DetectedStudent>> _detectedController =
      StreamController<List<DetectedStudent>>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _cleanupTimer;
  bool _isStudentAdvertising = false;
  int _scanBatches = 0;
  int _advertisementPackets = 0;
  DateTime? _lastPacketAt;
  int _minRssiThreshold = -92;
  int _staleSeconds = AppConstants.detectionStaleSeconds;
  String _securityKey = AppConstants.defaultSecurityKey;
  static const int _maxTrackedStudents = 300;

  Stream<List<DetectedStudent>> get detectedStudentsStream => _detectedController.stream;

  List<DetectedStudent> get latestDetectedStudents {
    final list = _detectedByRoll.values.toList(growable: false)
      ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
    return list;
  }

  bool get isStudentAdvertising => _isStudentAdvertising;
  bool get isTeacherScanning => FlutterBluePlus.isScanningNow;

  BleDiagnostics get diagnostics => BleDiagnostics(
        scanBatches: _scanBatches,
        advertisementsSeen: _advertisementPackets,
        lastPacketAt: _lastPacketAt,
        detectedStudents: _detectedByRoll.length,
        minRssiThreshold: _minRssiThreshold,
        staleSeconds: _staleSeconds,
        isScanning: FlutterBluePlus.isScanningNow,
      );

  Future<BluetoothAdapterState> currentAdapterState() async {
    return FlutterBluePlus.adapterState.first;
  }

  Future<void> ensureBluetoothEnabled() async {
    final current = await currentAdapterState();
    if (current == BluetoothAdapterState.on) {
      return;
    }

    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn(timeout: 8);
      } catch (_) {
        throw BleException('Bluetooth is off. Please turn on Bluetooth and try again.');
      }
    }

    final after = await currentAdapterState();
    if (after != BluetoothAdapterState.on) {
      throw BleException('Bluetooth is not enabled on this device.');
    }
  }

  Future<void> startTeacherScan({
    int minRssiThreshold = -92,
    int staleSeconds = AppConstants.detectionStaleSeconds,
    String securityKey = AppConstants.defaultSecurityKey,
  }) async {
    await ensureBluetoothEnabled();
    _minRssiThreshold = minRssiThreshold;
    _staleSeconds = staleSeconds;
    _securityKey = securityKey;
    _scanBatches = 0;
    _advertisementPackets = 0;
    _lastPacketAt = null;

    _detectedByRoll.clear();
    _emitDetected();

    await stopTeacherScan();

    await FlutterBluePlus.startScan(
      withMsd: <MsdFilter>[MsdFilter(AppConstants.bleManufacturerId)],
      continuousUpdates: true,
      removeIfGone: const Duration(seconds: 8),
      continuousDivisor: 1,
      androidScanMode: AndroidScanMode.lowLatency,
      androidUsesFineLocation: true,
      androidCheckLocationServices: false,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _onScanResults,
      onError: (Object error, StackTrace stackTrace) {
        _detectedController.addError(error, stackTrace);
      },
    );

    _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _removeStaleDetections();
    });
  }

  void _onScanResults(List<ScanResult> results) {
    if (results.isNotEmpty) {
      _scanBatches += 1;
      _advertisementPackets += results.length;
      _lastPacketAt = DateTime.now();
    }

    final now = DateTime.now();
    for (final result in results) {
      if (result.rssi < _minRssiThreshold) {
        continue;
      }

      final roll = _extractRollNumber(result);
      if (roll == null || roll.isEmpty) {
        continue;
      }

      final normalizedRoll = roll.toUpperCase();
      final existing = _detectedByRoll[normalizedRoll];
      final mergedRssi = existing == null ? result.rssi : (result.rssi > existing.rssi ? result.rssi : existing.rssi);
      _detectedByRoll[normalizedRoll] = DetectedStudent(
        rollNumber: normalizedRoll,
        rssi: mergedRssi,
        lastSeen: now,
        sourceId: result.device.remoteId.str,
      );

      if (_detectedByRoll.length > _maxTrackedStudents) {
        final oldest = _detectedByRoll.entries.toList(growable: false)
          ..sort((a, b) => a.value.lastSeen.compareTo(b.value.lastSeen));
        final removeCount = _detectedByRoll.length - _maxTrackedStudents;
        for (var i = 0; i < removeCount; i++) {
          _detectedByRoll.remove(oldest[i].key);
        }
      }
    }

    _removeStaleDetections(emit: false);
    _emitDetected();
  }

  String? _extractRollNumber(ScanResult result) {
    final ad = result.advertisementData;

    final manufacturerBytes = ad.manufacturerData[AppConstants.bleManufacturerId];
    if (manufacturerBytes != null && manufacturerBytes.isNotEmpty) {
      final verified = BlePayloadCodec.decodeAndVerify(
        manufacturerBytes,
        secret: _securityKey,
        allowUnsignedFallback: true,
      );
      if (verified != null && verified.rollNumber.isNotEmpty) {
        return verified.rollNumber;
      }

      final decoded = _decodeRoll(manufacturerBytes);
      if (decoded.isNotEmpty) {
        return decoded;
      }
    }

    for (final entry in ad.manufacturerData.entries) {
      final bytes = entry.value;
      if (bytes.isEmpty) {
        continue;
      }
      final verified = BlePayloadCodec.decodeAndVerify(
        bytes,
        secret: _securityKey,
        allowUnsignedFallback: true,
      );
      if (verified != null && verified.rollNumber.isNotEmpty) {
        return verified.rollNumber;
      }

      final decoded = _decodeRoll(bytes);
      if (decoded.isNotEmpty) {
        return decoded;
      }
    }

    final serviceData = ad.serviceData[_serviceGuid];
    if (serviceData != null && serviceData.isNotEmpty) {
      final decoded = _decodeRoll(serviceData);
      if (decoded.isNotEmpty) {
        return decoded;
      }
    }

    final name = ad.advName;
    final fromName = BlePayloadCodec.decodeFromAdvertisedName(name);
    if (fromName != null && fromName.isNotEmpty) {
      return fromName;
    }

    return null;
  }

  String _decodeRoll(List<int> bytes) {
    return BlePayloadCodec.decodeRollBytes(bytes);
  }

  void _removeStaleDetections({bool emit = true}) {
    final threshold = DateTime.now().subtract(Duration(seconds: _staleSeconds));
    _detectedByRoll.removeWhere((_, value) => value.lastSeen.isBefore(threshold));
    if (emit) {
      _emitDetected();
    }
  }

  void _emitDetected() {
    final list = _detectedByRoll.values.toList(growable: false)
      ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
    _detectedController.add(list);
  }

  Future<void> stopTeacherScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> startStudentAdvertising(
    StudentProfile profile, {
    String securityKey = AppConstants.defaultSecurityKey,
  }) async {
    await ensureBluetoothEnabled();
    _securityKey = securityKey;

    try {
      await _advertiseChannel.invokeMethod<void>('startAdvertising', <String, dynamic>{
        'rollNumber': profile.rollNumber.toUpperCase(),
        'serviceUuid': AppConstants.bleServiceUuid,
        'manufacturerId': AppConstants.bleManufacturerId,
        'payload': BlePayloadCodec.encodeRoll(profile.rollNumber, secret: _securityKey),
      });

      for (var i = 0; i < 6; i++) {
        final status = await getStudentAdvertisingStatus();
        if (status.isAdvertising) {
          _isStudentAdvertising = true;
          return;
        }

        if (status.state == 'error') {
          throw BleException(status.lastError ?? 'Broadcast failed to start.');
        }

        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

      final latest = await getStudentAdvertisingStatus();
      _isStudentAdvertising = latest.isAdvertising;
      if (!_isStudentAdvertising) {
        throw BleException(latest.lastError ?? 'Broadcast did not start. Try toggling Bluetooth and retry.');
      }
    } on MissingPluginException {
      throw BleException('BLE advertising bridge is unavailable on this platform build.');
    } on PlatformException catch (error) {
      throw BleException(error.message ?? 'Failed to start BLE advertising.');
    }
  }

  Future<StudentAdvertiseStatus> getStudentAdvertisingStatus() async {
    try {
      final map = await _advertiseChannel.invokeMethod<Map<dynamic, dynamic>>('getAdvertisingStatus');
      if (map == null) {
        return const StudentAdvertiseStatus(
          isAdvertising: false,
          state: 'unknown',
          lastError: 'No status from native advertiser.',
        );
      }
      return StudentAdvertiseStatus.fromJson(map);
    } on PlatformException catch (error) {
      return StudentAdvertiseStatus(
        isAdvertising: false,
        state: 'error',
        lastError: error.message,
      );
    } on MissingPluginException {
      return const StudentAdvertiseStatus(
        isAdvertising: false,
        state: 'unsupported',
        lastError: 'Native advertising status is unavailable on this platform build.',
      );
    }
  }

  Future<void> stopStudentAdvertising() async {
    try {
      await _advertiseChannel.invokeMethod<void>('stopAdvertising');
    } catch (_) {
    } finally {
      _isStudentAdvertising = false;
    }
  }

  Future<void> dispose() async {
    await stopTeacherScan();
    await stopStudentAdvertising();
    await _detectedController.close();
  }
}
