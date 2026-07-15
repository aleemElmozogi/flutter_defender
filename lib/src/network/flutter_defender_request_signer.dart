import 'dart:convert';
import 'dart:typed_data';

import '../native/flutter_defender_native.dart';

/// Signs a canonical request payload with the supplied key bytes.
typedef FlutterDefenderHmacSigner =
    String? Function({required Uint8List payload, required Uint8List key});

/// Timestamp and signature headers produced for an outgoing request.
class FlutterDefenderSignedRequest {
  const FlutterDefenderSignedRequest({
    required this.timestamp,
    required this.signature,
  });

  final String timestamp;
  final String signature;

  Map<String, String> get headers => <String, String>{
    'X-Defender-Timestamp': timestamp,
    'X-Defender-Signature': signature,
  };
}

/// Produces native HMAC-SHA256 signatures for exact outgoing request bodies.
class FlutterDefenderRequestSigner {
  FlutterDefenderRequestSigner({
    required String secretSalt,
    DateTime Function()? nowProvider,
    FlutterDefenderHmacSigner? hmacSigner,
  }) : _secretSaltBytes = Uint8List.fromList(utf8.encode(secretSalt)),
       _nowProvider = nowProvider ?? DateTime.now,
       _hmacSigner =
           hmacSigner ?? FlutterDefenderNative.instance.signHmacSha256Hex {
    if (secretSalt.isEmpty) {
      throw ArgumentError.value(secretSalt, 'secretSalt', 'Must not be empty.');
    }
  }

  final Uint8List _secretSaltBytes;
  final DateTime Function() _nowProvider;
  final FlutterDefenderHmacSigner _hmacSigner;

  FlutterDefenderSignedRequest sign({
    required List<int> bodyBytes,
    String? timestamp,
  }) {
    final resolvedTimestamp =
        timestamp ?? _nowProvider().toUtc().millisecondsSinceEpoch.toString();
    final payload = _canonicalPayload(
      bodyBytes: bodyBytes,
      timestamp: resolvedTimestamp,
    );
    final signature = _hmacSigner(payload: payload, key: _secretSaltBytes);
    if (signature == null) {
      throw StateError('Flutter Defender native signer is unavailable.');
    }
    return FlutterDefenderSignedRequest(
      timestamp: resolvedTimestamp,
      signature: signature,
    );
  }

  FlutterDefenderSignedRequest signString({
    required String body,
    Encoding encoding = utf8,
    String? timestamp,
  }) {
    return sign(bodyBytes: encoding.encode(body), timestamp: timestamp);
  }

  Uint8List _canonicalPayload({
    required List<int> bodyBytes,
    required String timestamp,
  }) {
    final timestampBytes = utf8.encode(timestamp);
    return Uint8List.fromList(<int>[...timestampBytes, 0x2e, ...bodyBytes]);
  }
}
