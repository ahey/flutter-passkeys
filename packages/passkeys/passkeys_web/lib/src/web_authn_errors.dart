import 'package:flutter/services.dart';

/// Abort reason used when the current WebAuthn operation is cancelled by Dart.
const abortedByUser = 'operation aborted by user.';

/// Normalized information from a JavaScript WebAuthn error.
class WebAuthnErrorDetails {
  /// Creates normalized WebAuthn error details.
  const WebAuthnErrorDetails({
    required this.fallbackText,
    this.name,
    this.message = '',
  });

  /// JavaScript `Error.name`, when available.
  final String? name;

  /// JavaScript `Error.message`, when available.
  final String message;

  /// Text to use when no structured error fields are available.
  final String fallbackText;
}

/// Maps normalized WebAuthn error details to the platform error contract.
PlatformException mapWebAuthnError(WebAuthnErrorDetails error) {
  final name = error.name;
  if (name != null) {
    if (name == 'NotAllowedError') {
      return PlatformException(
        code: 'cancelled',
        message: 'operation was cancelled by the user.',
        details: '',
      );
    }

    return PlatformException(
      code: name,
      message: error.message,
      details: '',
    );
  }

  if (error.fallbackText == abortedByUser) {
    return PlatformException(
      code: 'suppressed',
      message: error.fallbackText,
      details: '',
    );
  }

  return PlatformException(
    code: 'unknown',
    message: error.fallbackText,
    details: '',
  );
}
