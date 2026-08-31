# flutter_defender

Secure-screen protection for Flutter apps on Android and iOS.

`flutter_defender` is a general security layer for apps that handle sensitive
data (finance, healthcare, enterprise, identity, and more). Guarded screens can:
- hide Android recents/screenshot content with `FLAG_SECURE`
- react to screenshot and live-capture events
- conceal sensitive content immediately when iOS loses focus
- enforce OTP/session background timeouts
- block release builds on emulators/simulators
- harden Android guarded screens against overlay-based tapjacking

## What Changed

This package uses **explicit guard widgets**:
- `FlutterDefenderSensitiveGuard`
- `FlutterDefenderSecureContentGuard`
- `FlutterDefenderOtpGuard`

There is no route-observer setup. A guarded screen protects itself before the sensitive child is revealed.

## Installation

```yaml
dependencies:
  flutter_defender: ^0.7.0
```

### Android release emulator launch block

`enableEmulatorDetectionRelease` blocks guarded Flutter screens in release
builds. If you need the stricter policy where a release APK is blocked before
Flutter starts, first edit the existing `.MainActivity` declaration in place.
Set `android:exported="false"`, keep its remaining attributes and metadata, and
delete this entire launcher intent filter from it:

```xml
<intent-filter>
    <action android:name="android.intent.action.MAIN" />
    <category android:name="android.intent.category.LAUNCHER" />
</intent-filter>
```

Do not add another `.MainActivity` declaration or leave it exported. During
manifest merging, activities match by `android:name`, and an additional
declaration without the filter does not remove the filter from the existing
declaration. A directly exported target activity can also bypass the launcher
guard. If `.MainActivity` currently handles external deep links, it needs a
separate guarded routing design; do not silently remove those filters.

Then add the package guard activity as a sibling of `.MainActivity` inside the
same `<application>` element and point it at the real Flutter activity:

```xml
<activity
    android:name="aleem.flutter.defender.ReleaseEmulatorGuardActivity"
    android:excludeFromRecents="true"
    android:exported="true"
    android:finishOnTaskLaunch="true"
    android:launchMode="singleTask"
    android:noHistory="true"
    android:taskAffinity=""
    android:theme="@style/LaunchTheme"
    tools:replace="android:exported">
    <meta-data
        android:name="aleem.flutter.defender.TARGET_ACTIVITY"
        android:value=".MainActivity" />
    <!-- Optional text overrides:
    <meta-data
        android:name="aleem.flutter.defender.BLOCK_TITLE"
        android:value="Unsupported device" />
    <meta-data
        android:name="aleem.flutter.defender.BLOCK_SUBTITLE"
        android:value="Security protection is enabled" />
    <meta-data
        android:name="aleem.flutter.defender.BLOCK_MESSAGE"
        android:value="This release build cannot run on emulators." />
    <meta-data
        android:name="aleem.flutter.defender.BLOCK_BUTTON"
        android:value="Close app" />
    -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
</activity>
```

No Gradle change is required. Debug and profile builds remain runnable on
emulators; non-debuggable release-like builds are blocked at launch when an
emulator is detected. Android can still install a release APK on a compatible
emulator, so this is launch-time enforcement rather than install prevention. If
your manifest does not already define it, add
`xmlns:tools="http://schemas.android.com/tools"` to the root `<manifest>` tag.
If `TARGET_ACTIVITY` is wrong, the native guard shows a configuration error and
logs the missing activity instead of crashing. In Android Studio's **Merged
Manifest** view, confirm that
`aleem.flutter.defender.ReleaseEmulatorGuardActivity` is the only activity with
the `MAIN` and `LAUNCHER` pair, and that `.MainActivity` is not exported. Two
launcher activities produce two icons, while an exported target can be started
without passing through the native guard.

## Quick Start

Initialize once before `runApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_defender/flutter_defender.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterDefender.instance.init(
    otpBackgroundTimeoutSeconds: 60,
    authenticatedBackgroundTimeoutSeconds: 120,
    onLogoutRequested: () {
      // Clear session and return to a safe route.
    },
  );

  runApp(const MyApp());
}
```

