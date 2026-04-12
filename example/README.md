# flutter_defender example

This example is a manual verification harness for:
- `FlutterDefenderSensitiveGuard`
- `FlutterDefenderOtpGuard`
- authenticated background timeout via `setAuthenticated(true)`
- custom blocking UI
- release emulator/simulator blocking

## Run

```bash
flutter run
```

## Manual checks

1. Open **Sensitive Screen** and verify Android recents are blanked.
2. Start screen recording or mirroring on iOS and verify the blocking screen appears.
3. Open **OTP Screen**, background the app for more than 10 seconds, and verify only the OTP route is dismissed.
4. Sign in, background the app for more than 20 seconds, and verify logout is requested.
5. Build a **release** on an emulator/simulator and verify guarded screens are blocked.
