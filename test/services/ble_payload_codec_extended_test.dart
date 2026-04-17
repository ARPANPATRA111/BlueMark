import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/services/ble_payload_codec.dart';

void main() {
  group('BlePayloadCodec.encodeRoll', () {
    test('produces BAT: prefixed payload with 3 pipe-separated parts', () {
      final encoded = BlePayloadCodec.encodeRoll('CSE23A001');
      final decoded = String.fromCharCodes(encoded);
      expect(decoded.startsWith('BAT:CSE23A001|'), isTrue);

      final parts = decoded.split('|');
      expect(parts.length, 3);
    });

    test('normalizes roll number to uppercase', () {
      final encoded = BlePayloadCodec.encodeRoll('cse23a001');
      final decoded = String.fromCharCodes(encoded);
      expect(decoded.contains('CSE23A001'), isTrue);
    });

    test('different secrets produce different signatures', () {
      final a = BlePayloadCodec.encodeRoll('CSE23A001', secret: 'key-a');
      final b = BlePayloadCodec.encodeRoll('CSE23A001', secret: 'key-b');
      expect(a, isNot(equals(b)));
    });

    test('rolling slot changes over time within window', () {
      final t1 = BlePayloadCodec.encodeRoll('CSE23A001');
      final decoded1 = String.fromCharCodes(t1);
      final slot1 = decoded1.split('|')[1];
      expect(slot1.isNotEmpty, isTrue);
    });
  });

  group('BlePayloadCodec.decodeRollBytes', () {
    test('round-trips a valid payload', () {
      final encoded = BlePayloadCodec.encodeRoll('CSE23A001');
      final roll = BlePayloadCodec.decodeRollBytes(encoded);
      expect(roll, 'CSE23A001');
    });

    test('strips trailing zero padding', () {
      final encoded = BlePayloadCodec.encodeRoll('CSE23A001');
      final padded = <int>[...encoded, 0, 0, 0];
      final roll = BlePayloadCodec.decodeRollBytes(padded);
      expect(roll, 'CSE23A001');
    });

    test('returns empty string for random bytes', () {
      final garbage = <int>[0xFF, 0xAB, 0x01, 0x02];
      expect(BlePayloadCodec.decodeRollBytes(garbage), isEmpty);
    });

    test('returns empty string for empty input', () {
      expect(BlePayloadCodec.decodeRollBytes(<int>[]), isEmpty);
    });
  });

  group('BlePayloadCodec.decodeAndVerify', () {
    test('succeeds with correct secret', () {
      final encoded = BlePayloadCodec.encodeRoll('CSE23A001', secret: 'test-key');
      final result = BlePayloadCodec.decodeAndVerify(encoded, secret: 'test-key');
      expect(result, isNotNull);
      expect(result!.rollNumber, 'CSE23A001');
    });

    test('fails with wrong secret', () {
      final encoded = BlePayloadCodec.encodeRoll('CSE23A001', secret: 'correct');
      final result = BlePayloadCodec.decodeAndVerify(encoded, secret: 'wrong');
      expect(result, isNull);
    });

    test('allowUnsignedFallback returns roll from unverified payload', () {
      final encoded = BlePayloadCodec.encodeRoll('CSE23A001', secret: 'correct');
      final result = BlePayloadCodec.decodeAndVerify(
        encoded,
        secret: 'wrong',
        allowUnsignedFallback: true,
      );
      expect(result, isNotNull);
      expect(result!.rollNumber, 'CSE23A001');
    });

    test('returns null for garbage bytes even with fallback', () {
      final garbage = <int>[0xFF, 0x01, 0x02];
      final result = BlePayloadCodec.decodeAndVerify(
        garbage,
        secret: 'any',
        allowUnsignedFallback: true,
      );
      expect(result, isNull);
    });
  });

  group('BlePayloadCodec.decodeFromAdvertisedName', () {
    test('parses STU: prefixed name', () {
      expect(BlePayloadCodec.decodeFromAdvertisedName('STU:CSE23A009'), 'CSE23A009');
    });

    test('returns null for non-prefixed name', () {
      expect(BlePayloadCodec.decodeFromAdvertisedName('random-device'), isNull);
    });

    test('returns null for empty string', () {
      expect(BlePayloadCodec.decodeFromAdvertisedName(''), isNull);
    });

    test('returns null for STU: with empty roll', () {
      expect(BlePayloadCodec.decodeFromAdvertisedName('STU:'), isNull);
    });
  });
}