Tell the plugin when the authenticated session changes:

```dart
FlutterDefender.instance.setAuthenticated(true);
FlutterDefender.instance.setAuthenticated(false);
```

Wrap sensitive screens directly:

```dart
class StatementPage extends StatelessWidget {
  const StatementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FlutterDefenderSensitiveGuard(
      child: StatementView(),
    );
  }
}

class OtpPage extends StatelessWidget {
  const OtpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FlutterDefenderOtpGuard(
      child: OtpView(),
    );
  }
}
```

Wrap smaller sensitive regions when the rest of the screen should stay visible
and usable while the protected region is concealed:

```dart
class AccountSummaryCard extends StatelessWidget {
  const AccountSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const FlutterDefenderSecureContentGuard(
      child: BalanceCard(),
    );
  }
}
```

`FlutterDefenderSensitiveGuard` uses a full-screen blocking overlay for active
policy violations. When guarded content must be hidden before an explicit
blocking reason is available, it shows a default concealment placeholder styled
with `FlutterDefenderUiTheme`. `FlutterDefenderSecureContentGuard` uses the
same protection registration, but replaces only its own child bounds with the
themed placeholder and does not draw a route-level blocking screen.

On Android, activating any guard enables `FLAG_SECURE` on the activity window.
On iOS, activating any guard enables the native secure surface for the Flutter
root view. The scoped content guard controls the visible Dart replacement area,
but native screenshot protection applies to the Android window or shared iOS
Flutter surface rather than an individual Dart widget subtree.

Both guards accept `placeholderBuilder` if the host app wants custom replacement
content.

## API

### `FlutterDefender.instance.init(...)`

Options:
- `otpBackgroundTimeoutSeconds`
- `authenticatedBackgroundTimeoutSeconds` (default `120`; takes precedence
  over the deprecated `pinBackgroundTimeoutSeconds` alias)
- `enableForegroundCheck`
- `enableEmulatorDetectionRelease`
- `enableRootDetection` (defaults to `true` in release, `false` in debug/profile)
- `enableProxyVpnDetection` (default `false`)
- `enableRaspDetection` (default `false`)
- `enableSecureStorageHelper` (default `false`)
- `clearSecureStorageOnLogout` (default `false`)
- `failClosedOnPlatformError` (default `false`)
- `onLogoutRequested`
- `onRootDetected`
- `onProxyOrVpnDetected`
- `onTamperingDetected`
- `blockingScreenBuilder`
- `uiTheme`
- `blockingLocale`
- `messageResolver`
- `blockingTitleResolver`

`onLogoutRequested` may run while `init()` restores an expired cold-start
snapshot, before `runApp`. Keep it safe when no navigator or widget tree exists.

### Native Failure Policy

Runtime-state, advanced-signal, and native hardening channel failures are
fail-open by default to preserve host-app availability. Runtime state falls
back to foreground with no active capture, while advanced detection keeps any
available native FFI signals. Set `failClosedOnPlatformError: true` to keep
guarded content blocked with a protection-unavailable message when one of those
calls fails; a later successful protection sync clears that state.

Secure-storage errors are separate and always remain fail-fast.

## Advanced Security Layers

All advanced layers are optional and configured at `init`.

### Server-Verified Device and App Attestation

Local root, jailbreak, emulator, and hooking checks are best-effort risk
signals. An attacker controlling the client process can patch their results.
Use `FlutterDefenderAttestation` when a backend must authorize a sensitive
operation:

- Android uses Play Integrity standard requests.
- iOS uses App Attest hardware-backed keys and assertions.
- The package returns encrypted tokens or binary attestation artifacts only.
- A trusted backend must verify every artifact and make the authorization
  decision. Client-side success is never proof of trust.

Android setup:

