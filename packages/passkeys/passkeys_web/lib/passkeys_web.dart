import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';
import 'package:passkeys_platform_interface/types/types.dart';
import 'package:passkeys_web/models/passkey_login_request.dart';
import 'package:passkeys_web/models/passkey_login_response.dart';
import 'package:passkeys_web/models/passkey_sign_up_request.dart';
import 'package:passkeys_web/models/passkey_sign_up_response.dart';
import 'package:passkeys_web/src/availability_probe.dart';
import 'package:passkeys_web/src/base64url.dart';
import 'package:passkeys_web/src/interop.dart' as interop;
import 'package:passkeys_web/src/prf.dart';
import 'package:passkeys_web/src/web_authn_errors.dart';

/// The Web implementation of [PasskeysPlatform].
class PasskeysWeb extends PasskeysPlatform {
  interop.AbortController? _abortController;

  /// Whether the browser supports WebAuthn (`PublicKeyCredential` exists).
  /// Evaluated once; the browser cannot change mid-run.
  static final bool _hasSupport = _hasWebAuthnSupport();

  /// Registers this class as the default instance of [PasskeysPlatform].
  static void registerWith([Object? registrar]) {
    PasskeysPlatform.instance = PasskeysWeb();
  }

  /// Throws the error the `passkeys` package maps to
  /// `DeviceNotSupportedException` when the browser lacks WebAuthn support.
  /// [getAvailability] reports the same condition non-exceptionally via
  /// `hasPasskeySupport`.
  void _ensureSupported() {
    if (!_hasSupport) {
      throw PlatformException(
        code: 'deviceNotSupported',
        message: 'This browser does not support WebAuthn.',
        details: '',
      );
    }
  }

