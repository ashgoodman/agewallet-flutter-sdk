import 'dart:convert';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'types.dart';
import 'security.dart';
import 'storage.dart';

/// Core OIDC/PKCE implementation for AgeWallet age verification.
class AgeWalletCore {
  final AgeWalletConfig config;
  final Storage storage;

  AgeWalletCore({
    required this.config,
    Storage? storage,
  }) : storage = storage ?? Storage() {
    if (config.clientId.isEmpty) {
      throw ArgumentError('[AgeWallet] Missing clientId');
    }
    if (config.redirectUri.isEmpty) {
      throw ArgumentError('[AgeWallet] Missing redirectUri');
    }
  }

  /// Check if the user is currently verified (and not expired).
  Future<bool> isVerified() async {
    final state = await storage.getVerification();
    return state?.isVerified ?? false;
  }

  /// Start the verification flow.
  /// Opens the system browser to AgeWallet authorization page.
  Future<void> startVerification() async {
    // Generate PKCE parameters
    final verifier = Security.generateVerifier();
    final challenge = Security.generateChallenge(verifier);
    final state = Security.generateState();
    final nonce = Security.generateNonce();

    // Store OIDC state for callback validation
    await storage.setOidcState(OidcState(
      state: state,
      verifier: verifier,
      nonce: nonce,
    ));

    // Build authorization URL
    final authUrl = Uri.parse(config.authEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'scope': 'openid age',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'nonce': nonce,
      },
    );

    try {
      // Open browser and wait for callback
      final callbackUrlStr = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: Uri.parse(config.redirectUri).scheme,
      );

      // Handle the callback
      await handleCallback(callbackUrlStr);
    } catch (e) {
      // User cancelled or error occurred
      await storage.clearOidcState();
      rethrow;
    }
  }

  /// Handle callback URL from authorization.
  /// Returns true if verification succeeded, false otherwise.
  Future<bool> handleCallback(String url) async {
    final uri = Uri.parse(url);
    final params = uri.queryParameters;

    final code = params['code'];
    final state = params['state'];
    final error = params['error'];
    final errorDescription = params['error_description'];

    // Handle error response
    if (error != null) {
      return _handleError(error, errorDescription, state);
    }

    // Validate required parameters
    if (code == null || state == null) {
      print('[AgeWallet] Missing code or state in callback');
      await storage.clearOidcState();
      return false;
    }

    // Validate state matches stored state
    final storedOidc = await storage.getOidcState();
    if (storedOidc == null || storedOidc.state != state) {
      print('[AgeWallet] Invalid state or session expired');
      await storage.clearOidcState();
      return false;
    }

    try {
      // Exchange code for tokens
      final tokenResponse = await _exchangeCode(code, storedOidc.verifier);
      if (tokenResponse == null) {
        await storage.clearOidcState();
        return false;
      }

      // Fetch user info to verify age claim
      final userInfo = await _fetchUserInfo(tokenResponse['access_token']);
      if (userInfo == null) {
        await storage.clearOidcState();
        return false;
      }

      // Check age_verified claim
      final ageVerified = userInfo['age_verified'] as bool? ?? false;
      if (!ageVerified) {
        print('[AgeWallet] Age verification failed');
        await storage.clearOidcState();
        return false;
      }

      // Calculate expiry (use expires_in from token or default to 1 hour)
      final expiresIn = tokenResponse['expires_in'] as int? ?? 3600;
      final expiresAt =
          DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

      // Store verification state
      await storage.setVerification(VerificationState(
        accessToken: tokenResponse['access_token'],
        expiresAt: expiresAt,
        isVerified: true,
      ));

      await storage.clearOidcState();
      return true;
    } catch (e) {
      print('[AgeWallet] Error during token exchange: $e');
      await storage.clearOidcState();
      return false;
    }
  }

  /// Handle OIDC error response.
  Future<bool> _handleError(
      String error, String? description, String? state) async {
    // Validate state even for errors
    final storedOidc = await storage.getOidcState();
    if (storedOidc == null || storedOidc.state != state) {
      print('[AgeWallet] Error received with invalid state');
      await storage.clearOidcState();
      return false;
    }

    // Check for regional exemption
    if (error == 'access_denied' &&
        description == 'Region does not require verification') {
      print('[AgeWallet] Region exempt - granting 24h verification');

      // Grant synthetic 24-hour verification
      final expiresAt =
          DateTime.now().millisecondsSinceEpoch + (24 * 60 * 60 * 1000);

      await storage.setVerification(VerificationState(
        accessToken: 'region_exempt',
        expiresAt: expiresAt,
        isVerified: true,
      ));

      await storage.clearOidcState();
      return true;
    }

    print('[AgeWallet] Authorization error: $error - $description');
    await storage.clearOidcState();
    return false;
  }

  /// Exchange authorization code for tokens.
  Future<Map<String, dynamic>?> _exchangeCode(
      String code, String verifier) async {
    try {
      final response = await http.post(
        Uri.parse(config.tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'client_id': config.clientId,
          'redirect_uri': config.redirectUri,
          'code': code,
          'code_verifier': verifier,
        },
      );

      if (response.statusCode != 200) {
        print('[AgeWallet] Token exchange failed: ${response.statusCode}');
        return null;
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('[AgeWallet] Token exchange error: $e');
      return null;
    }
  }

  /// Fetch user info from the userinfo endpoint.
  Future<Map<String, dynamic>?> _fetchUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(config.userinfoEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode != 200) {
        print('[AgeWallet] UserInfo fetch failed: ${response.statusCode}');
        return null;
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('[AgeWallet] UserInfo fetch error: $e');
      return null;
    }
  }

  /// Clear all verification state (logout).
  Future<void> clearVerification() async {
    await storage.clearVerification();
    await storage.clearOidcState();
  }
}
