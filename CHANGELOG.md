# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Android trusted system prompts, including biometric authentication, no longer trigger the `foregroundRequired` blocking message when they only take window focus.
- Confirmed obscured-touch violations now retain the `overlaysBlocked` message even if the app also reports a foreground transition.
- Inactive lifecycle transitions no longer start authenticated or OTP background timeouts before the app is actually paused.

### Tests

- Added Android lifecycle tracking and Dart message-priority regressions for trusted system prompts, overlays, and actual background transitions.

## [0.5.0] - 2026-07-07

### Added

- Added `FlutterDefenderSecureContentGuard` for concealing bounded sensitive regions such as cards, panels, and containers without rendering a route-level blocking screen.
- Added `FlutterDefenderConcealmentPlaceholder` and `placeholderBuilder` support so guarded content can show themed replacement UI while concealed.
- Added native iOS secure-surface wiring so the Flutter root view is wrapped in a secure text-entry backed container while guarded content is active through `setProtectionState(secureActive:)`.
- Added iOS Swift Package Manager support while keeping CocoaPods support.
- Added localized `protectedContentHidden` blocking message text for English, Arabic, Spanish, and French.

### Changed

- `FlutterDefenderSensitiveGuard` now replaces concealed content with a `FlutterDefenderUiTheme`-styled placeholder when no explicit blocking overlay is active.
- Guarded children are now hidden behind all active blocking overlays, including custom blocking builders.
- Documentation now clarifies that native screenshot protection is window/root-surface level on Android and iOS, even when using the scoped Dart content guard.
- Documented that `enableRaspDetection` blocks guarded content when a debugger is attached, including during debug tooling sessions where the flag is forced on.
- `enableProxyVpnDetection` and `enableRaspDetection` now default to `false` in every build mode and must be enabled explicitly.
- Kept compatibility with Dart `>=3.10.1 <4.0.0` and Flutter `>=3.35.0`.

### Tests

- Added widget coverage for iOS inactive concealment placeholders and scoped secure-content concealment.
- Verified `flutter analyze`, `flutter test`, and iOS simulator debug build.

## [0.4.0] - 2026-05-24

### Added

- Added a native C++ FFI core for debugger, root/jailbreak, emulator, and hooking-artifact signals.
- Added native HMAC-SHA256 request signing through `FlutterDefenderRequestSigner`.
- Added Android CMake packaging for `libflutter_defender.so`.
- Added iOS Podspec source inclusion for the native C++ core.

### Changed

- RASP signals now merge native C++ checks with the existing platform detector fallback.
- Android native builds no longer pin a specific CMake patch version.

### Tests

- Verified `flutter analyze`, `flutter test`, Android debug APK build, Android release APK build, and the native HMAC-SHA256 test vector.

## [0.3.0] - 2026-05-16

### Added

- Added `ReleaseEmulatorGuardActivity` for Android apps that need non-debuggable release APKs blocked before Flutter starts on emulators.
- Added optional Android manifest metadata for native release-emulator blocker title, subtitle, message, and button text.
- Added package consumer keep rules for the Android release-emulator guard and detector classes, plus R8 warning suppression for annotation-only Tink references from `androidx.security:security-crypto`.
- Documented Android launch-guard setup, Android install-vs-launch enforcement, and iOS simulator release tooling prevention.
- Added iOS screen connect/disconnect observers so capture state is refreshed when mirrored or external screens are attached or removed.
- Added broader iOS jailbreak and runtime-tampering indicators for Frida/Gadget artifacts, injected DYLD environment variables, suspicious runtime classes, and known instrumentation dylibs.

### Changed

- Android release-emulator launch blocking is package-owned; host apps only need a launcher manifest handoff.
- Android guarded-screen overlay hardening now reports `supportsOverlayHardening: false` after `setHideOverlayWindows(...)` is unavailable.
- Android security signal refresh is isolated from detector exceptions and executor shutdown races.
- Android root `su` probing now has a timeout and cleans up its spawned process.
- iOS live capture detection now checks all connected screens instead of only `UIScreen.main`.
- iOS secure-storage writes now update existing Keychain items in place before adding new items.

### Fixed

- Fixed Android plugin registration so `Window.setHideOverlayWindows(...)` `SecurityException`s do not prevent `flutter_defender` registration.
- Fixed Android screenshot callback registration/unregistration so platform callback failures do not crash plugin setup or teardown.
- Fixed stale UI-thread protection updates from applying after an activity detach/rebind.
- Fixed Android release guard target-activity failures to show a native configuration error instead of crashing.
- Fixed iOS secure-storage writes so a failed add cannot remove an existing value first.

### Tests

