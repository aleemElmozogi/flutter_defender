# flutter_defender

Unified Flutter security helpers for banking-style apps: sensitive-route hardening, optional blocking overlays, and platform guardrails on **Android** and **iOS**.

## Features

- **Route-aware `FLAG_SECURE` (Android)** toggles when entering or leaving routes you mark as sensitive.
- **Blocking overlay** when policy is violated (screen capture, overlay permission on sensitive routes, foreground checks, release-mode emulator).
- **Screenshot attempt** feedback on sensitive routes (Android 14+ screen capture callback where available).
- **Lifecycle rules**: optional OTP route pop after background timeout; optional logout callback after long background while the app reports the user as authenticated (`setAuthenticated(true)`).
- **Localization** for built-in blocking copy (English, Spanish, French, Arabic). Extend by adding ARB files under `lib/l10n/` and running code generation.
- **Flexible i18n**: use your app’s existing `MaterialApp` locale, merge `supportedLocales`, force a locale only for the blocking overlay, or plug in your own string resolvers.
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

### 1. Localization (choose what fits your app)

The blocking overlay reads strings from a `BuildContext` under your `MaterialApp`. You can combine the plugin with your app in several ways.

#### A. Same locale as the rest of the app (recommended)

Append the defender delegate to your **existing** delegates list so the overlay inherits the same `Locale` as the rest of the UI. Merge `supportedLocales` so every language your app claims to support is listed (include defender locales you ship):

```dart
import 'package:flutter_defender/flutter_defender.dart';
// import 'package:my_app/l10n/app_localizations.dart';

MaterialApp(
  locale: appLocale, // optional: however you already drive locale
  localizationsDelegates: const [
    // AppLocalizations.delegate,
    // ...your other delegates,
    FlutterDefenderLocalizations.delegate,
  ],
  supportedLocales: mergeFlutterDefenderSupportedLocales(
    const [
      Locale('en'),
      Locale('de'),
      // ...your AppLocalizations.supportedLocales,
    ],
  ),
  home: const HomeScreen(),
);
```

`mergeFlutterDefenderSupportedLocales` unions your list with `FlutterDefenderLocalizations.supportedLocales` without duplicate entries (first occurrence wins). It is exported from `package:flutter_defender/flutter_defender.dart`.

If you omit `FlutterDefenderLocalizations.delegate`, the plugin uses **English fallbacks** from `FlutterDefenderMessages` unless you use option B or C below.

#### B. Force a locale only for the blocking UI

If the blocking overlay should always use a specific language (independent of `MaterialApp.locale`), pass it to `init`:

```dart
await defender.init(
  // ...
  blockingLocale: const Locale('ar'),
);
```

The overlay is wrapped with `Localizations.override` and an appropriate `TextDirection` for RTL languages such as Arabic.

#### C. Wire strings to your own `AppLocalizations`

If you already maintain all copy in your app, you can skip defender ARBs for the overlay body and title:

```dart
await defender.init(
  // ...
  messageResolver: (context, id) {
    // final loc = AppLocalizations.of(context)!;
    // return switch (id) { ... };
    return FlutterDefenderMessages.stringFor(id);
  },
  blockingTitleResolver: (context) {
    // return AppLocalizations.of(context)!.securityPolicyTitle;
    return FlutterDefenderMessages.blockingScreenTitle;
  },
);
```

When `messageResolver` is set, it is used for every blocking **message** line. When `blockingTitleResolver` is set, the default `BlockingScreen` uses it for the **title** (your `blockingScreenBuilder` can ignore this and draw anything you want).

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
  otpBackgroundTimeoutSeconds: 60,
  pinBackgroundTimeoutSeconds: 120,
  enableOverlayDetection: true,
  enableForegroundCheck: true,
  enableEmulatorDetectionRelease: true,
  onLogoutRequested: () {
    // Clear session after long background while authenticated (see below)
  },
  blockingScreenBuilder: null, // use default BlockingScreen + uiTheme
  uiTheme: FlutterDefenderUiTheme.defaults.copyWith(
    backgroundColor: const Color(0xFF0D1117),
  ),
  blockingLocale: null,
  messageResolver: null,
  blockingTitleResolver: null,
);
```

After login and logout, tell the plugin whether a banking session is active (PIN/session background timeout only runs while this is `true`; OTP pop still uses `otpRouteName` only):

```dart
defender.setAuthenticated(true);  // e.g. after successful login
defender.setAuthenticated(false); // e.g. on logout (also clears pending background clock)
```

Call `defender.dispose()` when tearing down the app shell (for example in tests or logout flows that remove the observer entirely).

### 4. Custom blocking widget

`blockingScreenBuilder` receives the **already localized** message string (after `messageResolver` / `FlutterDefenderLocalizations` / fallbacks):

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

This project is licensed under the **Apache License 2.0**; see the [`LICENSE`](LICENSE) file in the repository root.
