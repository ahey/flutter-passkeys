/// Runs an availability probe and converts failures into a nullable result.
Future<bool?> optionalAvailabilityProbe(Future<bool> Function() probe) async {
  try {
    return await probe();
  } catch (_) {
    return null;
  }
}
