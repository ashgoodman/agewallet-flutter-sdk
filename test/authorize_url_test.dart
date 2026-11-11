import 'package:agewallet_flutter_sdk/src/security.dart';
import 'package:agewallet_flutter_sdk/src/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// AgeWalletCore.buildVerificationURL(), the OIDC state it saves, and metadata.
void main() {
  setUp(useMemoryStorage);

  test('the URL carries the OIDC parameters', () async {
    final url = await makeCore().buildVerificationURL();
    final params = url.queryParameters;

    expect('${url.origin}${url.path}', 'https://app.agewallet.io/user/authorize');
    expect(params.keys, unorderedEquals(['response_type', 'client_id', 'redirect_uri', 'scope', 'state', 'code_challenge', 'code_challenge_method', 'nonce']));
    expect(params['response_type'], 'code');
    expect(params['client_id'], 'cid');
    expect(params['redirect_uri'], redirectUri);
    expect(params['scope'], 'openid age');
    expect(params['code_challenge_method'], 'S256');
  });

  test('the saved state, verifier and nonce match the URL', () async {
    final params = (await makeCore().buildVerificationURL()).queryParameters;
    final saved = (await storedJson(oidcKey))!;

    expect(params['state'], matches(RegExp(r'^flutter:[0-9a-f]{32}$')));
    expect(saved['state'], params['state']);
    expect(saved['nonce'], params['nonce']);
    expect(params['nonce'], matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(params['code_challenge'], Security.generateChallenge(saved['verifier'] as String));
  });

  test('a custom auth endpoint is used', () async {
    final core = makeCore(endpoints: const AgeWalletEndpoints(auth: 'https://dev3.agewallet.io/user/authorize'));
    final url = await core.buildVerificationURL();
    expect('${url.origin}${url.path}', 'https://dev3.agewallet.io/user/authorize');
  });

  test('each URL has its own state, nonce and challenge', () async {
    final core = makeCore();
    final first = (await core.buildVerificationURL()).queryParameters;
    final second = (await core.buildVerificationURL()).queryParameters;
    for (final name in ['state', 'nonce', 'code_challenge']) {
      expect(second[name], isNot(first[name]), reason: name);
    }
  });

  test('a newer URL replaces the saved state, so the older URL\'s callback fails without a request', () async {
    final core = makeCore();
    final olderState = await startFlow(core);
    await startFlow(core);
    final server = FakeServer();

    final result = await server.run(() => core.handleCallback('$redirectUri?code=c1&state=$olderState'));

    expect(result, AgeWalletResult.failed);
    expect(server.requests, isEmpty);
  });

  group('metadata', () {
    test('is left out when none is set', () async {
      expect((await makeCore().buildVerificationURL()).queryParameters.containsKey('metadata'), isFalse);
    });

    test('the config default is sent', () async {
      expect((await makeCore(metadata: 'tenant-1').buildVerificationURL()).queryParameters['metadata'], 'tenant-1');
    });

    test('a per-call value wins without changing the default', () async {
      final core = makeCore(metadata: 'tenant-1');
      expect((await core.buildVerificationURL(metadata: 'order:42 & co')).queryParameters['metadata'], 'order:42 & co');
      expect((await core.buildVerificationURL()).queryParameters['metadata'], 'tenant-1');
    });

    test('a per-call empty value sends no metadata', () async {
      final core = makeCore(metadata: 'tenant-1');
      expect((await core.buildVerificationURL(metadata: '')).queryParameters.containsKey('metadata'), isFalse);
    });

    test('setMetadata changes the default, and null clears it', () async {
      final core = makeCore(metadata: 'tenant-1');
      core.setMetadata('tenant-2');
      expect((await core.buildVerificationURL()).queryParameters['metadata'], 'tenant-2');
      core.setMetadata(null);
      expect((await core.buildVerificationURL()).queryParameters.containsKey('metadata'), isFalse);
    });

    test('over 4096 characters is rejected by setMetadata and per call, and the default stays', () async {
      final core = makeCore(metadata: 'tenant-1');
      expect(() => core.setMetadata('a' * 4097), throwsArgumentError);
      await expectLater(core.buildVerificationURL(metadata: 'a' * 4097), throwsArgumentError);
      expect((await core.buildVerificationURL()).queryParameters['metadata'], 'tenant-1');
    });

    test('4096 characters is accepted', () async {
      final atLimit = 'a' * 4096;
      expect((await makeCore().buildVerificationURL(metadata: atLimit)).queryParameters['metadata'], atLimit);
    });
  });
}
