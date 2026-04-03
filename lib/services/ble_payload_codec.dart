import '../core/constants/app_constants.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';

class DecodedBlePayload {
  const DecodedBlePayload({
    required this.rollNumber,
    required this.slot,
    required this.signature,
  });

  final String rollNumber;
  final int slot;
  final String signature;
}

class BlePayloadCodec {
  const BlePayloadCodec._();

  static List<int> encodeRoll(
    String rollNumber, {
    String secret = AppConstants.defaultSecurityKey,
    DateTime? now,
  }) {
    final normalized = rollNumber.trim().toUpperCase();
    final slot = _currentSlot(now ?? DateTime.now());
    final slotEncoded = _encodeSlot(slot);
    final signature = _signPayload(normalized, slotEncoded, secret);
    return '${AppConstants.blePayloadPrefix}$normalized|$slotEncoded|$signature'.codeUnits;
  }

  static String decodeRollBytes(List<int> bytes) {
    final verified = decodeAndVerify(
      bytes,
      secret: AppConstants.defaultSecurityKey,
      allowUnsignedFallback: true,
    );
    if (verified != null) {
      return verified.rollNumber;
    }
    return _decodeLegacy(bytes);
  }

  static DecodedBlePayload? decodeAndVerify(
    List<int> bytes, {
    required String secret,
    DateTime? now,
    int toleranceSlots = 1,
    bool allowUnsignedFallback = false,
  }) {
    final sanitized = bytes.where((e) => e != 0).toList(growable: false);
    final decoded = utf8.decode(sanitized, allowMalformed: true).trim().toUpperCase();

    if (decoded.startsWith(AppConstants.blePayloadPrefix)) {
      final body = decoded.substring(AppConstants.blePayloadPrefix.length);
      final parts = body.split('|');
      if (parts.length >= 3) {
        final roll = parts[0].trim();
        final slotEncoded = parts[1].trim();
        final signature = parts[2].trim();
        final slot = _decodeSlot(slotEncoded);
        if (roll.isNotEmpty && slot != null && signature.isNotEmpty) {
          final expected = _signPayload(roll, slotEncoded, secret);
          if (expected == signature) {
            final nowSlot = _currentSlot(now ?? DateTime.now());
            final delta = (nowSlot - slot).abs();
            if (delta <= toleranceSlots) {
              return DecodedBlePayload(
                rollNumber: roll,
                slot: slot,
                signature: signature,
              );
            }
          }
        }
      }

      if (!allowUnsignedFallback) {
        return null;
      }
    }

    if (!allowUnsignedFallback) {
      return null;
    }

    final legacy = _decodeLegacy(bytes);
    if (legacy.isEmpty) {
      return null;
    }

    return DecodedBlePayload(
      rollNumber: legacy,
      slot: _currentSlot(now ?? DateTime.now()),
      signature: 'LEGACY',
    );
  }

  static String? decodeFromAdvertisedName(String advertisedName) {
    final name = advertisedName.trim();
    if (!name.startsWith(AppConstants.bleNamePrefix)) {
      return null;
    }
    final roll = name.substring(AppConstants.bleNamePrefix.length).trim();
    return roll.isEmpty ? null : roll.toUpperCase();
  }

  static int _currentSlot(DateTime now) {
    return now.millisecondsSinceEpoch ~/ (AppConstants.bleRollingTokenWindowSeconds * 1000);
  }

  static String _encodeSlot(int slot) => slot.toRadixString(36).toUpperCase();

  static int? _decodeSlot(String slot) {
    return int.tryParse(slot, radix: 36);
  }

  static String _signPayload(String roll, String slot, String secret) {
    final digest = sha256.convert(utf8.encode('$roll|$slot|$secret')).toString().toUpperCase();
    return digest.substring(0, 10);
  }

  static String _decodeLegacy(List<int> bytes) {
    final sanitized = bytes.where((e) => e != 0).toList(growable: false);
    final decoded = String.fromCharCodes(sanitized).trim().toUpperCase();

    if (decoded.startsWith(AppConstants.blePayloadPrefix)) {
      final body = decoded.substring(AppConstants.blePayloadPrefix.length).trim();
      final firstSegment = body.split('|').first.trim();
      if (firstSegment.isNotEmpty) {
        return firstSegment;
      }
    }

    if (decoded.startsWith(AppConstants.bleNamePrefix)) {
      return decoded.substring(AppConstants.bleNamePrefix.length).trim();
    }

    final rollRegex = RegExp(r'^[A-Z0-9_-]{4,24}$');
    if (rollRegex.hasMatch(decoded)) {
      return decoded;
    }

    return '';
  }
}
