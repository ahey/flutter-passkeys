import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys_web/src/prf.dart';

void main() {
  group('PrfClientOutputs', () {
    test('serializes enabled without results (registration)', () {
      const outputs = PrfClientOutputs(enabled: true);

      expect(outputs.toJson(), {'enabled': true});
    });

    test('serializes results without enabled (authentication)', () {
      const outputs = PrfClientOutputs(first: 'Zmlyc3Q');

      expect(outputs.toJson(), {
        'results': {'first': 'Zmlyc3Q'},
      });
    });

    test('serializes both results when present', () {
      const outputs = PrfClientOutputs(first: 'Zmlyc3Q', second: 'c2Vjb25k');

      expect(outputs.toJson(), {
        'results': {'first': 'Zmlyc3Q', 'second': 'c2Vjb25k'},
      });
    });

    test('omits a second result that has no first', () {
      const outputs = PrfClientOutputs(second: 'c2Vjb25k');

      expect(outputs.toJson(), isEmpty);
    });
  });

  group('mergePrfOutputs', () {
    test('returns the results untouched when there is no PRF output', () {
      final results = <String, dynamic>{'credProps': <String, dynamic>{}};

      expect(mergePrfOutputs(results, null), same(results));
    });

    test('replaces a degraded prf entry and keeps other outputs', () {
      // JSON.stringify degrades the ArrayBuffers in prf.results to empty
      // objects; the merged entry must win.
      final results = <String, dynamic>{
        'credProps': {'rk': true},
        'prf': {
          'results': {'first': <String, dynamic>{}},
        },
      };

      final merged = mergePrfOutputs(
        results,
        const PrfClientOutputs(first: 'Zmlyc3Q'),
      );

      expect(merged, {
        'credProps': {'rk': true},
        'prf': {
          'results': {'first': 'Zmlyc3Q'},
        },
      });
    });
  });

  group('applyPrf', () {
    test('does nothing when no PRF input is given', () {
      final requestJson = <String, dynamic>{
        'publicKey': <String, dynamic>{'challenge': 'AQ'},
      };

      applyPrf(requestJson, null);

      expect(
        (requestJson['publicKey'] as Map<String, dynamic>).containsKey(
          'extensions',
        ),
        isFalse,
      );
    });

    test('adds the PRF eval input as a base64url string', () {
      final requestJson = <String, dynamic>{
        'publicKey': <String, dynamic>{'challenge': 'AQ'},
      };

      applyPrf(requestJson, 'c2FsdC1pbnB1dA');

      final publicKey = requestJson['publicKey'] as Map<String, dynamic>;
      expect(publicKey['extensions'], {
        'prf': {
          'eval': {'first': 'c2FsdC1pbnB1dA'},
        },
      });
    });

    test('preserves existing extensions', () {
      final requestJson = <String, dynamic>{
        'publicKey': <String, dynamic>{
          'challenge': 'AQ',
          'extensions': <String, dynamic>{'credProps': true},
        },
      };

      applyPrf(requestJson, 'c2FsdC1pbnB1dA');

      final publicKey = requestJson['publicKey'] as Map<String, dynamic>;
      final extensions = publicKey['extensions'] as Map<String, dynamic>;
      expect(extensions['credProps'], isTrue);
      expect(extensions['prf'], {
        'eval': {'first': 'c2FsdC1pbnB1dA'},
      });
    });
  });
}
