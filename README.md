# flutter_defender

Defense-in-depth security controls for sensitive Flutter screens on Android and
iOS.

Use `flutter_defender` to conceal guarded content, enforce lifecycle timeouts,
detect common device risks, and request server-verifiable platform attestation.
It is designed for finance, healthcare, identity, enterprise, and other apps
that handle sensitive data.

## Features

| Capability | Android | iOS |
| --- | --- | --- |
| Screenshot and recent-app protection | `FLAG_SECURE` | Secure native surface |
| Capture and focus-loss handling | Screenshot and lifecycle events | Screenshot, live capture, and immediate concealment |
| Guarded screens and scoped content | Yes | Yes |
| OTP and authenticated-session timeouts | Yes | Yes |
| Root / jailbreak, proxy / VPN, and RASP signals | Yes | Yes |
| Release emulator / simulator policy | Yes | Yes |
| Server-verifiable integrity | Play Integrity | App Attest |
| Optional secure storage | Keystore-backed | Keychain-backed |

> `flutter_defender` is a client-side security layer, not an authorization
> system. Runtime signals can be bypassed on a controlled device. Sensitive
> operations must still be authorized by a trusted backend; see
> [Platform attestation](doc/attestation.md).

## Installation

```yaml
dependencies:
  flutter_defender: ^0.7.0
```

Then run:

```bash
flutter pub get
```

## Quick start

Initialize the package once before `runApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_defender/flutter_defender.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterDefender.instance.init(
    otpBackgroundTimeoutSeconds: 60,
    authenticatedBackgroundTimeoutSeconds: 120,
    onLogoutRequested: () {
      // Clear the session and return to a safe route.
    },
  );

  runApp(const MyApp());
}
```

Wrap sensitive UI directly—no route observer is required:

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
```

Choose the guard that matches the content:

| Guard | Use it for |
| --- | --- |
| `FlutterDefenderSensitiveGuard` | A complete screen that should block on policy violations |
| `FlutterDefenderSecureContentGuard` | A sensitive region while the rest of the screen remains usable |
| `FlutterDefenderOtpGuard` | An OTP route that should close after its background timeout |

Both sensitive-content guards accept `placeholderBuilder` for a custom
concealment state. Native screenshot protection applies to the Android window
or shared iOS Flutter surface, even when only one Dart region is replaced.

Tell the package when authentication changes:

```dart
FlutterDefender.instance.setAuthenticated(true);  // After login.
FlutterDefender.instance.setAuthenticated(false); // During logout.
```

## Configuration

Common `init` options:

| Option | Purpose | Default |
| --- | --- | --- |
| `otpBackgroundTimeoutSeconds` | Close an active OTP route after backgrounding | `60` |
| `authenticatedBackgroundTimeoutSeconds` | Request logout after an authenticated background timeout | `120` |
| `enableEmulatorDetectionRelease` | Block guarded release builds on emulators or simulators | `true` |
| `enableRootDetection` | Enable root or jailbreak indicators | Release: on; debug/profile: off |
| `enableProxyVpnDetection` | Block on proxy or VPN signals | `false` |
| `enableRaspDetection` | Block on debugger or hooking signals | `false` |
| `enableSecureStorageHelper` | Enable the optional storage API | `false` |
| `failClosedOnPlatformError` | Keep guarded content blocked after native protection errors | `false` |

Callbacks such as `onRootDetected`, `onProxyOrVpnDetected`, and
`onTamperingDetected` let the host app record or react to policy events. UI can
be customized with `blockingScreenBuilder`, `uiTheme`, locale, and message
resolvers.

For every option and its behavior, see the
[API reference](https://pub.dev/documentation/flutter_defender/latest/).

## Platform setup

### Android release launch guard

Guarded widgets can block an emulator after Flutter starts. For stricter
release-only enforcement before Flutter starts, configure
`ReleaseEmulatorGuardActivity` as the app's only launcher activity.

This manifest edit must leave exactly one `MAIN`/`LAUNCHER` activity. Do not add
a second `.MainActivity` declaration—the merged manifest can otherwise produce
two app icons or leave a bypassable exported activity.

Follow the complete [Android release launch guard setup](doc/android-release-guard.md).

### Platform attestation

Use `FlutterDefenderAttestation` when a backend needs stronger evidence for a
sensitive operation:

- Android: Play Integrity standard tokens.
- iOS: App Attest key enrollment and assertions.
- Backend: verify the artifact, request binding, app identity, freshness, and
  platform verdict before authorizing the operation.

Follow the complete [platform attestation guide](doc/attestation.md).

## Optional security layers

Root/jailbreak detection, proxy/VPN detection, RASP, request signing, and secure
storage are opt-in or policy-driven layers. Their results have different trust
boundaries and failure behavior.

Read [Security layers and limitations](doc/security.md) before enabling them in
production.

## Blocking UI

The built-in blocking UI is full-screen and absorbs interaction. You may
replace its visible content while the package retains the modal barrier:

```dart
await FlutterDefender.instance.init(
  blockingScreenBuilder: (message) {
    return Center(child: Text(message));
  },
);
```

## Localization

Register the package delegates in the host app:

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

Built-in locales: English, Arabic, French, and Spanish.

## Example

The [`example/`](example/) app demonstrates guards, lifecycle timeouts, policy
profiles, UI customization, advanced signals, and manual platform checks.

```bash
cd example
flutter run
```

## Documentation

- [Android release launch guard](doc/android-release-guard.md)
- [Platform attestation](doc/attestation.md)
- [Security layers and limitations](doc/security.md)
- [Development and release workflow](doc/development.md)
- [Changelog](CHANGELOG.md)

## License

Apache-2.0
