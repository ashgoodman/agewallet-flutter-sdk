import 'package:agewallet_flutter_sdk/src/agewallet_core.dart';
import 'package:agewallet_flutter_sdk/src/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// AgeWalletConfig endpoints and the checks in the AgeWalletCore constructor.
void main() {
  setUp(useMemoryStorage);

  test('an empty client ID or redirect URI is rejected', () {
    expect(() => AgeWalletCore(config: const AgeWalletConfig(clientId: '', redirectUri: redirectUri)), throwsArgumentError);
    expect(() => AgeWalletCore(config: const AgeWalletConfig(clientId: 'cid', redirectUri: '')), throwsArgumentError);
  });

  test('the default endpoints are on app.agewallet.io', () {
    const config = AgeWalletConfig(clientId: 'cid', redirectUri: redirectUri);
    expect(config.authEndpoint, 'https://app.agewallet.io/user/authorize');
    expect(config.tokenEndpoint, 'https://app.agewallet.io/user/token');
    expect(config.userinfoEndpoint, 'https://app.agewallet.io/user/userinfo');
  });

  test('each custom endpoint replaces only its own default', () {
    const config = AgeWalletConfig(
      clientId: 'cid',
      redirectUri: redirectUri,
      endpoints: AgeWalletEndpoints(token: 'https://aw.test/token'),
    );
    expect(config.authEndpoint, 'https://app.agewallet.io/user/authorize');
    expect(config.tokenEndpoint, 'https://aw.test/token');
    expect(config.userinfoEndpoint, 'https://app.agewallet.io/user/userinfo');
  });

  test('metadata over 4096 characters in the config is rejected', () {
    expect(() => makeCore(metadata: 'a' * 4097), throwsArgumentError);
    expect(() => makeCore(metadata: 'a' * 4096), returnsNormally);
  });
}
