import 'package:agewallet_flutter_sdk/src/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

// AgeWalletCore.handleCallback(): the callback checks, the token exchange, userinfo and the saved verification.
// Every request goes to FakeServer.
void main() {
  setUp(useMemoryStorage);

  group('rejected before any request', () {
    test('a denied request returns denied and clears the saved state', () async {
      final core = makeCore();
      await startFlow(core);
      final server = FakeServer();

      final result = await server.run(() => core.handleCallback(
          '$redirectUri?error=access_denied&error_description=The%20user%20denied%20the%20request'));

      expect(result, AgeWalletResult.denied);
      expect(await stored(oidcKey), isNull);
      expect(server.requests, isEmpty);
    });

    test('any other error returns failed and clears the saved state', () async {
      final core = makeCore();
      await startFlow(core);
      final server = FakeServer();

      final result = await server.run(() => core.handleCallback('$redirectUri?error=server_error&error_description=Oops'));

      expect(result, AgeWalletResult.failed);
      expect(await stored(oidcKey), isNull);
      expect(server.requests, isEmpty);
    });

    test('a missing code or state returns failed', () async {
      final core = makeCore();
      final state = await startFlow(core);
      final server = FakeServer();

      expect(await server.run(() => core.handleCallback('$redirectUri?state=$state')), AgeWalletResult.failed);
      expect(await server.run(() => core.handleCallback('$redirectUri?code=c1')), AgeWalletResult.failed);
      expect(server.requests, isEmpty);
    });

    test('a state that does not match returns failed and clears the saved state', () async {
      final core = makeCore();
      await startFlow(core);
      final server = FakeServer();

      final result = await server.run(() => core.handleCallback('$redirectUri?code=c1&state=flutter:other'));

      expect(result, AgeWalletResult.failed);
      expect(await stored(oidcKey), isNull);
      expect(server.requests, isEmpty);
    });

    test('no saved state returns failed', () async {
      final server = FakeServer();

      final result = await server.run(() => makeCore().handleCallback('$redirectUri?code=c1&state=flutter:abc'));

      expect(result, AgeWalletResult.failed);
      expect(server.requests, isEmpty);
    });
  });

  group('a valid callback', () {
    test('exchanges the code with the saved verifier, calls userinfo and saves the verification', () async {
      final core = makeCore();
      final state = await startFlow(core);
      final verifier = (await storedJson(oidcKey))!['verifier'];
      final server = FakeServer();
      final before = DateTime.now().millisecondsSinceEpoch;

      final result = await server.run(() => core.handleCallback('$redirectUri?code=c1&state=$state'));
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(result, AgeWalletResult.success);
      expect(server.requests.map((r) => '${r.method} ${r.url}'), [
        'POST https://app.agewallet.io/user/token',
        'GET https://app.agewallet.io/user/userinfo',
      ]);
      final tokenRequest = server.requests[0];
      expect(tokenRequest.headers['content-type'], startsWith('application/x-www-form-urlencoded'));
      expect(tokenRequest.bodyFields, {
        'grant_type': 'authorization_code',
        'client_id': 'cid',
        'redirect_uri': redirectUri,
        'code': 'c1',
        'code_verifier': verifier,
      });
      expect(server.requests[1].headers['authorization'], 'Bearer tok');

      expect(await core.isVerified(), isTrue);
      expect(await core.getMetadata(), 'm1');
      final saved = (await storedJson(verificationKey))!;
      expect(saved['accessToken'], 'tok');
      expect(saved['isVerified'], isTrue);
      expect(saved['expiresAt'], inInclusiveRange(before + 3600 * 1000, after + 3600 * 1000));
      expect(await stored(oidcKey), isNull);
    });

    test('expires after the token\'s expires_in', () async {
      final core = makeCore();
      final state = await startFlow(core);
      final server = FakeServer(token: (_) => FakeServer.json({'access_token': 'tok', 'expires_in': 120}));
      final before = DateTime.now().millisecondsSinceEpoch;

      await server.run(() => core.handleCallback('$redirectUri?code=c1&state=$state'));

      expect((await storedJson(verificationKey))!['expiresAt'], inInclusiveRange(before + 120000, DateTime.now().millisecondsSinceEpoch + 120000));
    });

    test('expires after an hour when the token has no expires_in', () async {
      final core = makeCore();
      final state = await startFlow(core);
      final server = FakeServer(token: (_) => FakeServer.json({'access_token': 'tok'}));
      final before = DateTime.now().millisecondsSinceEpoch;

      await server.run(() => core.handleCallback('$redirectUri?code=c1&state=$state'));

      expect((await storedJson(verificationKey))!['expiresAt'], inInclusiveRange(before + 3600000, DateTime.now().millisecondsSinceEpoch + 3600000));
    });

    test('with no metadata in userinfo saves none', () async {
      final core = makeCore();
      final state = await startFlow(core);
      final server = FakeServer(userinfo: (_) => FakeServer.json({'age_verified': true}));

      await server.run(() => core.handleCallback('$redirectUri?code=c1&state=$state'));

      expect(await core.isVerified(), isTrue);
      expect(await core.getMetadata(), isNull);
      expect((await storedJson(verificationKey))!.containsKey('metadata'), isFalse);
    });

    test('uses custom token and userinfo endpoints', () async {
      final core = makeCore(endpoints: const AgeWalletEndpoints(token: 'https://aw.test/x/token', userinfo: 'https://aw.test/x/userinfo'));
      final state = await startFlow(core);
      final server = FakeServer();

      await server.run(() => core.handleCallback('$redirectUri?code=c1&state=$state'));

      expect(server.requests.map((r) => r.url.toString()), ['https://aw.test/x/token', 'https://aw.test/x/userinfo']);
    });

    test('cannot be used twice', () async {
      final core = makeCore();
      final state = await startFlow(core);
      final server = FakeServer();
      final callback = '$redirectUri?code=c1&state=$state';

      expect(await server.run(() => core.handleCallback(callback)), AgeWalletResult.success);
      expect(await server.run(() => core.handleCallback(callback)), AgeWalletResult.failed);
      expect(server.requests.length, 2);
    });
  });

  group('fails and saves nothing', () {
    Future<void> expectFailure(FakeServer server, {required int requests}) async {
      final core = makeCore();
      final state = await startFlow(core);

      final result = await server.run(() => core.handleCallback('$redirectUri?code=c1&state=$state'));

      expect(result, AgeWalletResult.failed);
      expect(server.requests.length, requests);
      expect(await core.isVerified(), isFalse);
      expect(await stored(verificationKey), isNull);
      expect(await stored(oidcKey), isNull);
    }

    test('when the token request is refused', () async {
      await expectFailure(FakeServer(token: (_) => FakeServer.json({'error': 'invalid_grant'}, status: 400)), requests: 1);
    });

    test('when the token reply is not JSON', () async {
      await expectFailure(FakeServer(token: (_) => http.Response('<html>error</html>', 200)), requests: 1);
    });

    test('when userinfo is refused', () async {
      await expectFailure(FakeServer(userinfo: (_) => FakeServer.json({'error': 'invalid_token'}, status: 401)), requests: 2);
    });

    for (final entry in {
      'false': false,
      'the string "true"': 'true',
      'missing': null,
    }.entries) {
      test('when age_verified is ${entry.key}', () async {
        final body = entry.value == null ? <String, Object>{} : {'age_verified': entry.value!};
        await expectFailure(FakeServer(userinfo: (_) => FakeServer.json(body)), requests: 2);
      });
    }
  });
}
