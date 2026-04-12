## 0.0.1

* Initial release of `flutter_defender`, a unified security plugin for Flutter designed for banking-style applications.

The plugin provides sensitive-route hardening, platform-level guardrails, and automated UI blocking to prevent unauthorized access or information leakage on Android and iOS.

- **Security Features**:
    - Toggles `FLAG_SECURE` on Android automatically based on route sensitivity.
    - Detects screen overlays, screen recording/mirroring, and screenshot attempts.
    - Implements mandatory foreground checks for sensitive screens.
    - Blocks execution on emulators when running in release mode.
- **Navigation & Lifecycle**:
    - Includes `FlutterDefenderNavigatorObserver` for route-aware security policies.
    - Supports automatic session expiration (logout) or route popping (OTP) after background timeouts.
- **User Interface**:
    - Provides a customizable `BlockingScreen` overlay when security policies are violated.
    - Supports custom UI themes via `FlutterDefenderUiTheme`.
- **Localization**:
    - Built-in multi-language support (English, Arabic, French, Spanish) for security messages.
- **Native Implementation**:
    - Kotlin-based Android plugin using `ActivityAware` and modern screen capture APIs.
    - Swift-based iOS plugin utilizing `UIScreen` and system notifications..
