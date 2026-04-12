# flutter_defender

Unified Flutter security helpers for banking-style apps: sensitive-route hardening, optional blocking overlays, and platform guardrails on **Android** and **iOS**.

## Features

- **Route-aware `FLAG_SECURE` (Android)** toggles when entering or leaving routes you mark as sensitive.
- **Blocking overlay** when policy is violated (screen capture, overlay permission on sensitive routes, foreground checks, release-mode emulator).
- **Screenshot attempt** feedback on sensitive routes (Android 14+ screen capture callback where available).
- **Lifecycle rules**: optional OTP route pop after background timeout; optional logout callback after authenticated-route background timeout.
- **Localization** for built-in blocking copy (English, Spanish, French, Arabic). Extend by adding ARB files under `lib/l10n/` and running code generation.
- **Custom default blocking UI** via `FlutterDefenderUiTheme`, or supply your own `blockingScreenBuilder`.

## Installation

Add the dependency (path, git, or pub.dev when published):

```yaml
dependencies:
  flutter_defender:
    path: ../flutter_defender  # example
```

Run `flutter pub get`.

## App setup

### 1. Localization delegates

Register the package localizations on your root `MaterialApp` (or `CupertinoApp` with compatible delegates) so blocking messages and titles resolve correctly:

```dart
import 'package:flutter_defender/flutter_defender.dart';

MaterialApp(
  localizationsDelegates: FlutterDefenderLocalizations.localizationsDelegates,
  supportedLocales: FlutterDefenderLocalizations.supportedLocales,
  // Optionally set locale: Locale('ar'), etc.
  home: const HomeScreen(),
);
```

If delegates are missing, the plugin falls back to English strings from `FlutterDefenderMessages`.

### 2. Navigator observer

Attach the singleton observer so the defender knows the current route:

```dart
final defender = FlutterDefender.instance;

MaterialApp(
  navigatorObservers: [defender.navigatorObserver],
  // ... localizationsDelegates, supportedLocales, routes / home
);
```

Use a `GlobalKey<NavigatorState>` on the same navigator if you rely on programmatic navigation from outside `MaterialApp` routes; the observer still receives pushes/pops.

### 3. Initialize

Call `init` once you know your route names (must match the names used in `Navigator` / `MaterialApp` routes, for example `ModalRoute.of(context)!.settings.name`):

```dart
await defender.init(
  sensitiveRoutes: ['/pin', '/statement', '/otp'],
  otpRouteName: '/otp',
  authenticatedRoutes: ['/home', '/accounts'],
  otpBackgroundTimeoutSeconds: 60,
  pinBackgroundTimeoutSeconds: 120,
  enableOverlayDetection: true,
  enableForegroundCheck: true,
  enableEmulatorDetectionRelease: true,
  onLogoutRequested: () {
    // Clear session after long background on authenticated routes
  },
  blockingScreenBuilder: null, // use default BlockingScreen + uiTheme
  uiTheme: FlutterDefenderUiTheme.defaults.copyWith(
    backgroundColor: const Color(0xFF0D1117),
  ),
);
```

Call `defender.dispose()` when tearing down the app shell (for example in tests or logout flows that remove the observer entirely).

### 4. Custom blocking widget

`blockingScreenBuilder` receives the **already localized** message string:

```dart
await defender.init(
  // ...
  blockingScreenBuilder: (message) => MySecuritySheet(message: message),
);
```

## Localization for maintainers

Strings live in ARB files under `lib/l10n/` (for example `app_en.arb`, `app_ar.arb`). After editing ARBs:

```bash
cd /path/to/flutter_defender
flutter gen-l10n
```

Configuration is in `l10n.yaml`. Generated Dart files are written to `lib/l10n/`.

## Android plugin identifier

The Android embedding class is registered under the namespace **`aleem.flutter.defender`** (`FlutterDefenderPlugin`).

## Platform APIs

The plugin exposes methods such as `getPlatformVersion`, `setFlagSecure`, `isOverlayPermissionDetected`, `isAppInForeground`, `isEmulator`, and `isScreenCaptured` through `FlutterDefenderPlatform`. Typical app code uses `FlutterDefender.instance` and `init` as above.

## Example

See the `example/` app for delegates, locale switching, and a preview of the default blocking UI.

```bash
cd example
flutter run
```

## Testing

```bash
flutter test
flutter analyze
```

## License

See the repository or package metadata for license terms.
