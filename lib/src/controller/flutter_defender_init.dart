part of '../../flutter_defender.dart';

extension _FlutterDefenderInit on FlutterDefender {
  Future<void> _performInit({
    required int otpBackgroundTimeoutSeconds,
    required int pinBackgroundTimeoutSeconds,
    required bool enableForegroundCheck,
    required bool enableEmulatorDetectionRelease,
    required Widget Function(String message)? blockingScreenBuilder,
    required VoidCallback? onLogoutRequested,
    required FlutterDefenderUiTheme uiTheme,
    required Locale? blockingLocale,
    required String Function(BuildContext context, FlutterDefenderMessageId id)?
    messageResolver,
    required String Function(BuildContext context)? blockingTitleResolver,
  }) async {
    _runtime.initInFlight = true;
    _config = FlutterDefenderConfig.fromInit(
      otpBackgroundTimeoutSeconds: otpBackgroundTimeoutSeconds,
      pinBackgroundTimeoutSeconds: pinBackgroundTimeoutSeconds,
      enableForegroundCheck: enableForegroundCheck,
      enableEmulatorDetectionRelease: enableEmulatorDetectionRelease,
      blockingScreenBuilder: blockingScreenBuilder,
      onLogoutRequested: onLogoutRequested,
      uiTheme: uiTheme,
      blockingLocale: blockingLocale,
      messageResolver: messageResolver,
      blockingTitleResolver: blockingTitleResolver,
    );

    _platform.setCallbacks(
      FlutterDefenderPlatformCallbacks(
        onScreenshotDetected: _handleScreenshotDetected,
        onScreenCaptureChanged: _handleScreenCaptureChanged,
        onOverlayViolation: _handleOverlayViolation,
        onForegroundStateChanged: _handleForegroundStateChanged,
      ),
    );

    if (!_runtime.initialized) {
      WidgetsBinding.instance.addObserver(this);
    }

    final pigeon.LifecycleSnapshot snapshot =
        await _safeLoadLifecycleSnapshot();
    final pigeon.NativeRuntimeState runtimeState = await _safeGetRuntimeState();

    _applyRuntimeState(runtimeState);
    _applyColdStartSnapshot(snapshot);
    _runtime
      ..initialized = true
      ..initInFlight = false;

    await _safeClearLifecycleSnapshot();
    await _syncProtection();
  }
}
