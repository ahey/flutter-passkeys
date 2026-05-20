// ignore_for_file: public_member_api_docs

@JS()
library;

import 'dart:js_interop';

@JS('PublicKeyCredential')
external JSAny? get publicKeyCredentialCtor;

@JS('PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable')
external JSPromise<JSBoolean> isUserVerifyingPlatformAuthenticatorAvailable();

@JS('PublicKeyCredential.isConditionalMediationAvailable')
external JSPromise<JSBoolean> isConditionalMediationAvailable();

@JS('PublicKeyCredential.signalUnknownCredential')
external JSPromise<JSAny?> signalUnknownCredential(JSObject options);

@JS('PublicKeyCredential.signalAllAcceptedCredentials')
external JSPromise<JSAny?> signalAllAcceptedCredentials(JSObject options);

@JS('navigator')
external Navigator get navigator;

extension type Navigator._(JSObject _) implements JSObject {
  external CredentialsContainer get credentials;
}

extension type CredentialsContainer._(JSObject _) implements JSObject {
  external JSPromise<JSObject?> create(CredentialCreationOptions options);
  @JS('get')
  external JSPromise<JSObject?> getCredential(CredentialRequestOptions options);
}

extension type CredentialCreationOptions._(JSObject _) implements JSObject {
  external factory CredentialCreationOptions({
    JSObject publicKey,
    AbortSignal? signal,
  });
}

extension type CredentialRequestOptions._(JSObject _) implements JSObject {
  external factory CredentialRequestOptions({
    JSObject publicKey,
    String? mediation,
    AbortSignal? signal,
  });
}

extension type PublicKeyCredentialInstance._(JSObject _) implements JSObject {
  external String get id;
  external JSObject getClientExtensionResults();
  @JS('response')
  external AttestationResponseJS get attestationResponse;
  @JS('response')
  external AssertionResponseJS get assertionResponse;
}

extension type AttestationResponseJS._(JSObject _) implements JSObject {
  external JSArrayBuffer get clientDataJSON;
  external JSArrayBuffer get attestationObject;
  @JS('getTransports')
  external JSArray<JSString> getTransportsJS();
}

extension type AssertionResponseJS._(JSObject _) implements JSObject {
  external JSArrayBuffer get clientDataJSON;
  external JSArrayBuffer get authenticatorData;
  external JSArrayBuffer get signature;
  external JSArrayBuffer? get userHandle;
}

extension type AbortController._(JSObject _) implements JSObject {
  external factory AbortController();
  external AbortSignal get signal;
  external void abort([JSAny? reason]);
}

extension type AbortSignal._(JSObject _) implements JSObject {}

@JS('JSON.parse')
external JSObject jsonParse(JSString text);

@JS('JSON.stringify')
external JSString jsonStringify(JSAny? value);
