import 'dart:convert';
import 'dart:typed_data';

/// Encodes [bytes] as unpadded base64url, the encoding WebAuthn JSON uses
/// for binary fields.
String base64UrlNoPadding(Uint8List bytes) {
  final encoded = base64UrlEncode(bytes);
  final padding = encoded.indexOf('=');
  return padding == -1 ? encoded : encoded.substring(0, padding);
}

/// Decodes the (padded or unpadded) base64url [input] into bytes.
Uint8List base64UrlDecode(String input) {
  return base64Url.decode(base64Url.normalize(input));
}
