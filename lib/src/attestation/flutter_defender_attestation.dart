import 'dart:convert';
import 'dart:typed_data';

import '../../flutter_defender_platform_interface.dart';

/// Server-verifiable platform attestation primitives.
///
/// These methods return attestation artifacts only. The consuming app must send
/// them to a trusted backend for verification and authorization. A client-side
/// success result is not proof that the app or device is trustworthy.
class FlutterDefenderAttestation {
  FlutterDefenderAttestation._();

  static const int _maxPlayIntegrityRequestHashBytes = 500;

  static final FlutterDefenderAttestation instance =
      FlutterDefenderAttestation._();

  FlutterDefenderPlatform get _platform => FlutterDefenderPlatform.instance;

  /// Prepares an Android Play Integrity standard-token provider.
  ///
  /// The Cloud project number is public configuration. Never include service
  /// account credentials in the application.
  Future<void> preparePlayIntegrity({required int cloudProjectNumber}) {
    if (cloudProjectNumber <= 0) {
      throw ArgumentError.value(
        cloudProjectNumber,
        'cloudProjectNumber',
        'Must be a positive Google Cloud project number.',
      );
    }
    return _platform.preparePlayIntegrity(cloudProjectNumber);
  }

  /// Obtains an encrypted Android Play Integrity token for [requestHash].
  ///
  /// The backend must decode the token with Google, verify the app and device
  /// verdicts, and compare this hash with its own canonical request hash.
  Future<String> requestPlayIntegrityToken({required String requestHash}) {
    if (requestHash.trim().isEmpty) {
      throw ArgumentError.value(
        requestHash,
        'requestHash',
        'Must not be empty.',
      );
    }
    final int requestHashBytes = utf8.encode(requestHash).length;
    if (requestHashBytes > _maxPlayIntegrityRequestHashBytes) {
      throw ArgumentError.value(
        requestHashBytes,
        'requestHash',
        'Must not exceed $_maxPlayIntegrityRequestHashBytes UTF-8 bytes.',
      );
    }
    return _requirePlayIntegrityToken(
      _platform.requestPlayIntegrityToken(requestHash),
    );
  }

  static Future<String> _requirePlayIntegrityToken(
    Future<String> tokenFuture,
  ) async {
    final String token = await tokenFuture;
    if (token.trim().isEmpty) {
      throw StateError('Play Integrity returned an empty token.');
    }
    return token;
  }

  /// Whether Apple App Attest is available on the current iOS device.
  Future<bool> isAppAttestSupported() {
    return _platform.isAppAttestSupported();
  }

  /// Generates a new Apple App Attest key and returns its key identifier.
  ///
  /// Generate once per user account per installation, then persist the
  /// identifier. The private key remains protected by Apple.
  Future<String> generateAppAttestKey() async {
    final String keyId = await _platform.generateAppAttestKey();
    if (keyId.trim().isEmpty) {
      throw StateError('App Attest returned an empty key identifier.');
    }
    return keyId;
  }

  /// Attests an App Attest key using a server-bound SHA-256 hash.
  Future<Uint8List> attestAppAttestKey({
    required String keyId,
    required Uint8List clientDataHash,
  }) {
    _validateAppAttestInput(keyId, clientDataHash);
    return _requireArtifact(
      _platform.attestAppAttestKey(
        keyId: keyId,
        clientDataHash: clientDataHash,
      ),
      operation: 'App Attest key attestation',
    );
  }

  /// Signs a server-bound SHA-256 hash with an attested App Attest key.
  Future<Uint8List> generateAppAttestAssertion({
    required String keyId,
    required Uint8List clientDataHash,
  }) {
    _validateAppAttestInput(keyId, clientDataHash);
    return _requireArtifact(
      _platform.generateAppAttestAssertion(
        keyId: keyId,
        clientDataHash: clientDataHash,
      ),
      operation: 'App Attest assertion',
    );
  }

  static Future<Uint8List> _requireArtifact(
    Future<Uint8List> artifactFuture, {
    required String operation,
  }) async {
    final Uint8List artifact = await artifactFuture;
    if (artifact.isEmpty) {
      throw StateError('$operation returned an empty artifact.');
    }
    return artifact;
  }

  static void _validateAppAttestInput(String keyId, Uint8List clientDataHash) {
    if (keyId.trim().isEmpty) {
      throw ArgumentError.value(keyId, 'keyId', 'Must not be empty.');
    }
    if (clientDataHash.length != 32) {
      throw ArgumentError.value(
        clientDataHash.length,
        'clientDataHash',
        'Must contain exactly 32 SHA-256 bytes.',
      );
    }
  }
}
