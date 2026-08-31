import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_defender/flutter_defender.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects an empty secret salt', () {
    expect(
      () => FlutterDefenderRequestSigner(secretSalt: ''),
      throwsArgumentError,
    );
  });

  test('signs timestamp dot exact raw body bytes', () {
    Uint8List? capturedPayload;
    Uint8List? capturedKey;
    final FlutterDefenderRequestSigner signer = FlutterDefenderRequestSigner(
      secretSalt: 'secret',
      hmacSigner: ({required Uint8List payload, required Uint8List key}) {
        capturedPayload = Uint8List.fromList(payload);
        capturedKey = Uint8List.fromList(key);
        return 'signature';
      },
    );

    final FlutterDefenderSignedRequest signed = signer.sign(
      bodyBytes: <int>[0x00, 0xff, 0x2e],
      timestamp: '1234',
    );

    expect(capturedPayload, <int>[...utf8.encode('1234.'), 0x00, 0xff, 0x2e]);
    expect(capturedKey, utf8.encode('secret'));
    expect(signed.timestamp, '1234');
    expect(signed.signature, 'signature');
    expect(signed.headers, <String, String>{
      'X-Defender-Timestamp': '1234',
      'X-Defender-Signature': 'signature',
    });
  });

  test('uses the UTC epoch timestamp from the injected clock', () {
    final FlutterDefenderRequestSigner signer = FlutterDefenderRequestSigner(
      secretSalt: 'secret',
      nowProvider: () => DateTime.parse('2026-07-15T10:00:00+02:00'),
      hmacSigner: ({required Uint8List payload, required Uint8List key}) =>
          'signature',
    );

    final FlutterDefenderSignedRequest signed = signer.signString(body: '{}');

    expect(signed.timestamp, '1784102400000');
  });

  test('fails when the native signer is unavailable', () {
    final FlutterDefenderRequestSigner signer = FlutterDefenderRequestSigner(
      secretSalt: 'secret',
      hmacSigner: ({required Uint8List payload, required Uint8List key}) =>
          null,
    );

    expect(
      () => signer.signString(body: '{}', timestamp: '1234'),
      throwsStateError,
    );
  });
}
