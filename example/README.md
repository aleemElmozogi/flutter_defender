# flutter_defender example

This example is a manual feature lab for the plugin. It demonstrates:
- sensitive screen protection with `FlutterDefenderSensitiveGuard`
- OTP timeout behavior with `FlutterDefenderOtpGuard`
- authenticated background logout via `setAuthenticated(true)`
- custom blocking UI with a defender-owned barrier
- release emulator or simulator blocking on guarded routes

## Run

```bash
flutter run
```

## Run Tests

```bash
./tool/run_tests.sh
```

This script runs:
- `flutter test`
- Android integration test on the first connected emulator/device
- iOS integration test on the first detected iPhone simulator

You can force specific devices:

```bash
ANDROID_DEVICE_ID=emulator-5554 IOS_DEVICE_ID=F3F27306-1C8D-41A5-9268-ACC141C6F0A8 ./tool/run_tests.sh
```

You can skip one platform when needed:

```bash
RUN_ANDROID_INTEGRATION=0 ./tool/run_tests.sh
RUN_IOS_INTEGRATION=0 ./tool/run_tests.sh
```

## What the example includes

- **Feature Lab home screen** with session state, event log, and direct entry points for each flow
- **Sensitive Screen** for Android recents and capture handling checks
- **OTP Screen** for route-scoped timeout validation
- **Authenticated Area** for full logout timeout validation
- **Custom Blocking Screen Demo** to verify that a custom builder still cannot expose the page to taps

## Recommended manual checks

1. Open **Sensitive Screen** and verify Android recents are protected.
2. Take a screenshot or start screen recording or mirroring and verify the plugin response matches the current platform limitations.
3. Open **OTP Screen**, background the app for less than 10 seconds, then repeat for more than 10 seconds and confirm only the OTP route is dismissed.
4. Sign in, open **Authenticated Area**, background for less than 20 seconds, then repeat for more than 20 seconds and confirm logout is requested.
5. Open **Custom Blocking Screen Demo** and verify the underlying route is not tappable while blocked.
6. Build a **release** on an emulator or simulator and verify guarded routes are blocked there while debug remains usable.
