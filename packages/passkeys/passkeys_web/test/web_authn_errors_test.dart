import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys_web/src/web_authn_errors.dart';

void main() {
  group('mapWebAuthnError', () {
    test('maps NotAllowedError to cancelled', () {
      final error = mapWebAuthnError(
        const WebAuthnErrorDetails(
          name: 'NotAllowedError',
          message: 'The operation either timed out or was not allowed.',
          fallbackText: '',
        ),
      );

      expect(error.code, 'cancelled');
      expect(error.message, 'operation was cancelled by the user.');
      expect(error.details, '');
    });

    test('passes through other DOMException names', () {
      final error = mapWebAuthnError(
        const WebAuthnErrorDetails(
          name: 'SecurityError',
          message: 'The RP domain is not valid.',
          fallbackText: '',
        ),
      );

      expect(error.code, 'SecurityError');
      expect(error.message, 'The RP domain is not valid.');
      expect(error.details, '');
    });

    test('maps explicit abort reason to suppressed', () {
      final error = mapWebAuthnError(
        const WebAuthnErrorDetails(fallbackText: abortedByUser),
      );

      expect(error.code, 'suppressed');
      expect(error.message, abortedByUser);
      expect(error.details, '');
    });

    test('maps unstructured errors to unknown', () {
      final error = mapWebAuthnError(
        const WebAuthnErrorDetails(fallbackText: 'unexpected failure'),
      );

      expect(error.code, 'unknown');
      expect(error.message, 'unexpected failure');
      expect(error.details, '');
    });
  });
}
