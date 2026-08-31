# Security layers and limitations

`flutter_defender` provides defense-in-depth controls for a Flutter client. It
does not replace backend authentication, authorization, replay prevention, or
transaction validation.

## Runtime signals

### Root and jailbreak detection

- Android checks common root indicators such as `su`, Magisk paths, and
  `test-keys`.
- iOS checks common jailbreak paths and sandbox write escape.
- Enable with `enableRootDetection`.
- React with `onRootDetected`.

These are best-effort signals. Root hiding and runtime instrumentation can evade
software checks.

### Proxy and VPN detection

- Detects active proxy settings and VPN transport or interface indicators.
- Disabled by default in every build mode.
- Enable with `enableProxyVpnDetection`.
- React with `onProxyOrVpnDetected`.

Android can miss network-specific proxy configuration that is not exposed
through process system properties.

### Basic RASP

- Combines a native C++ FFI core with platform-specific signals for debuggers,
  root/jailbreak, emulators, and common hooking artifacts.
- Disabled by default in every build mode.
- Enable with `enableRaspDetection`.
- React with `onTamperingDetected`.

Debugger attachment is treated as tampering. If RASP is enabled while running
from Flutter tooling, Xcode, or Android Studio with a debugger attached,
guarded content is expected to be blocked. Validate production policy in an
unattached release or profile build.

## Native failure policy

Runtime state, advanced signals, and native hardening calls fail open by
default to preserve host-app availability. Set
`failClosedOnPlatformError: true` to keep guarded content blocked with a
protection-unavailable message until a later protection sync succeeds.

Secure-storage errors are separate and always fail fast.

## Request signing

`FlutterDefenderRequestSigner` signs `timestamp.rawBodyBytes` using native
HMAC-SHA256 and returns headers for an outgoing request:

```dart
final signer = FlutterDefenderRequestSigner(
  secretSalt: 'your_obfuscated_salt',
);

final body = jsonEncode({'amount': 100});
final signed = signer.signString(body: body);

final headers = <String, String>{
  ...signed.headers,
  'Content-Type': 'application/json',
};
```

Validate the signature server-side using the same timestamp, exact raw body,
and salt. The embedded salt can be recovered from a sufficiently inspected or
modified app, so this is a tamper and replay signal—not client authentication.
The server must enforce a short timestamp window and a replay cache.

## Secure storage

The optional helper uses Keystore-backed encrypted shared preferences on
Android and Keychain on iOS:

```dart
await FlutterDefender.instance.init(
  enableSecureStorageHelper: true,
  clearSecureStorageOnLogout: true,
);

await FlutterDefender.instance.secureWrite(key: 'token', value: 'abc');
final token = await FlutterDefender.instance.secureRead('token');
await FlutterDefender.instance.secureDelete('token');
await FlutterDefender.instance.secureClearAll();
```

Only a missing key returns `null`; platform errors throw. Key generation and
storage I/O run on native background queues.

Android currently retains deprecated Jetpack `security-crypto` for storage
compatibility. A future breaking release should migrate existing storage to a
direct Keystore-backed AES-GCM implementation before removing it.

## Lifecycle and timeout behavior

- iOS conceals guarded content immediately while the app is inactive.
- Android conceals guarded content during focus-only interruptions, such as
  biometric prompts, without starting background timeouts. Timeouts start when
  the activity is paused.
- An active `FlutterDefenderOtpGuard` pops only its OTP route after timeout.
- An authenticated timeout calls `onLogoutRequested` while
  `setAuthenticated(true)` is active.
- Timeout state survives process death and is checked on the next launch.
- Lifecycle snapshots contain timestamps and guard/session flags, not secrets.
  Clearing app data removes this cold-start evidence.

`onLogoutRequested` may run while `init()` restores an expired snapshot, before
`runApp`. It must be safe when no navigator or widget tree exists.

## Platform limitations

| Area | Limitation |
| --- | --- |
| Android overlays | Mitigation-based hardening; no claim of detecting every hostile overlay |
| Android screenshots | `FLAG_SECURE` protects the activity window, not one Dart subtree |
| iOS screenshots | The screenshot notification arrives after capture |
| iOS secure rendering | Uses a secure text-entry backed surface and should be validated on real devices for supported iOS releases |
| iOS overlays | Uses privacy concealment on focus loss, not hostile-overlay detection |
| Emulator policy | Release-only and enforced on guarded screens, or at Android launch when the optional native guard is configured |

Because Flutter renders through a shared native surface, the iOS secure wrapper
is applied to the Flutter root view while any guard is active.
