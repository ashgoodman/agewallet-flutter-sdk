import 'dart:convert';

import 'package:agewallet_flutter_sdk/src/agewallet_core.dart';
import 'package:agewallet_flutter_sdk/src/types.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Storage keys the SDK writes (lib/src/storage.dart).
const verificationKey = 'io.agewallet.sdk.verification';
const oidcKey = 'io.agewallet.sdk.oidc';

const redirectUri = 'https://shop.example/callback';

/// Replaces flutter_secure_storage with an in-memory store holding [values], for every Storage the SDK makes.
void useMemoryStorage([Map<String, String> values = const {}]) {
  FlutterSecureStorage.setMockInitialValues(Map.of(values));
}

/// The raw string stored under [key], or null.
Future<String?> stored(String key) => const FlutterSecureStorage().read(key: key);

/// The JSON object stored under [key], or null.
Future<Map<String, dynamic>?> storedJson(String key) async {
  final raw = await stored(key);
  return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
}

/// An AgeWalletCore with client ID "cid" and [redirectUri].
AgeWalletCore makeCore({String? metadata, AgeWalletEndpoints? endpoints}) {
  return AgeWalletCore(
    config: AgeWalletConfig(
      clientId: 'cid',
      redirectUri: redirectUri,
      endpoints: endpoints,
      metadata: metadata,
    ),
  );
}

/// The authorize URL's state after building one, which the SDK has saved as the expected callback state.
Future<String> startFlow(AgeWalletCore core) async {
  final url = await core.buildVerificationURL();
  return url.queryParameters['state']!;
}

/// A fake AgeWallet server for code run through [run]: records every request the SDK sends with package:http,
/// answers paths ending in /token with [token] and paths ending in /userinfo with [userinfo], and anything else 404.
class FakeServer {
  FakeServer({http.Response Function(http.Request)? token, http.Response Function(http.Request)? userinfo})
      : token = token ?? ((_) => json({'access_token': 'tok', 'expires_in': 3600})),
        userinfo = userinfo ?? ((_) => json({'age_verified': true, 'metadata': 'm1'}));

  final http.Response Function(http.Request) token;
  final http.Response Function(http.Request) userinfo;
  final List<http.Request> requests = [];

  /// A 200 (or [status]) JSON reply.
  static http.Response json(Object body, {int status = 200}) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<T> run<T>(Future<T> Function() body) {
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/token')) return token(request);
      if (request.url.path.endsWith('/userinfo')) return userinfo(request);
      return http.Response('not found', 404);
    });
    return http.runWithClient(body, () => client);
  }
}
