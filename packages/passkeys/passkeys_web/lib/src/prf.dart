/// PRF extension client outputs with binary values base64url encoded.
class PrfClientOutputs {
  /// Creates PRF client outputs.
  const PrfClientOutputs({this.enabled, this.first, this.second});

  /// Whether the authenticator supports the PRF extension (registration).
  final bool? enabled;

  /// The base64url encoded first PRF result (authentication).
  final String? first;

  /// The base64url encoded second PRF result, when two inputs were given.
  final String? second;

  /// Serializes these outputs to the WebAuthn JSON shape.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (enabled != null) {
      json['enabled'] = enabled;
    }

    final first = this.first;
    if (first != null) {
      final results = <String, dynamic>{'first': first};
      if (second != null) {
        results['second'] = second;
      }
      json['results'] = results;
    }

    return json;
  }
}

/// Replaces the `prf` entry of [clientExtensionResults] with the manually
/// extracted [prf] outputs.
///
/// The plugin extracts PRF outputs itself (from
/// `getClientExtensionResults()`) because they contain `ArrayBuffer`s that a
/// plain JSON serialization degrades to empty objects.
Map<String, dynamic> mergePrfOutputs(
  Map<String, dynamic> clientExtensionResults,
  PrfClientOutputs? prf,
) {
  if (prf == null) {
    return clientExtensionResults;
  }

  return {...clientExtensionResults, 'prf': prf.toJson()};
}

/// Adds the WebAuthn PRF extension salt to the serialized [requestJson].
///
/// [prf] is the base64url-encoded first PRF eval input. The browser's
/// `parseCreationOptionsFromJSON` / `parseRequestOptionsFromJSON` convert it
/// to the `ArrayBuffer` the authenticator expects.
void applyPrf(Map<String, dynamic> requestJson, String? prf) {
  if (prf == null) {
    return;
  }

  final publicKey = requestJson['publicKey'] as Map<String, dynamic>;
  final extensions =
      (publicKey['extensions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  extensions['prf'] = {
    'eval': {'first': prf},
  };
  publicKey['extensions'] = extensions;
}
