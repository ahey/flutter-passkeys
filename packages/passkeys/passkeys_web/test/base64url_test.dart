import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys_web/src/base64url.dart';

void main() {
  group('base64UrlNoPadding', () {
    test('encodes without padding', () {
      // 'M' → 'TQ==' in padded base64.
      expect(base64UrlNoPadding(Uint8List.fromList([0x4d])), 'TQ');
      // 'Ma' → 'TWE=' in padded base64.
      expect(base64UrlNoPadding(Uint8List.fromList([0x4d, 0x61])), 'TWE');
      // 'Man' needs no padding.
      expect(
        base64UrlNoPadding(Uint8List.fromList([0x4d, 0x61, 0x6e])),
        'TWFu',
      );
    });

    test('uses the url-safe alphabet', () {
      // '---__w' in base64url is '+++//w' in standard base64.
      expect(
        base64UrlNoPadding(Uint8List.fromList([0xfb, 0xef, 0xbf, 0xff])),
        '---__w',
      );
    });

    test('encodes empty input to an empty string', () {
      expect(base64UrlNoPadding(Uint8List(0)), '');
    });
  });

  group('base64UrlDecode', () {
    test('decodes unpadded input', () {
      expect(base64UrlDecode('TQ'), [0x4d]);
      expect(base64UrlDecode('TWE'), [0x4d, 0x61]);
      expect(base64UrlDecode('TWFu'), [0x4d, 0x61, 0x6e]);
    });

    test('decodes padded input', () {
      expect(base64UrlDecode('TQ=='), [0x4d]);
    });

    test('decodes the url-safe alphabet', () {
      expect(base64UrlDecode('---__w'), [0xfb, 0xef, 0xbf, 0xff]);
    });

    test('round-trips with base64UrlNoPadding', () {
      final bytes = Uint8List.fromList(List.generate(33, (i) => i * 7 % 256));

      expect(base64UrlDecode(base64UrlNoPadding(bytes)), bytes);
    });
  });
}
