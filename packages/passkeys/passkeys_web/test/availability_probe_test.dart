import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys_web/src/availability_probe.dart';

void main() {
  group('optionalAvailabilityProbe', () {
    test('returns the probe value', () async {
      await expectLater(
        optionalAvailabilityProbe(() async => true),
        completion(isTrue),
      );

      await expectLater(
        optionalAvailabilityProbe(() async => false),
        completion(isFalse),
      );
    });

    test('returns null when the probe throws', () async {
      await expectLater(
        optionalAvailabilityProbe(() async => throw Exception('blocked')),
        completion(isNull),
      );
    });
  });
}
