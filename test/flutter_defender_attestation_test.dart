import 'dart:typed_data';

import 'package:flutter_defender/flutter_defender.dart';
import 'package:flutter_defender/flutter_defender_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAttestationPlatform extends FlutterDefenderPlatform {
  int? cloudProjectNumber;
  String? playRequestHash;
  String? appAttestKeyId;
  Uint8List? appAttestClientDataHash;
  String playToken = 'encrypted-play-integrity-token';
  String appAttestKey = 'apple-key-id';
  Uint8List attestationArtifact = Uint8List.fromList(<int>[1, 2, 3]);
  Uint8List assertionArtifact = Uint8List.fromList(<int>[4, 5, 6]);

  @override
  Future<void> preparePlayIntegrity(int cloudProjectNumber) async {
    this.cloudProjectNumber = cloudProjectNumber;
  }

  @override
  Future<String> requestPlayIntegrityToken(String requestHash) async {
    playRequestHash = requestHash;
    return playToken;
  }

  @override
  Future<bool> isAppAttestSupported() async => true;

  @override
  Future<String> generateAppAttestKey() async => appAttestKey;

  @override
  Future<Uint8List> attestAppAttestKey({
    required String keyId,
    required Uint8List clientDataHash,
  }) async {
    appAttestKeyId = keyId;
    appAttestClientDataHash = clientDataHash;
    return attestationArtifact;
  }

  @override
  Future<Uint8List> generateAppAttestAssertion({
    required String keyId,
    required Uint8List clientDataHash,
  }) async {
    appAttestKeyId = keyId;
    appAttestClientDataHash = clientDataHash;
    return assertionArtifact;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FlutterDefenderPlatform originalPlatform;
  late FakeAttestationPlatform fakePlatform;
  final FlutterDefenderAttestation attestation =
      FlutterDefenderAttestation.instance;

  setUp(() {
    originalPlatform = FlutterDefenderPlatform.instance;
    fakePlatform = FakeAttestationPlatform();
    FlutterDefenderPlatform.instance = fakePlatform;
  });

  tearDown(() {
    FlutterDefenderPlatform.instance = originalPlatform;
  });

  test('Play Integrity preparation and token requests are forwarded', () async {
    await attestation.preparePlayIntegrity(cloudProjectNumber: 123456789);
    final String token = await attestation.requestPlayIntegrityToken(
      requestHash: 'canonical-request-hash',
    );

    expect(fakePlatform.cloudProjectNumber, 123456789);
    expect(fakePlatform.playRequestHash, 'canonical-request-hash');
    expect(token, 'encrypted-play-integrity-token');
  });

  test('invalid Play Integrity arguments fail before the platform call', () {
    expect(
      () => attestation.preparePlayIntegrity(cloudProjectNumber: 0),
      throwsArgumentError,
    );
    expect(
      () => attestation.requestPlayIntegrityToken(requestHash: '  '),
      throwsArgumentError,
    );
    expect(
      () => attestation.requestPlayIntegrityToken(
        requestHash: List<String>.filled(501, 'a').join(),
      ),
      throwsArgumentError,
    );
  });

  test('empty platform attestation results fail closed', () async {
    fakePlatform.playToken = '';
    await expectLater(
      attestation.requestPlayIntegrityToken(requestHash: 'request-hash'),
      throwsStateError,
    );

    fakePlatform.appAttestKey = '  ';
    await expectLater(attestation.generateAppAttestKey(), throwsStateError);

    fakePlatform.attestationArtifact = Uint8List(0);
    await expectLater(
      attestation.attestAppAttestKey(
        keyId: 'apple-key-id',
        clientDataHash: Uint8List(32),
      ),
      throwsStateError,
    );

    fakePlatform.assertionArtifact = Uint8List(0);
    await expectLater(
      attestation.generateAppAttestAssertion(
        keyId: 'apple-key-id',
        clientDataHash: Uint8List(32),
      ),
      throwsStateError,
    );
  });

  test('App Attest operations preserve binary artifacts', () async {
    final Uint8List clientDataHash = Uint8List.fromList(
      List<int>.generate(32, (int index) => index),
    );

    expect(await attestation.isAppAttestSupported(), isTrue);
    expect(await attestation.generateAppAttestKey(), 'apple-key-id');
    expect(
      await attestation.attestAppAttestKey(
        keyId: 'apple-key-id',
        clientDataHash: clientDataHash,
      ),
      <int>[1, 2, 3],
    );
    expect(fakePlatform.appAttestKeyId, 'apple-key-id');
    expect(fakePlatform.appAttestClientDataHash, clientDataHash);

    expect(
      await attestation.generateAppAttestAssertion(
        keyId: 'apple-key-id',
        clientDataHash: clientDataHash,
      ),
      <int>[4, 5, 6],
    );
  });

  test('App Attest requires a key ID and an exact SHA-256 hash', () {
    expect(
      () => attestation.attestAppAttestKey(
        keyId: '',
        clientDataHash: Uint8List(32),
      ),
      throwsArgumentError,
    );
    expect(
      () => attestation.generateAppAttestAssertion(
        keyId: 'apple-key-id',
        clientDataHash: Uint8List(31),
      ),
      throwsArgumentError,
    );
  });
}
