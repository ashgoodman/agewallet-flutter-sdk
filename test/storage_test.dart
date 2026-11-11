import 'package:agewallet_flutter_sdk/src/storage.dart';
import 'package:agewallet_flutter_sdk/src/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Storage (lib/src/storage.dart) over the in-memory flutter_secure_storage, and AgeWalletCore's use of it.
void main() {
  setUp(useMemoryStorage);

  int inAnHour() => DateTime.now().millisecondsSinceEpoch + 3600000;

  test('a verification is saved under io.agewallet.sdk.verification and read back', () async {
    await Storage().setVerification(VerificationState(accessToken: 'tok', expiresAt: inAnHour(), isVerified: true, metadata: 'm1'));

    final read = (await Storage().getVerification())!;
    expect(read.accessToken, 'tok');
    expect(read.isVerified, isTrue);
    expect(read.metadata, 'm1');
    expect((await storedJson(verificationKey))!['metadata'], 'm1');
  });

  test('a verification with no metadata is saved without the field', () async {
    await Storage().setVerification(VerificationState(accessToken: 'tok', expiresAt: inAnHour(), isVerified: true));
    expect((await storedJson(verificationKey))!.containsKey('metadata'), isFalse);
  });

  test('an expired verification reads as none and is deleted', () async {
    await Storage().setVerification(VerificationState(
        accessToken: 'tok', expiresAt: DateTime.now().millisecondsSinceEpoch - 1000, isVerified: true));

    expect(await Storage().getVerification(), isNull);
    expect(await stored(verificationKey), isNull);
    expect(await makeCore().isVerified(), isFalse);
  });

  test('a corrupt verification reads as none and is deleted', () async {
    useMemoryStorage({verificationKey: '{not json'});

    expect(await Storage().getVerification(), isNull);
    expect(await stored(verificationKey), isNull);
  });

  test('OIDC state is saved under io.agewallet.sdk.oidc and read back', () async {
    await Storage().setOidcState(const OidcState(state: 's', verifier: 'v', nonce: 'n'));

    final read = (await Storage().getOidcState())!;
    expect([read.state, read.verifier, read.nonce], ['s', 'v', 'n']);
    expect(await storedJson(oidcKey), {'state': 's', 'verifier': 'v', 'nonce': 'n'});
  });

  test('corrupt OIDC state reads as none and is deleted', () async {
    useMemoryStorage({oidcKey: '{not json'});

    expect(await Storage().getOidcState(), isNull);
    expect(await stored(oidcKey), isNull);
  });

  test('not verified when nothing is saved', () async {
    final core = makeCore();
    expect(await core.isVerified(), isFalse);
    expect(await core.getMetadata(), isNull);
  });

  test('clearVerification deletes the verification and the OIDC state', () async {
    final core = makeCore();
    await Storage().setVerification(VerificationState(accessToken: 'tok', expiresAt: inAnHour(), isVerified: true));
    await startFlow(core);

    await core.clearVerification();

    expect(await stored(verificationKey), isNull);
    expect(await stored(oidcKey), isNull);
    expect(await core.isVerified(), isFalse);
  });
}
