import 'package:agewallet_flutter_sdk/src/security.dart';
import 'package:flutter_test/flutter_test.dart';

// PKCE verifier and challenge, state and nonce (lib/src/security.dart).
void main() {
  test('the challenge matches the RFC 7636 Appendix B example', () {
    expect(
      Security.generateChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('a verifier is 86 Base64-URL characters with no padding', () {
    expect(Security.generateVerifier(), matches(RegExp(r'^[A-Za-z0-9_-]{86}$')));
  });

  test('verifiers differ', () {
    expect(Security.generateVerifier(), isNot(Security.generateVerifier()));
  });

  test('state and nonce are 32 lowercase hex characters', () {
    expect(Security.generateState(), matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(Security.generateNonce(), matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('states and nonces differ', () {
    expect(Security.generateState(), isNot(Security.generateState()));
    expect(Security.generateNonce(), isNot(Security.generateNonce()));
  });
}
