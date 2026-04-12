
# Flutter Plugin Development Guidelines

This document outlines the essential guidelines for creating robust, secure, and maintainable Flutter plugins. It is particularly relevant for security‑sensitive plugins like `flutter_secure_guard`.

## 1. Project Scaffolding & Naming

### Initial Setup
- Create the plugin using the official template:
  ```bash
  flutter create --template=plugin --platforms=android,ios -a kotlin -i swift <plugin_name>
  ```
- Use a unique, descriptive name that follows Dart package naming conventions (lowercase_with_underscores).

### `pubspec.yaml` Essentials
- Provide a concise `description` (max 60 characters for pub.dev summary).
- Specify the `repository` URL for source code and `homepage` for documentation.
- Declare the `license` field (e.g., `Apache-2.0`).

## 2. Architecture & Structure

### Federated Architecture (Recommended for complex plugins)
Separate the plugin into multiple packages:
- `plugin_name_platform_interface` – abstract API definition.
- `plugin_name_android` – Android implementation.
- `plugin_name_ios` – iOS implementation.
- `plugin_name` – umbrella package that combines them.

### File Organization
```
plugin_name/
├── lib/
│   ├── plugin_name.dart          # Main entry point
│   ├── platform_interface/       # Abstract classes
│   └── method_channel_plugin.dart # Default method channel implementation
├── android/
│   ├── src/main/kotlin/          # Kotlin source
│   └── build.gradle
├── ios/
│   ├── Classes/                  # Swift source
│   └── plugin_name.podspec
├── example/                      # Fully functional demo app
├── test/                         # Unit tests
├── integration_test/             # Integration tests
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## 3. Platform Communication

### Use `pigeon` for Type Safety
- Define a `.dart` interface file.
- Run `pigeon` to generate type‑safe, bidirectional code for both Dart and native platforms.
- This eliminates manual `MethodChannel` boilerplate and runtime type errors.

### Asynchronous Calls
- All platform channel interactions are inherently asynchronous.
- Never block the Dart UI thread with long‑running native operations.
- For heavy work, offload to a background thread on the native side or a Dart isolate.

## 4. Testing Strategy

### Unit Tests
- Test Dart‑only logic (parsing, validation, state management).
- Place in `test/` directory.

### Integration Tests
- Test full plugin functionality (Dart + native) using the example app.
- Place in `integration_test/` directory.
- Run on real devices or emulators for platform‑specific features.

### Example App as Test Harness
- The `example/` app must demonstrate **all** plugin features.
- It serves as both documentation and a manual testing ground.

## 5. Documentation

### README.md
Must include:
- **Overview** – what the plugin does and its primary use cases.
- **Installation** – how to add the dependency and any platform‑specific setup (e.g., permissions in `AndroidManifest.xml` or `Info.plist`).
- **Quick Start** – minimal code to initialize and use the plugin.
- **API Reference** – explanation of each public method and configuration option.
- **Platform Notes** – differences between Android and iOS implementations (e.g., overlay detection vs. screen recording detection).
- **Example Code** – link to or embed snippets from the example app.

### API Documentation
- Use `///` comments for all public members.
- Run `dart doc` to generate hosted documentation.

### CHANGELOG.md
- Follow [Keep a Changelog](https://keepachangelog.com/) format.
- Group changes under `## [version] - YYYY-MM-DD`.
- Categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.

## 6. Versioning & Publishing

### Semantic Versioning (SemVer)
- **PATCH** (1.0.x) – backwards‑compatible bug fixes.
- **MINOR** (1.x.0) – new features, still backwards‑compatible.
- **MAJOR** (x.0.0) – breaking API changes.

### Pre‑Publish Checklist
- Run `flutter pub publish --dry-run` – verify no errors or unexpected files.
- Ensure `publish_to: none` is **not** present in `pubspec.yaml`.
- Confirm `LICENSE` file exists (e.g., Apache 2.0, MIT, BSD).

## 7. Security Guidelines (Critical for `flutter_secure_guard`)

### Input Validation
- Always validate and sanitize data received from Dart on the native side to prevent injection attacks.

### Permission Handling
- Check for required permissions before performing sensitive operations.
- Request permissions properly using native APIs and report results back to Dart.
- Do **not** request permissions that are not strictly necessary.

### Logging
- Never log sensitive information (tokens, passwords, PII).
- Use conditional logging that is disabled in release builds.

### Secure Data Storage
- If the plugin stores any data, use platform‑secure storage (Android Keystore, iOS Keychain).

### Emulator / Simulator Detection
- For release builds, detect emulators/simulators and block sensitive operations (or show a warning).

## 8. Tooling & Maintenance

### Code Quality
- Add `flutter_lints` to `dev_dependencies` and follow its recommendations.
- Run `flutter analyze` and fix all warnings before publishing.

### Continuous Integration (CI)
- Use GitHub Actions, Bitrise, or similar to:
    - Run `flutter analyze`
    - Run `flutter test`
    - Run integration tests on Android and iOS emulators.

### Dependency Management
- Regularly run `flutter pub outdated` and update dependencies to get security patches.
- Avoid adding unnecessary dependencies that bloat the plugin.

## 9. Developer Experience (DX)

### Clear Error Messages
- Throw descriptive exceptions (e.g., `PlatformException`) with meaningful error codes and messages.

### Graceful Degradation
- If a feature is not supported on a platform version, return a clear error or `false` instead of crashing.

### Configurability
- Allow developers to opt in/out of features via the `init` method or separate methods.
- Provide sensible defaults that prioritize security but can be relaxed for development.

## 10. Publishing Checklist

Before publishing to `pub.dev`, verify:

- [ ] All tests pass (`flutter test` and `flutter test integration_test`).
- [ ] Example app builds and runs on both Android and iOS.
- [ ] README is up to date and includes setup instructions.
- [ ] CHANGELOG reflects all changes since the last release.
- [ ] Version number is updated in `pubspec.yaml`.
- [ ] `pub publish --dry-run` shows no errors.
- [ ] License file is present.

## 11. Example Plugin: `flutter_secure_guard` Alignment

For a security plugin, these guidelines translate into:

- **Structure** – Federated architecture with separate platform interfaces.
- **Communication** – `pigeon` for type‑safe overlay detection, foreground checks, and screenshot blocking.
- **Testing** – Integration tests that simulate overlays (Android) and screen recording (iOS).
- **Security** – No persistent logging of detection events; emulator blocking in release builds.
- **Documentation** – Clear warnings about platform limitations (e.g., iOS overlay detection is screen‑recording based).

---

*These guidelines are based on official Flutter documentation, community best practices, and OWASP MASVS standards.*

