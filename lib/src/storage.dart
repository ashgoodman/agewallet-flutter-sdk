import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'types.dart';

/// Secure storage for verification and OIDC state.
class Storage {
  static const _verificationKey = 'io.agewallet.sdk.verification';
  static const _oidcKey = 'io.agewallet.sdk.oidc';

  final FlutterSecureStorage _storage;

  Storage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Get stored verification state.
  Future<VerificationState?> getVerification() async {
    final json = await _storage.read(key: _verificationKey);
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final state = VerificationState.fromJson(data);

      // Auto-clear if expired
      if (state.isExpired) {
        await clearVerification();
        return null;
      }

      return state;
    } catch (e) {
      await clearVerification();
      return null;
    }
  }

  /// Store verification state.
  Future<void> setVerification(VerificationState state) async {
    final json = jsonEncode(state.toJson());
    await _storage.write(key: _verificationKey, value: json);
  }

  /// Clear verification state.
  Future<void> clearVerification() async {
    await _storage.delete(key: _verificationKey);
  }

  /// Get stored OIDC state (during auth flow).
  Future<OidcState?> getOidcState() async {
    final json = await _storage.read(key: _oidcKey);
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return OidcState.fromJson(data);
    } catch (e) {
      await clearOidcState();
      return null;
    }
  }

  /// Store OIDC state (during auth flow).
  Future<void> setOidcState(OidcState state) async {
    final json = jsonEncode(state.toJson());
    await _storage.write(key: _oidcKey, value: json);
  }

  /// Clear OIDC state.
  Future<void> clearOidcState() async {
    await _storage.delete(key: _oidcKey);
  }
}
