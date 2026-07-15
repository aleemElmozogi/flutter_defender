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
  flutter_defender: ^0.5.1
```

### Android release emulator launch block

`enableEmulatorDetectionRelease` blocks guarded Flutter screens in release
builds. If you need the stricter policy where a release APK is blocked before
Flutter starts, make the package guard activity your Android launcher and point
it at your real Flutter activity:

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

<!-- Keep your existing MainActivity settings, but remove MAIN/LAUNCHER from it. -->
<activity
    android:name=".MainActivity"
    android:exported="false"
    android:theme="@style/LaunchTheme" />
```

No Gradle change is required. Debug and profile builds remain runnable on
emulators; non-debuggable release-like builds are blocked at launch when an
emulator is detected. Android can still install a release APK on a compatible
emulator, so this is launch-time enforcement rather than install prevention. If
your manifest does not already define it, add
`xmlns:tools="http://schemas.android.com/tools"` to the root `<manifest>` tag.
If `TARGET_ACTIVITY` is wrong, the native guard shows a configuration error and
logs the missing activity instead of crashing.

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
  matching Git tag such as `v0.5.1`.
- Pushing that tag triggers the publish workflow, which runs a final
  `flutter pub publish --dry-run` and then publishes to pub.dev.

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
