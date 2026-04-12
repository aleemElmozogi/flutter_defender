# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- _(nothing yet — add entries here before the next release)_

## [0.1.0] - 2026-04-12

### Added

- `FlutterDefender.setAuthenticated(bool)` so the app signals login/logout instead of passing a list of authenticated route names.

### Changed

- **Breaking:** `FlutterDefender.init` no longer accepts `authenticatedRoutes`. PIN/session background timeout uses `setAuthenticated(true)` only.

### Removed

- `FlutterDefenderConfig.authenticatedRouteSet` and related `init` parameter.

## [0.0.1] - 2026-04-12

### Added

- Flutter plugin `flutter_defender` for Android and iOS with method-channel bridge.
- Route-aware Android `FLAG_SECURE` toggling for configured sensitive routes.
- `FlutterDefenderNavigatorObserver` and `FlutterDefender.init` / `dispose` lifecycle.
- Blocking overlay for policy violations (overlay permission, screen capture, foreground check, release-mode emulator) and temporary overlay for screenshot attempts where supported.
- Background timeout handling: OTP route pop and optional authenticated-route logout callback.
- Generated localizations (ARB): English, Spanish, French, Arabic; `flutter gen-l10n` via `l10n.yaml`.
- `FlutterDefenderUiTheme` for default `BlockingScreen` styling; optional `blockingScreenBuilder`.
- Localization integration helpers: `mergeFlutterDefenderSupportedLocales`, optional `blockingLocale` (`Localizations.override`), optional `messageResolver` / `blockingTitleResolver`.
- Example app with locale switching and blocking UI preview.
- `README.md`, `LICENSE` (Apache-2.0), and `.gitignore` coverage for package and example.
- GitHub Actions workflow to run package and example `flutter test` on pull requests and pushes to `main` / `master`.

When you publish the repo, add compare/release links at the bottom of this file (see [Keep a Changelog](https://keepachangelog.com/) footer examples).
