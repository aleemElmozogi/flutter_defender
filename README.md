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
- `FlutterDefenderOtpGuard`

There is no route-observer setup. A guarded screen protects itself before the sensitive child is revealed.

## Installation

```yaml
dependencies:
  flutter_defender: ^0.2.0
```

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

## API

### `FlutterDefender.instance.init(...)`

Options:
- `otpBackgroundTimeoutSeconds`
- `authenticatedBackgroundTimeoutSeconds`
- `enableForegroundCheck`
- `enableEmulatorDetectionRelease`
- `enableRootDetection` (defaults to `true` in release, `false` in debug/profile)
- `enableProxyVpnDetection` (defaults to `true` in release, `false` in debug/profile)
- `enableRaspDetection` (defaults to `true` in release, `false` in debug/profile)
- `enableSecureStorageHelper` (default `false`)
- `clearSecureStorageOnLogout` (default `false`)
- `onLogoutRequested`
- `onRootDetected`
- `onProxyOrVpnDetected`
- `onTamperingDetected`
- `blockingScreenBuilder`
- `uiTheme`
- `blockingLocale`
- `messageResolver`
- `blockingTitleResolver`

## Advanced Security Layers

All advanced layers are optional and configured at `init`.

### Root / Jailbreak Detection

- Android checks common root indicators (for example `su`, Magisk paths, `test-keys`).
- iOS checks common jailbreak indicators (for example Cydia paths and sandbox write escape).
- Callback: `onRootDetected`
- Policy toggle: `enableRootDetection`

### Proxy / VPN Detection

- Detects active proxy settings and VPN transport/interface indicators.
- Callback: `onProxyOrVpnDetected`
- Policy toggle: `enableProxyVpnDetection`

### Basic RASP

- Detects debugger attachment and common hooking artifacts (best-effort).
- Callback: `onTamperingDetected`
- Policy toggle: `enableRaspDetection`

### Secure Storage Helper (Optional)

- Provides convenience secure key/value methods backed by:
  - Android: Keystore-backed encrypted shared preferences
  - iOS: Keychain
- Toggle: `enableSecureStorageHelper`
- Optional lifecycle integration: `clearSecureStorageOnLogout`

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
| Secure screenshots / recents | Yes, via `FLAG_SECURE` | No direct equivalent |
| Screenshot event | Android 14+ screenshot callback | Post-capture notification only |
| Live capture / mirroring detection | Limited | Yes, via `UIScreen.isCaptured` |
| Conceal on focus loss (`inactive`) | Lifecycle-driven concealment | Yes, hides guarded content immediately |
| Overlay protection | Mitigation-based hardening | Not supported |
| Emulator / simulator release block | Yes | Yes |
| Root / jailbreak detection | Yes (best-effort indicators) | Yes (best-effort indicators) |
| Proxy / VPN detection | Yes | Yes |
| Basic RASP (debugger / hooking) | Yes | Yes |
| Secure storage helper | Yes (Keystore-backed) | Yes (Keychain-backed) |

Important limitations:
- **Android overlay defense is mitigation-based.** The plugin hardens guarded screens and reports obscured-touch violations; it does not claim perfect detection of every hostile overlay.
- **iOS screenshot detection is after capture.** The system screenshot has already happened when the notification arrives.
- **iOS uses privacy concealment, not hostile-overlay detection.** Guarded content is hidden when the app becomes inactive, such as during Control Center, Notification Center, Siri, calls, or app-switcher transitions.
- **Release-only emulator/simulator blocking** applies on guarded screens when `enableEmulatorDetectionRelease` is enabled.

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
cd example && flutter test
flutter pub publish --dry-run
```

## Release Automation

This repository includes GitHub Actions for CI and publishing:

- Pull requests run package and example analysis plus tests.
- Pushes to `main` / `master` rerun those checks, verify that `pubspec.yaml`
  contains a version higher than the previous branch tip, and then create a
  matching Git tag such as `v0.2.1`.
- Pushing that tag triggers the publish workflow, which runs a final
  `flutter pub publish --dry-run` and then publishes to pub.dev.

Important notes:

- The first release of a new package must still be published manually with
  `dart pub publish` / `flutter pub publish`.
- Pub.dev automated publishing from GitHub Actions only works for workflows
  triggered by tag pushes, so the main-branch workflow tags the release and the
  tag workflow performs the actual publish.
- Configure automated publishing for this package on pub.dev and require the
  GitHub Actions environment named `pub.dev` to match the publish workflow.

## License

Apache-2.0
