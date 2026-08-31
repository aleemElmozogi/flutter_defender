# Platform attestation

Local root, jailbreak, emulator, and hooking checks are best-effort risk
signals. An attacker controlling the client process can patch their results.
Use `FlutterDefenderAttestation` when a trusted backend must authorize a
sensitive operation.

The package returns platform artifacts only:

- Android uses Play Integrity standard tokens.
- iOS uses App Attest hardware-backed keys and assertions.
- The backend verifies the artifact and makes the authorization decision.
- Client-side success is never proof that the app or device is trustworthy.

## Android: Play Integrity

### Setup

1. Enable Play Integrity for the host app's Google Cloud project and link it in
   Play Console using Google's
   [setup guide](https://developer.android.com/google/play/integrity/setup).
2. Warm the token provider before the first sensitive operation.
3. Create a canonical request containing the relevant action fields and a
   fresh, server-issued challenge or transaction identifier.
4. Send its digest as `requestHash`, then send the returned token and original
   request to the backend.

```dart
final attestation = FlutterDefenderAttestation.instance;

await attestation.preparePlayIntegrity(
  cloudProjectNumber: 123456789,
);

final integrityToken = await attestation.requestPlayIntegrityToken(
  requestHash: canonicalRequestHash,
);

// Send integrityToken and the original request to the backend.
```

The Cloud project number is public configuration. Never ship Google
service-account credentials in the app.

### Backend verification

The backend must ask Google to decode the token, then:

- verify the package name and signing certificate;
- compare `requestHash` with its own canonical request hash;
- evaluate the app and device integrity verdicts;
- bind the token to the expected user, operation, and fresh challenge; and
- allow, restrict, step up, or reject the operation according to server policy.

`requestHash` is limited to 500 UTF-8 bytes. Send a digest such as SHA-256, not
sensitive request data. Standard tokens include replay protection, but the
backend must still enforce request freshness and binding.

Warm-up calls contact Google, can take several seconds, and are limited to five
calls per app instance per minute. If Google reports that the prepared provider
is invalid, call `preparePlayIntegrity` again before requesting another token.
Follow Google's [standard request guide](https://developer.android.com/google/play/integrity/standard)
for the complete flow and retry guidance.

## iOS: App Attest

### Setup

1. Enable the App Attest capability and configure the
   [`com.apple.developer.devicecheck.appattest-environment`](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.devicecheck.appattest-environment)
   entitlement in the host app.
2. Generate a key for the installation and persist its key identifier.
3. Attest the key once using a fresh server challenge.
4. Generate an assertion over a fresh canonical request hash for later
   sensitive operations.

```dart
final attestation = FlutterDefenderAttestation.instance;

if (await attestation.isAppAttestSupported()) {
  final keyId = await attestation.generateAppAttestKey();
  final attestationObject = await attestation.attestAppAttestKey(
    keyId: keyId,
    clientDataHash: sha256ClientDataHash,
  );

  // After the backend accepts enrollment:
  final assertion = await attestation.generateAppAttestAssertion(
    keyId: keyId,
    clientDataHash: nextSha256ClientDataHash,
  );
}
```

`clientDataHash` must contain exactly 32 SHA-256 bytes. It must bind a unique
server challenge of at least 16 random bytes to the canonical operation data.

### Backend verification

During enrollment, validate Apple's certificate chain, nonce, app identity, and
public key. For later assertions, validate the signature, request binding, and
monotonically increasing assertion counter.

Persist the key identifier because Apple does not provide a recovery API. If
key attestation fails with `serverUnavailable`, retry later with the same key
and hash. For other attestation errors, discard the identifier and enroll a new
key.

Development and production keys are not interchangeable. TestFlight and App
Store builds use production. Keys do not survive reinstall, device migration,
or backup restoration. Follow Apple's
[client guide](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
and [server validation guide](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server).

## Failure policy

Unsupported devices and transient platform or network failures should enter an
explicit limited or step-up policy. Invalid signatures, identities, request
hashes, or replay evidence should cause the backend to reject the operation.

Native failures surface as `PlatformException` with stable routing codes:

| Code | Meaning |
| --- | --- |
| `play-integrity` | Google rejected or could not complete a token operation |
| `play-integrity-state` | The provider is not prepared or its state was superseded |
| `play-integrity-unavailable` | The Android provider is unavailable |
| `app-attest` | Apple rejected or could not complete an App Attest operation |
| `unsupported-platform` | The requested API does not exist on this platform |

On Android, `play-integrity` exposes Google's numeric
`StandardIntegrityErrorCode` in `details`. Retry only errors documented as
transient by Google.