  @override
  Future<RegisterResponseType> register(RegisterRequestType request) async {
    _ensureSupported();

    final r = PasskeySignUpRequest(
      PublicKey(
        request.relyingParty,
        request.user,
        request.challenge,
        request.pubKeyCredParams!,
        request.authSelectionType,
        request.excludeCredentials,
        request.timeout,
        request.attestation,
      ),
    );

    _abortController = interop.AbortController();
    try {
      final requestJson = r.toJson();
      applyPrf(requestJson, request.prf);
      final credential = await _credentialOperation(
        interop.navigator.credentials.create(
          interop.CredentialCreationOptions(
            publicKey: _jsCreationOptions(
              requestJson['publicKey'] as Map<String, dynamic>,
            ),
            signal: _abortController!.signal,
          ),
        ),
      );

      if (credential == null) {
        throw PlatformException(
          code: 'unknown',
          message: 'navigator.credentials.create returned null',
          details: '',
        );
      }

      final decodedResponse = _registrationResponseJson(
        credential as interop.PublicKeyCredentialInstance,
      );
      final typedResponse = PasskeySignUpResponse.fromJson(decodedResponse);

      return RegisterResponseType(
        id: typedResponse.id,
        rawId: typedResponse.rawId,
        clientDataJSON: typedResponse.response.clientDataJSON,
        attestationObject: typedResponse.response.attestationObject,
        transports: typedResponse.response.transports,
        clientExtensionResults:
            decodedResponse['clientExtensionResults'] as Map<String, dynamic>?,
      );
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<AuthenticateResponseType> authenticate(
    AuthenticateRequestType request,
  ) async {
    _ensureSupported();

    final r = PasskeyLoginRequest.fromPlatformType(
      request.relyingPartyId,
      request.challenge,
      request.timeout,
      request.userVerification,
      request.allowCredentials,
      request.mediation,
    );

    _abortController = interop.AbortController();
    try {
      final requestJson = r.toJson();
      applyPrf(requestJson, request.prf);
      final credential = await _credentialOperation(
        interop.navigator.credentials.getCredential(
          interop.CredentialRequestOptions(
            publicKey: _jsRequestOptions(
              requestJson['publicKey'] as Map<String, dynamic>,
            ),
            mediation: _mediationName(r.mediation),
            signal: _abortController!.signal,
          ),
        ),
      );

      if (credential == null) {
        throw PlatformException(
          code: 'unknown',
          message: 'navigator.credentials.get returned null',
          details: '',
        );
      }

      final decodedResponse = _authenticationResponseJson(
        credential as interop.PublicKeyCredentialInstance,
      );
      final typedResponse = PasskeyLoginResponse.fromJson(decodedResponse);

      return typedResponse.toAuthenticateResponseType(
        clientExtensionResults:
            decodedResponse['clientExtensionResults'] as Map<String, dynamic>?,
      );
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signalUnknownCredential(
    SignalUnknownCredentialRequestType request,
  ) async {
    if (!_supportsSignal('signalUnknownCredential')) {
      // This browser does not support the Signal API; the hint is best-effort
      // so treat it as a no-op.
      return;
    }

    final options = JSObject()
      ..setProperty('rpId'.toJS, request.relyingPartyId.toJS)
      ..setProperty('credentialId'.toJS, request.credentialId.toJS);

    try {
      await _signalOperation(interop.signalUnknownCredential(options));
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signalAllAcceptedCredentials(
    SignalAllAcceptedCredentialsRequestType request,
  ) async {
    if (!_supportsSignal('signalAllAcceptedCredentials')) {
      // This browser does not support the Signal API; the hint is best-effort
      // so treat it as a no-op.
      return;
    }

    final credentialIds = request.allAcceptedCredentialIds
        .map((e) => e.toJS)
        .toList()
        .toJS;
    final options = JSObject()
      ..setProperty('rpId'.toJS, request.relyingPartyId.toJS)
      ..setProperty('userId'.toJS, request.userId.toJS)
      ..setProperty('allAcceptedCredentialIds'.toJS, credentialIds);

    try {
      await _signalOperation(interop.signalAllAcceptedCredentials(options));
    } catch (e) {
      throw _mapError(e);
    }
  }

  bool _supportsSignal(String method) {
    final ctor = interop.publicKeyCredentialCtor;
    if (ctor == null || !ctor.typeofEquals('function')) return false;
    return _hasFunction(ctor as JSObject, method);
  }

  @override
  Future<void> cancelCurrentAuthenticatorOperation() async {
    _abortController?.abort(abortedByUser.toJS);
  }

  @override
  Future<AvailabilityTypeWeb> getAvailability() async {
    final hasPasskeySupport = _hasSupport;

    bool? uvpaa;
    bool? cma;
    if (hasPasskeySupport) {
      uvpaa = await optionalAvailabilityProbe(
        () async =>
            (await interop
                    .isUserVerifyingPlatformAuthenticatorAvailable()
                    .toDart)
                .toDart,
      );
      cma = await optionalAvailabilityProbe(
        () async =>
            (await interop.isConditionalMediationAvailable().toDart).toDart,
      );
    }

    return AvailabilityTypeWeb(
      hasPasskeySupport: hasPasskeySupport,
      isUserVerifyingPlatformAuthenticatorAvailable: uvpaa,
      isConditionalMediationAvailable: cma,
      isNative: false,
    );
  }

  // Requests are converted from WebAuthn JSON to browser options here
  // rather than via `PublicKeyCredential.parseCreationOptionsFromJSON` /
  // `parseRequestOptionsFromJSON`, which only exist in Chrome/Edge 129+,
  // Safari 18.4+ and Firefox 119+. Converting the base64url fields in Dart
  // keeps every WebAuthn-capable browser supported, on a single code path.
  // `JSON.parse` provides the JSON-safe fields; the known binary fields are
  // then replaced with decoded buffers.

  JSObject _jsCreationOptions(Map<String, dynamic> publicKey) {
    final options = interop.jsonParse(jsonEncode(publicKey).toJS);
    _patchBuffer(options, 'challenge', publicKey['challenge'] as String?);

    final user = publicKey['user'] as Map<String, dynamic>?;
    if (user != null) {
      _patchBuffer(
        options.getProperty<JSObject>('user'.toJS),
        'id',
        user['id'] as String?,
      );
    }

    _patchCredentialIds(options, 'excludeCredentials', publicKey);
    _patchPrfInputs(options, publicKey);
    return options;
  }

  JSObject _jsRequestOptions(Map<String, dynamic> publicKey) {
    final options = interop.jsonParse(jsonEncode(publicKey).toJS);
    _patchBuffer(options, 'challenge', publicKey['challenge'] as String?);
    _patchCredentialIds(options, 'allowCredentials', publicKey);
    _patchPrfInputs(options, publicKey);
    return options;
  }

  void _patchBuffer(JSObject target, String name, String? value) {
    if (value == null) {
      return;
    }

    target.setProperty(name.toJS, base64UrlDecode(value).toJS);
  }

  void _patchCredentialIds(
    JSObject options,
    String key,
    Map<String, dynamic> publicKey,
  ) {
    final credentials = publicKey[key] as List<dynamic>?;
    if (credentials == null || credentials.isEmpty) {
      return;
    }

    final jsCredentials = options.getProperty<JSArray<JSObject>>(key.toJS);
    for (var i = 0; i < credentials.length; i++) {
      _patchBuffer(
        jsCredentials.toDart[i],
        'id',
        (credentials[i] as Map<String, dynamic>)['id'] as String?,
      );
    }
  }

  void _patchPrfInputs(JSObject options, Map<String, dynamic> publicKey) {
    final extensions = publicKey['extensions'] as Map<String, dynamic>?;
    final prf = extensions?['prf'] as Map<String, dynamic>?;
    final evalInputs = prf?['eval'] as Map<String, dynamic>?;
    if (evalInputs == null) {
      return;
    }

    final jsEval = options
        .getProperty<JSObject>('extensions'.toJS)
        .getProperty<JSObject>('prf'.toJS)
        .getProperty<JSObject>('eval'.toJS);
    _patchBuffer(jsEval, 'first', evalInputs['first'] as String?);
    _patchBuffer(jsEval, 'second', evalInputs['second'] as String?);
  }

  // The response is serialized to WebAuthn JSON here rather than via the
  // browser's `PublicKeyCredential.toJSON()`, which shipped with broken PRF
  // output serialization in all three engines (results dropped on
  // Chrome <152 and Firefox <139; renderer crash on Safari <26.3) and, like
  // the parse helpers above, does not exist in older browsers at all.

  Map<String, dynamic> _registrationResponseJson(
    interop.PublicKeyCredentialInstance credential,
  ) {
    final response = credential.attestationResponse;
    return <String, dynamic>{
      'id': credential.id,
      'rawId': credential.id,
      'type': 'public-key',
      'response': <String, dynamic>{
        'clientDataJSON': _bufferToBase64Url(response.clientDataJSON),
        'attestationObject': _bufferToBase64Url(response.attestationObject),
        'transports': _transports(response),
      },
      'clientExtensionResults': _clientExtensionResults(credential),
    };
  }

  Map<String, dynamic> _authenticationResponseJson(
    interop.PublicKeyCredentialInstance credential,
  ) {
    final response = credential.assertionResponse;
    final userHandle = response.userHandle;
    return <String, dynamic>{
      'id': credential.id,
      'rawId': credential.id,
      'type': 'public-key',
      'response': <String, dynamic>{
        'clientDataJSON': _bufferToBase64Url(response.clientDataJSON),
        'authenticatorData': _bufferToBase64Url(response.authenticatorData),
        'signature': _bufferToBase64Url(response.signature),
        'userHandle': userHandle == null
            ? null
            : _bufferToBase64Url(userHandle),
      },
      'clientExtensionResults': _clientExtensionResults(credential),
    };
  }

  List<String> _transports(interop.AttestationResponseJS response) {
    if (!_hasFunction(response, 'getTransports')) {
      return const [];
    }

    return response.getTransportsJS().toDart.map((e) => e.toDart).toList();
  }

  Map<String, dynamic> _clientExtensionResults(
    interop.PublicKeyCredentialInstance credential,
  ) {
    final outputs = credential.getClientExtensionResults();
    // JSON.stringify keeps the JSON-safe outputs (e.g. credProps) but
    // degrades ArrayBuffers to empty objects, so PRF outputs are extracted
    // manually and merged over the top.
    final json = _toDartJson(outputs);
    return mergePrfOutputs(json, _readPrfOutputs(outputs));
  }

  PrfClientOutputs? _readPrfOutputs(JSObject outputs) {
    final prf = outputs.getProperty<JSAny?>('prf'.toJS);
    if (prf == null || !prf.typeofEquals('object')) {
      return null;
    }
    final prfObject = prf as JSObject;

    bool? enabled;
    final enabledJs = prfObject.getProperty<JSAny?>('enabled'.toJS);
    if (enabledJs != null && enabledJs.typeofEquals('boolean')) {
      enabled = (enabledJs as JSBoolean).toDart;
    }

    String? first;
    String? second;
    final results = prfObject.getProperty<JSAny?>('results'.toJS);
    if (results != null && results.typeofEquals('object')) {
      final resultsObject = results as JSObject;
      first = _bufferProperty(resultsObject, 'first');
      second = _bufferProperty(resultsObject, 'second');
    }

    return PrfClientOutputs(enabled: enabled, first: first, second: second);
  }

  String? _bufferProperty(JSObject object, String name) {
    final value = object.getProperty<JSAny?>(name.toJS);
    if (value == null || !value.typeofEquals('object')) {
      return null;
    }

    return _bufferToBase64Url(value as JSArrayBuffer);
  }

  String _bufferToBase64Url(JSArrayBuffer buffer) {
    return base64UrlNoPadding(buffer.toDart.asUint8List());
  }

  Map<String, dynamic> _toDartJson(JSObject jsObject) {
    final stringified = interop.jsonStringify(jsObject).toDart;
    return jsonDecode(stringified) as Map<String, dynamic>;
  }

  String _mediationName(PasskeyLoginMediationType m) {
    switch (m) {
      case PasskeyLoginMediationType.Conditional:
        return 'conditional';
      case PasskeyLoginMediationType.Optional:
        return 'optional';
      case PasskeyLoginMediationType.Required:
        return 'required';
      case PasskeyLoginMediationType.Silent:
        return 'silent';
    }
  }

  PlatformException _mapError(Object e) {
    if (e is PlatformException) return e;

    return mapWebAuthnError(
      WebAuthnErrorDetails(fallbackText: e.toString()),
    );
  }
}

bool _hasWebAuthnSupport() {
  final ctor = interop.publicKeyCredentialCtor;
  return ctor != null && ctor.typeofEquals('function');
}

bool _hasFunction(JSObject object, String name) {
  return object.getProperty<JSAny?>(name.toJS).typeofEquals('function');
}

Future<JSObject?> _credentialOperation(JSPromise<JSObject?> promise) {
  final completer = Completer<JSObject?>();

  void completeCredential(JSObject? credential) {
    completer.complete(credential);
  }

  void completeWithError(JSAny? error) {
    completer.completeError(_mapJsError(error));
  }

  _PromiseWithHandlers(promise).then(
    completeCredential.toJS,
    completeWithError.toJS,
  );

  return completer.future;
}

Future<void> _signalOperation(JSPromise<JSAny?> promise) {
  final completer = Completer<void>();

  void completeSignal(JSAny? _) {
    completer.complete();
  }

  void completeWithError(JSAny? error) {
    completer.completeError(_mapJsError(error));
  }

  _PromiseWithAnyHandlers(promise).then(
    completeSignal.toJS,
    completeWithError.toJS,
  );

  return completer.future;
}

PlatformException _mapJsError(JSAny? error) {
  return mapWebAuthnError(
    WebAuthnErrorDetails(
      name: _jsStringProperty(error, 'name'),
      message: _jsStringProperty(error, 'message') ?? '',
      fallbackText: _jsStringValue(error) ?? error.toString(),
    ),
  );
}

String? _jsStringProperty(JSAny? value, String property) {
  if (value == null ||
      !(value.typeofEquals('object') || value.typeofEquals('function'))) {
    return null;
  }

  final propertyValue = (value as JSObject).getProperty<JSAny?>(property.toJS);
  return _jsStringValue(propertyValue);
}

String? _jsStringValue(JSAny? value) {
  if (value == null || !value.typeofEquals('string')) return null;

  return (value as JSString).toDart;
}

extension type _PromiseWithHandlers(JSPromise<JSObject?> _)
    implements JSPromise<JSObject?> {
  external JSPromise<JSAny?> then(
    JSFunction onFulfilled,
    JSFunction onRejected,
  );
}

extension type _PromiseWithAnyHandlers(JSPromise<JSAny?> _)
    implements JSPromise<JSAny?> {
  external JSPromise<JSAny?> then(
    JSFunction onFulfilled,
    JSFunction onRejected,
  );
}
