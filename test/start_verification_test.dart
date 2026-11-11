import 'package:agewallet_flutter_sdk/agewallet_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';

import 'helpers.dart';

/// Stands in for the browser sign-off: records each authenticate() call and returns [reply] for its URL.
class FakeWebAuth extends FlutterWebAuth2Platform {
  FakeWebAuth(this.reply);

  final String Function(Uri url) reply;
  final List<({Uri url, String callbackUrlScheme})> calls = [];

  @override
  Future<String> authenticate({required String url, required String callbackUrlScheme, required Map<String, dynamic> options}) async {
    calls.add((url: Uri.parse(url), callbackUrlScheme: callbackUrlScheme));
    return reply(Uri.parse(url));
  }

  @override
  Future clearAllDanglingCalls() async {}
}

// The public AgeWallet class and startVerification(), with the sign-off faked through FlutterWebAuth2Platform.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(useMemoryStorage);

  test('startVerification opens the authorize URL and handles the callback it returns', () async {
    final webAuth = FakeWebAuth((url) => '$redirectUri?code=c1&state=${Uri.encodeQueryComponent(url.queryParameters['state']!)}');
    FlutterWebAuth2Platform.instance = webAuth;
    final ageWallet = AgeWallet(clientId: 'cid', redirectUri: redirectUri, metadata: 'tenant-1');
    final server = FakeServer();

    final result = await server.run(() => ageWallet.startVerification(metadata: 'order:42'));

    expect(result, AgeWalletResult.success);
    expect(webAuth.calls, hasLength(1));
    expect(webAuth.calls.single.callbackUrlScheme, 'https');
    expect('${webAuth.calls.single.url.origin}${webAuth.calls.single.url.path}', 'https://app.agewallet.io/user/authorize');
    expect(webAuth.calls.single.url.queryParameters['metadata'], 'order:42');
    expect(await ageWallet.isVerified(), isTrue);
    expect(await ageWallet.getMetadata(), 'm1');
  });

  test('the public class passes calls through to the core', () async {
    final ageWallet = AgeWallet(clientId: 'cid', redirectUri: redirectUri, metadata: 'tenant-1');

    expect((await ageWallet.buildVerificationURL()).queryParameters['metadata'], 'tenant-1');
    ageWallet.setMetadata('tenant-2');
    expect((await ageWallet.buildVerificationURL()).queryParameters['metadata'], 'tenant-2');

    final state = (await storedJson(oidcKey))!['state'];
    final server = FakeServer();
    expect(await server.run(() => ageWallet.handleCallback('$redirectUri?code=c1&state=$state')), AgeWalletResult.success);
    await ageWallet.clearVerification();
    expect(await ageWallet.isVerified(), isFalse);
  });
}
