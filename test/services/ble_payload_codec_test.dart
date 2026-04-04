import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_attendance_tracker/services/ble_payload_codec.dart';

void main() {
  group('BlePayloadCodec', () {
    test('encodeRoll prefixes and normalizes payload', () {
      final encoded = BlePayloadCodec.encodeRoll('cse23a001');
      final decoded = String.fromCharCodes(encoded);
      expect(decoded.startsWith('BAT:CSE23A001|'), isTrue);
      expect(decoded.split('|').length, 3);
    });

    test('decodeRollBytes strips zero padding and BAT prefix', () {
      final encoded = BlePayloadCodec.encodeRoll('CSE23A001');
      final bytes = <int>[...encoded, 0, 0];
      final roll = BlePayloadCodec.decodeRollBytes(bytes);
      expect(roll, 'CSE23A001');
    });

    test('decodeRollBytes rejects unrelated payloads', () {
      final bytes = <int>[1, 4, 9, 12, 31, 44];
      final roll = BlePayloadCodec.decodeRollBytes(bytes);
      expect(roll, isEmpty);
    });

    test('decodeFromAdvertisedName parses valid prefixed names', () {
      expect(BlePayloadCodec.decodeFromAdvertisedName('STU:CSE23A009'), 'CSE23A009');
      expect(BlePayloadCodec.decodeFromAdvertisedName('random'), isNull);
    });

    test('decodeAndVerify validates signature', () {
      final encoded = BlePayloadCodec.encodeRoll('CSE23A111', secret: 'secret-1');
      final verified = BlePayloadCodec.decodeAndVerify(encoded, secret: 'secret-1');
      expect(verified, isNotNull);
      expect(verified!.rollNumber, 'CSE23A111');

      final invalid = BlePayloadCodec.decodeAndVerify(encoded, secret: 'wrong-secret');
      expect(invalid, isNull);
    });
  });
}
