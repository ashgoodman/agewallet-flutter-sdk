import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Security utilities for PKCE and state generation.
class Security {
  static final Random _random = Random.secure();

  /// Generate a cryptographically secure PKCE verifier.
  /// Returns a base64-URL encoded string of 64 random bytes.
  static String generateVerifier() {
    final bytes = Uint8List(64);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return _base64UrlEncode(bytes);
  }

  /// Generate a PKCE challenge from a verifier using S256 method.
  /// Returns SHA256(verifier) as base64-URL encoded string.
  static String generateChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return _base64UrlEncode(Uint8List.fromList(digest.bytes));
  }

  /// Generate a random state parameter for CSRF protection.
  /// Returns a 32-character hex string.
  static String generateState() {
    return _generateRandomHex(16);
  }

  /// Generate a random nonce for replay protection.
  /// Returns a 32-character hex string.
  static String generateNonce() {
    return _generateRandomHex(16);
  }

  /// Generate a random hex string of specified byte length.
  static String _generateRandomHex(int byteLength) {
    final bytes = Uint8List(byteLength);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Base64-URL encode bytes without padding.
  static String _base64UrlEncode(Uint8List bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