- Verified `flutter analyze`, `flutter test`, Android release APK build, iOS simulator debug build, and Android release emulator launch blocking.

## [0.2.4] - 2026-05-12

### Fixed

- Fixed `authenticatedBackgroundTimeoutSeconds` and `otpBackgroundTimeoutSeconds` so timeout handling fires at the configured boundary instead of requiring an extra second.
- Fixed Android resume handling so `hidden -> inactive -> resumed` does not overwrite the original background timestamp and prevent authenticated logout or OTP dismissal.
- Fixed native foreground callback timeout handling so Android foreground/focus transitions apply the same background-timeout policy.
- Fixed Android VPN detection to avoid crashing host apps when network-state access is unavailable.

### Tests

- Added regression coverage for authenticated timeout, OTP timeout, Android resume lifecycle ordering, native foreground callbacks, and cold-start timeout behavior.

## [0.2.2] - 2026-04-20

### Added

- Test coverage for hardening behavior:
  - secure storage fail-fast error propagation
  - cold-start authenticated-timeout secure-clear parity
  - concurrent `init()` latest-wins behavior

### Changed

- Update `environment.sdk` constraint to include an upper bound (`>=3.10.1 <4.0.0`).
- `FlutterDefender.init()` is now serialized and deterministic under repeated calls (latest-wins).
- Init lifecycle handling is exception-safe (`initInFlight` reset via `finally`) and observer registration is idempotent.
- Advanced security detections (root/proxy-vpn/rasp) now run asynchronously on native background execution paths and return cached snapshots quickly to Dart.
- Secure storage operations now follow fail-fast semantics for platform failures (write/read/delete/clear).
- Authenticated-timeout logout handling now applies secure-storage clearing consistently across resume-time and cold-start paths.
- Android plugin lifecycle cleanup removed unused mutable context state and tightened detector/cache lifecycle.

### Fixed

- Eliminated silent secure-storage failure paths where operations previously appeared successful despite native errors.
- Removed timeout-behavior drift between cold-start and resume-time authenticated logout flows.

## [0.2.1] - 2026-04-19

### Added

- Optional root/jailbreak detection layer with `enableRootDetection` and `onRootDetected`.
- Optional proxy/VPN detection layer with `enableProxyVpnDetection` and `onProxyOrVpnDetected`.
- Optional basic RASP checks (debugger/hooking) with `enableRaspDetection` and `onTamperingDetected`.
- Optional secure storage helper (`secureWrite`, `secureRead`, `secureDelete`, `secureClearAll`) with `enableSecureStorageHelper`.
- Optional secure-storage lifecycle cleanup via `clearSecureStorageOnLogout`.
- New blocking message IDs and localized strings for root/jailbreak, proxy/VPN, and tampering detections.

### Changed

- Moved the package to explicit guarded screens with `FlutterDefenderSensitiveGuard` and `FlutterDefenderOtpGuard`.
- Replaced the old ad hoc channel API with generated Pigeon messages.
- Reworked Android overlay handling to use window hardening and obscured-touch interception instead of overlay-permission checks.
- Persisted OTP/session background timeout state across process death.
- Rebuilt the example app and README around the new guard-based API.
- Added iOS privacy concealment while guarded routes are inactive, and documented it separately from true overlay protection.
- Expanded the example app into a configuration profile lab for UI customization and policy toggles.
- Added GitHub Actions workflows for PR/main CI, release tag creation on version bumps, and tag-triggered pub.dev publishing.

## [0.2.0] - 2026-04-19

### Added

- `FlutterDefenderSensitiveGuard` for secure guarded routes.
- `FlutterDefenderOtpGuard` for OTP-only timeout popping.
- Pigeon-generated Dart, Kotlin, and Swift platform bridge.
- Native lifecycle snapshot persistence on Android and iOS.
- Full-screen barrier enforcement for all blocking states, including custom builders.

### Changed

- **Breaking:** Removed route-observer based protection and route-name configuration.
- **Breaking:** `FlutterDefender.init` now configures policy only; guarded screens are declared with widgets.
- **Breaking:** Removed the old method-channel query API from the public surface.
- Android now applies overlay hardening instead of checking `Settings.canDrawOverlays`.
- Documentation now explicitly describes iOS screenshot and overlay limitations.

### Fixed

- Closed the first-frame leak where secure-window protection used to apply after navigation.
- Stopped custom blocking builders from accidentally allowing interaction with the guarded UI.
- Ensured background timeout state is enforced after cold launch.
- Fixed guard registration so covered routes stop leaking protection onto later non-guarded screens.
- Fixed guard layout so protected content can be used inside bottom sheets and other unconstrained containers.

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
