# flutter_defender

Secure-screen protection for Flutter apps on Android and iOS.

`flutter_defender` is built for banking-style flows where guarded screens must:
- hide Android recents/screenshot content with `FLAG_SECURE`
- react to screenshot and live-capture events
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
    pinBackgroundTimeoutSeconds: 120,
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
- `pinBackgroundTimeoutSeconds`
- `enableForegroundCheck`
- `enableEmulatorDetectionRelease`
- `onLogoutRequested`
- `blockingScreenBuilder`
- `uiTheme`
- `blockingLocale`
- `messageResolver`
- `blockingTitleResolver`

### `FlutterDefenderSensitiveGuard`

Use for any guarded screen that should:
- enable Android secure-window protection
- react to overlay hardening events on Android
- react to capture/foreground/emulator policy failures

### `FlutterDefenderOtpGuard`

Use for OTP flows. On timeout, only the enclosing OTP route is popped.

### `FlutterDefender.instance.setAuthenticated(bool)`

Controls the authenticated-session timeout logic. Call:
- `true` after successful login
- `false` on logout or session clear

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
| Overlay protection | Mitigation-based hardening | Not supported |
| Emulator / simulator release block | Yes | Yes |

Important limitations:
- **Android overlay defense is mitigation-based.** The plugin hardens guarded screens and reports obscured-touch violations; it does not claim perfect detection of every hostile overlay.
- **iOS screenshot detection is after capture.** The system screenshot has already happened when the notification arrives.
- **iOS has no hostile-overlay defense in this package.**
- **Release-only emulator/simulator blocking** applies on guarded screens when `enableEmulatorDetectionRelease` is enabled.

## Background Timeout Behavior

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
- custom blocking UI
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

## License

Apache-2.0