1. Enable Play Integrity for the host app's Google Cloud project and link it in
   Play Console as described in the
   [official setup guide](https://developer.android.com/google/play/integrity/setup).
2. Warm the token provider before the first sensitive operation.
3. Hash a canonical request containing the relevant action fields and a fresh,
   server-issued challenge or transaction identifier.

```dart
final attestation = FlutterDefenderAttestation.instance;

await attestation.preparePlayIntegrity(
  cloudProjectNumber: 123456789,
);

final integrityToken = await attestation.requestPlayIntegrityToken(
  requestHash: canonicalRequestHash,
);

// Send integrityToken and the original request to the host app's backend.
```

The backend must ask Google to decode the token, verify the package and signing
certificate, compare `requestHash`, evaluate app/device integrity verdicts, and
then allow, restrict, or reject the operation. Never ship Google service-account
credentials in the app.

The `requestHash` is limited to 500 UTF-8 bytes. Send a digest such as SHA-256,
not sensitive request data. Standard tokens have replay protection, but the
backend must still bind each token to the expected user, operation, and fresh
server challenge. Warm-up calls contact Google, can take several seconds, and
are limited to five calls per app instance per minute. If Google reports that
the prepared token provider is invalid, call `preparePlayIntegrity` again before
requesting another token. See the
[standard request guide](https://developer.android.com/google/play/integrity/standard)
for the full client/server flow and retry guidance.

iOS setup:

1. Enable the App Attest capability and configure the
   [`com.apple.developer.devicecheck.appattest-environment`](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.devicecheck.appattest-environment)
   entitlement in the host app.
2. Generate one key per user account per installation and persist its key ID.
3. Attest that key once using a fresh server challenge.
4. Generate an assertion over a fresh, canonical request hash for later
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

`clientDataHash` must contain exactly 32 SHA-256 bytes and must bind a unique
server challenge of at least 16 random bytes to the canonical operation data.
The backend must validate
Apple's certificate chain, nonce, app identity, public key, signature, and
monotonically increasing assertion counter.

Persist the key identifier because Apple does not provide a way to recover it.
If key attestation fails with Apple's `serverUnavailable` error, retry later
with the same key and the same hash. For other attestation errors, discard the
identifier and enroll a new key. Development and production App Attest keys are
not interchangeable; TestFlight and App Store builds use production. Keys do
not survive app reinstall, device migration, or backup restoration. Follow
Apple's
[App Attest client guide](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
and
[server validation guide](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server).

Unsupported devices and transient platform/network failures should enter an
explicit limited or step-up policy. Invalid signatures, identities, request
hashes, or replay evidence should cause the backend to reject the sensitive
operation.

Native failures surface as `PlatformException`. Use the stable codes
`play-integrity`, `play-integrity-state`, `play-integrity-unavailable`,
`app-attest`, and `unsupported-platform` for policy routing. On Android,
`play-integrity` exposes Google's numeric `StandardIntegrityErrorCode` in
`details`; retry only the transient codes documented by Google.

### Root / Jailbreak Detection

- Android checks common root indicators (for example `su`, Magisk paths, `test-keys`).
- iOS checks common jailbreak indicators (for example Cydia paths and sandbox write escape).
- Callback: `onRootDetected`
- Policy toggle: `enableRootDetection`

### Proxy / VPN Detection

- Detects active proxy settings and VPN transport/interface indicators.
- Disabled by default in every build mode; enable it explicitly when the host
  app wants proxy/VPN usage to block guarded content.
- Callback: `onProxyOrVpnDetected`
- Policy toggle: `enableProxyVpnDetection`

### Basic RASP

- Uses a native C++ FFI core for debugger, root/jailbreak, emulator, and
  common hooking-artifact signals, merged with the platform detector fallback.
- Disabled by default in every build mode; enable it explicitly when the host
  app wants debugger or tampering signals to block guarded content.
- Debugger attachment is treated as tampering. If `enableRaspDetection` is
  forced on while running from Flutter tooling, Xcode, or Android Studio with a
  debugger attached, guarded content is expected to be blocked even on a clean
  device. Validate this policy in an unattached release/profile build when you
  need production-like behavior.
- Callback: `onTamperingDetected`
- Policy toggle: `enableRaspDetection`

### Request Signing

`FlutterDefenderRequestSigner` signs `timestamp.rawBodyBytes` using native
HMAC-SHA256 and returns headers you can attach to outgoing requests. Validate
the signature server-side using the same timestamp, exact raw body bytes, and
salt.

The embedded salt is recoverable from a sufficiently inspected or modified app,
so this is a tamper/replay signal, not client authentication. The server must
enforce a short timestamp window and a replay cache (for example, keyed by
signature plus timestamp); accepting a valid signature indefinitely makes a
captured request replayable.

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

### Secure Storage Helper (Optional)

- Provides convenience secure key/value methods backed by:
  - Android: Keystore-backed encrypted shared preferences
  - iOS: Keychain
- Toggle: `enableSecureStorageHelper`
- Optional lifecycle integration: `clearSecureStorageOnLogout`
- Failure policy: secure-storage platform errors are fail-fast and throw; only
  missing keys return `null` from `secureRead`.
- Key generation and storage I/O run on native background queues.

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

### `FlutterDefenderSensitiveGuard`

Use for any guarded screen that should:
- enable Android secure-window protection
- react to overlay hardening events on Android
- conceal content immediately when iOS enters `inactive`
- react to capture/foreground/emulator policy failures

### `FlutterDefenderOtpGuard`

Use for OTP flows. On timeout, only the enclosing OTP route is popped.

### `FlutterDefender.instance.setAuthenticated(bool)`

Controls the authenticated-session timeout logic. Call:
- `true` after successful login
- `false` on logout or session clear

`authenticatedBackgroundTimeoutSeconds` applies to this authenticated-session state.
The older `pinBackgroundTimeoutSeconds` name is deprecated because the timeout is
not tied to detecting a specific PIN page.

## Blocking UI

The built-in blocking UI is full-screen and always absorbs interaction.

You can customize the visible content with `blockingScreenBuilder`, but the plugin still owns the modal barrier and pointer absorption:

```dart
await FlutterDefender.instance.init(
  blockingScreenBuilder: (message) {
    return Center(child: Text(message));
  },
);
```

## Platform Notes

| Capability | Android | iOS |
| --- | --- | --- |
| Secure screenshots / recents | Yes, via window-level `FLAG_SECURE` | Secure text-entry backed surface for guarded content |
| Screenshot event | Android 14+ screenshot callback | Post-capture notification only |
| Live capture / mirroring detection | Limited | Yes, across connected screens via `UIScreen.isCaptured` |
| Conceal on focus loss (`inactive`) | Lifecycle-driven concealment | Yes, hides guarded content immediately |
| Overlay protection | Mitigation-based hardening | Not supported |
| Emulator / simulator release block | Guarded screens; optional native launch guard | Flutter/Xcode tooling blocks release simulator builds |
| Root / jailbreak detection | Yes (best-effort indicators) | Yes (best-effort indicators) |
| Proxy / VPN detection | Yes | Yes |
| Basic RASP (debugger / hooking) | Yes | Yes |
| Secure storage helper | Yes (Keystore-backed) | Yes (Keychain-backed) |

Important limitations:
- **Android overlay defense is mitigation-based.** The plugin hardens guarded screens and reports obscured-touch violations; it does not claim perfect detection of every hostile overlay.
- **Runtime detectors are best-effort indicators.** Root-hiding and instrumentation can evade path/process checks, and Android proxy detection can miss network-specific proxy configuration that is not exposed through process system properties.
- **Android secure screenshot protection is window-level.** `FLAG_SECURE` protects the activity window while a guard is active; it cannot be limited to one Dart widget subtree.
- **iOS screenshot detection is after capture.** The system screenshot has already happened when the notification arrives.
- **iOS guarded content uses a secure text-entry backed surface.** This is the closest practical equivalent to Telegram-style screenshot blanking, but it relies on iOS secure-rendering behavior and should be validated on real devices for each supported iOS release. Because Flutter renders through a shared native surface, native secure wrapping is applied to the Flutter root view while a guard is active.
- **iOS uses privacy concealment, not hostile-overlay detection.** Guarded content is hidden when the app becomes inactive, such as during Control Center, Notification Center, Siri, calls, or app-switcher transitions.
- **Release-only emulator/simulator blocking** applies on guarded screens when `enableEmulatorDetectionRelease` is enabled. On Android, the optional package launcher guard blocks release-like emulator launches before Flutter starts. On iOS, `flutter build ios --simulator --release` is already rejected by Flutter/Xcode tooling.
- **Lifecycle snapshots are not secrets.** They contain timestamps and guard/session flags in `SharedPreferences` / `UserDefaults`; clearing app data removes the cold-start timeout evidence.
- **Android secure storage still uses deprecated Jetpack `security-crypto`.** Existing storage remains supported for compatibility; migrate to direct Keystore-backed AES-GCM storage before removing that dependency in a breaking release.

## Background Timeout Behavior

- On iOS, guarded content is concealed immediately while the app is `inactive` and revealed again when the app becomes active.
- On Android, focus-only interruptions over a guarded screen (for example biometric prompts or permission dialogs) conceal guarded content while focus is lost, but do not start background timeouts and do not show the `foregroundRequired` blocking screen. Timeouts start only when the activity is actually paused.
- While an `FlutterDefenderOtpGuard` screen is active, background timeout pops only that OTP route.
- While `setAuthenticated(true)` is active, background timeout calls `onLogoutRequested`.
- Timeout state is persisted across process death and rechecked on the next launch.

## Localization

Register the package delegates in your app:

```dart
MaterialApp(
  localizationsDelegates: const [
    ...FlutterDefenderLocalizations.localizationsDelegates,
  ],
  supportedLocales: mergeFlutterDefenderSupportedLocales(
    const [Locale('en')],
  ),
);
```

Supported built-in locales:
- English
- Arabic
- French
- Spanish

## Example App

The `example/` app demonstrates:
- guarded sensitive screens
- OTP guard behavior
- authenticated timeout wiring
- blocking UI customization profiles (`blockingScreenBuilder`, `uiTheme`, `blockingLocale`, `messageResolver`, `blockingTitleResolver`)
- policy toggle profiles for `enableForegroundCheck` and `enableEmulatorDetectionRelease`
- advanced-layer profiles for root/jailbreak, proxy/VPN, RASP, and secure storage helper
- manual validation steps for release emulator/simulator checks and capture handling

Run it with:

```bash
cd example
flutter run
```

## Development Checks

```bash
flutter analyze
flutter test
c++ -std=c++17 -Wall -Wextra -Werror -I src/native/include src/native/src/crypto/defender_crypto.cpp test/native/defender_crypto_test.cpp -o /tmp/flutter_defender_crypto_test && /tmp/flutter_defender_crypto_test
cd example && flutter build apk --release
cd example && flutter build ios --simulator --debug --no-pub
cd example && flutter test
flutter pub publish --dry-run
```

## Release Automation

This repository includes GitHub Actions for CI and publishing:

- Pull requests run package and example analysis plus tests.
- CI verifies that `pubspec.yaml`, the podspec, and the latest released
  changelog entry use the same version.
- Pushes to `main` / `master` rerun those checks, verify that `pubspec.yaml`
  contains a version higher than the previous branch tip, and then create a
  matching Git tag such as `v0.7.0`.
- Pushing that tag triggers the publish workflow, which reruns the full
  analyze/test gate (package, example, and native known-answer tests), checks
  that the tag matches the `pubspec.yaml` version, and only then runs
  `flutter pub publish --dry-run` followed by the actual publish to pub.dev.
  A manually pushed tag therefore cannot publish untested code.

Important notes:

- Pub.dev automated publishing from GitHub Actions only works for workflows
  triggered by tag pushes, so the main-branch workflow tags the release and the
  tag workflow performs the actual publish.
- GitHub does not start another workflow when a workflow pushes a tag with the
  default `GITHUB_TOKEN`. Add an Actions secret named `RELEASE_TAG_TOKEN`
  containing a fine-grained personal access token with repository
  `Contents: Read and write`; the release-tag workflow uses it only to push the
  release tag so `publish.yml` can run.
- Configure automated publishing for this package on pub.dev and require the
  GitHub Actions environment named `pub.dev` to match the publish workflow.

## License

Apache-2.0
