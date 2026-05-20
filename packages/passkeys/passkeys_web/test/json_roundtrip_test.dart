import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys_web/models/passkey_login_response.dart';
import 'package:passkeys_web/models/passkey_sign_up_response.dart';

/// Verifies that the WebAuthn JSON response shape built by the plugin's own
/// credential serializer decodes correctly into the Dart response models
/// used by passkeys_web.
///
/// Fixtures are hand-written per the WebAuthn JSON spec rather than
/// captured from a live browser, so this test runs without any browser
/// dependency.
void main() {
  group('PublicKeyCredential.toJSON round-trip', () {
    test('registration response decodes into PasskeySignUpResponse', () {
      final fixture = <String, dynamic>{
        'id': 'AQIDBAUGBwgJCgsMDQ4PEA',
        'rawId': 'AQIDBAUGBwgJCgsMDQ4PEA',
        'type': 'public-key',
        'authenticatorAttachment': 'platform',
        'response': <String, dynamic>{
          'clientDataJSON': 'eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIn0',
          'attestationObject': 'o2NmbXRoZmlkby11MmZnYXR0U3RtdKA',
          'transports': <String>['internal', 'hybrid'],
          'publicKeyAlgorithm': -7,
          'publicKey': 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE',
        },
        'clientExtensionResults': <String, dynamic>{},
      };

      final decoded = PasskeySignUpResponse.fromJson(fixture);

      expect(decoded.id, 'AQIDBAUGBwgJCgsMDQ4PEA');
      expect(decoded.rawId, 'AQIDBAUGBwgJCgsMDQ4PEA');
      expect(
        decoded.response.clientDataJSON,
        'eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIn0',
      );
      expect(
        decoded.response.attestationObject,
        'o2NmbXRoZmlkby11MmZnYXR0U3RtdKA',
      );
      expect(decoded.response.transports, ['internal', 'hybrid']);
    });

    test('authentication response decodes into PasskeyLoginResponse', () {
      final fixture = <String, dynamic>{
        'id': 'AQIDBAUGBwgJCgsMDQ4PEA',
        'rawId': 'AQIDBAUGBwgJCgsMDQ4PEA',
        'type': 'public-key',
        'authenticatorAttachment': 'platform',
        'response': <String, dynamic>{
          'clientDataJSON': 'eyJ0eXBlIjoid2ViYXV0aG4uZ2V0In0',
          'authenticatorData': 'SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2M',
          'signature': 'MEUCIQDxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          'userHandle': 'dXNlci1oYW5kbGU',
        },
        'clientExtensionResults': <String, dynamic>{},
      };

      final decoded = PasskeyLoginResponse.fromJson(fixture);

      expect(decoded.id, 'AQIDBAUGBwgJCgsMDQ4PEA');
      expect(decoded.rawId, 'AQIDBAUGBwgJCgsMDQ4PEA');
      expect(
        decoded.response.clientDataJSON,
        'eyJ0eXBlIjoid2ViYXV0aG4uZ2V0In0',
      );
      expect(
        decoded.response.authenticatorData,
        'SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2M',
      );
      expect(decoded.response.signature, isNotEmpty);
      expect(decoded.response.userHandle, 'dXNlci1oYW5kbGU');

      final platform = decoded.toAuthenticateResponseType();
      expect(platform.userHandle, 'dXNlci1oYW5kbGU');
    });

    test('authentication response tolerates null userHandle', () {
      final fixture = <String, dynamic>{
        'id': 'AQ',
        'rawId': 'AQ',
        'type': 'public-key',
        'response': <String, dynamic>{
          'clientDataJSON': 'eyJ9',
          'authenticatorData': 'AQ',
          'signature': 'AQ',
          'userHandle': null,
        },
      };

      final decoded = PasskeyLoginResponse.fromJson(fixture);
      expect(decoded.response.userHandle, isNull);

      final platform = decoded.toAuthenticateResponseType();
      expect(platform.userHandle, '');
    });
  });
}
