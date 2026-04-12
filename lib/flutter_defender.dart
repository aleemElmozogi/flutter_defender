import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/blocking_screen.dart';
import 'src/flutter_defender_config.dart';
import 'src/flutter_defender_message_id.dart';
import 'src/flutter_defender_messages.dart';
import 'src/flutter_defender_navigator_observer.dart';
import 'src/flutter_defender_runtime_state.dart';
import 'src/flutter_defender_ui_theme.dart';
import 'flutter_defender_platform_interface.dart';

export 'l10n/flutter_defender_localizations.dart';
export 'src/blocking_screen.dart';
export 'src/flutter_defender_message_id.dart';
export 'src/flutter_defender_messages.dart';
export 'src/flutter_defender_navigator_observer.dart';
export 'src/flutter_defender_ui_theme.dart';

class FlutterDefender with WidgetsBindingObserver {
  FlutterDefender._internal() {
    navigatorObserver.addListener(_handleRouteChanged);
  }

  static final FlutterDefender instance = FlutterDefender._internal();

  factory FlutterDefender() => instance;

  final FlutterDefenderNavigatorObserver navigatorObserver =
      FlutterDefenderNavigatorObserver();
  FlutterDefenderConfig _config = const FlutterDefenderConfig();
  final FlutterDefenderRuntimeState _runtime = FlutterDefenderRuntimeState();

  Future<String?> getPlatformVersion() {
    return FlutterDefenderPlatform.instance.getPlatformVersion();
  }

  Future<void> init({
    required List<String> sensitiveRoutes,
    required String otpRouteName,
    required List<String> authenticatedRoutes,
    int otpBackgroundTimeoutSeconds = 60,
    int pinBackgroundTimeoutSeconds = 120,
    bool enableOverlayDetection = true,
    bool enableForegroundCheck = true,
    bool enableEmulatorDetectionRelease = true,
    Widget Function(String message)? blockingScreenBuilder,
    VoidCallback? onLogoutRequested,
    FlutterDefenderUiTheme uiTheme = FlutterDefenderUiTheme.defaults,
  }) async {
    _config = FlutterDefenderConfig.fromInit(
      sensitiveRoutes: sensitiveRoutes,
      otpRouteName: otpRouteName,
      authenticatedRoutes: authenticatedRoutes,
      otpBackgroundTimeoutSeconds: otpBackgroundTimeoutSeconds,
      pinBackgroundTimeoutSeconds: pinBackgroundTimeoutSeconds,
      enableOverlayDetection: enableOverlayDetection,
      enableForegroundCheck: enableForegroundCheck,
      enableEmulatorDetectionRelease: enableEmulatorDetectionRelease,
      blockingScreenBuilder: blockingScreenBuilder,
      onLogoutRequested: onLogoutRequested,
      uiTheme: uiTheme,
    );

    FlutterDefenderPlatform.instance.setMethodCallHandler(
      _handleNativeCallback,
    );

    if (!_runtime.initialized) {
      WidgetsBinding.instance.addObserver(this);
      _runtime.initialized = true;
    }

    _runtime.screenCaptureActive = await _safeIsScreenCaptured();

    if (kReleaseMode && _config.enableEmulatorDetectionRelease) {
      _runtime.emulatorBlocked = await _safeIsEmulator();
      if (_runtime.emulatorBlocked) {
        _showBlockingOverlay(
          messageId: FlutterDefenderMessageId.emulatorReleaseBlocked,
          source: DefenderBlockingSource.emulator,
        );
      }
    }

    await _refreshRouteProtection();
  }

  void dispose() {
    if (_runtime.initialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _runtime.reset();
    navigatorObserver.reset();
    FlutterDefenderPlatform.instance.setMethodCallHandler(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_runtime.initialized) {
      return;
    }
    switch (state) {
      case AppLifecycleState.paused:
        _runtime.pausedAt = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        unawaited(_handleAppResumed());
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onScreenshotAttempted':
        if (_runtime.isRouteSensitive) {
          _showTemporaryBlockingOverlay(
            messageId: FlutterDefenderMessageId.screenshotsBlocked,
          );
        }
        break;
      case 'onScreenCaptureChanged':
        _runtime.screenCaptureActive = _parseScreenCaptureState(call.arguments);
        await _reevaluateBlockingState();
        break;
      default:
        break;
    }
  }

  void _handleRouteChanged() {
    if (!_runtime.initialized || _runtime.isRouteRefreshScheduled) {
      return;
    }
    _runtime.isRouteRefreshScheduled = true;
    scheduleMicrotask(() async {
      _runtime.isRouteRefreshScheduled = false;
      await _refreshRouteProtection();
    });
  }

  Future<void> _handleAppResumed() async {
    final DateTime? pausedAt = _runtime.pausedAt;
    _runtime.pausedAt = null;
    final String? routeName = navigatorObserver.currentRouteName;
    if (pausedAt != null && routeName != null) {
      final int elapsedSeconds = DateTime.now().difference(pausedAt).inSeconds;
      if (routeName == _config.otpRouteName &&
          elapsedSeconds > _config.otpBackgroundTimeoutSeconds) {
        final NavigatorState? currentNavigator =
            navigatorObserver.preferredNavigatorState;
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        }
        await _refreshRouteProtection();
        return;
      }
      if (_config.authenticatedRouteSet.contains(routeName) &&
          elapsedSeconds > _config.pinBackgroundTimeoutSeconds) {
        _config.onLogoutRequested?.call();
      }
    }
    await _refreshRouteProtection();
  }

  Future<void> _refreshRouteProtection() async {
    final String? routeName = navigatorObserver.currentRouteName;
    _runtime.isRouteSensitive =
        routeName != null && _config.sensitiveRouteSet.contains(routeName);

    await _setFlagSecure(_runtime.isRouteSensitive);
    _syncOverlayMonitoring();

    if (_runtime.isRouteSensitive) {
      await _reevaluateBlockingState();
    } else if (_runtime.hasPersistentBlockingSource) {
      _clearBlockingOverlay();
    }
  }

  void _syncOverlayMonitoring() {
    _runtime.overlayMonitorTimer?.cancel();
    if (!_config.enableOverlayDetection ||
        !_runtime.isRouteSensitive ||
        _runtime.emulatorBlocked) {
      _runtime.overlayMonitorTimer = null;
      return;
    }
    _runtime.overlayMonitorTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_checkOverlayViolation()),
    );
  }

  Future<void> _checkOverlayViolation() async {
    if (!_runtime.isRouteSensitive) {
      return;
    }
    final bool overlayDetected = await _safeIsOverlayPermissionDetected();
    if (overlayDetected) {
      _showBlockingOverlay(
        messageId: FlutterDefenderMessageId.overlaysBlocked,
        source: DefenderBlockingSource.overlay,
      );
      return;
    }
    if (_runtime.blockingSource == DefenderBlockingSource.overlay) {
      await _reevaluateBlockingState();
    }
  }

  Future<void> _reevaluateBlockingState() async {
    if (_runtime.emulatorBlocked) {
      _showBlockingOverlay(
        messageId: FlutterDefenderMessageId.emulatorReleaseBlocked,
        source: DefenderBlockingSource.emulator,
      );
      return;
    }

    if (!_runtime.isRouteSensitive) {
      if (_runtime.hasPersistentBlockingSource) {
        _clearBlockingOverlay();
      }
      return;
    }

    if (_config.enableOverlayDetection) {
      final bool overlayDetected = await _safeIsOverlayPermissionDetected();
      if (overlayDetected) {
        _showBlockingOverlay(
          messageId: FlutterDefenderMessageId.overlaysBlocked,
          source: DefenderBlockingSource.overlay,
        );
        return;
      }
    }

    _runtime.screenCaptureActive = await _safeIsScreenCaptured();
    if (_runtime.screenCaptureActive) {
      _showBlockingOverlay(
        messageId: FlutterDefenderMessageId.screenCaptureBlocked,
        source: DefenderBlockingSource.screenCapture,
      );
      return;
    }

    if (_config.enableForegroundCheck) {
      final bool isForeground = await _safeIsAppInForeground();
      if (!isForeground) {
        _showBlockingOverlay(
          messageId: FlutterDefenderMessageId.foregroundRequired,
          source: DefenderBlockingSource.foreground,
        );
        return;
      }
    }

    if (_runtime.hasPersistentBlockingSource) {
      _clearBlockingOverlay();
    }
  }

  void _showBlockingOverlay({
    required FlutterDefenderMessageId messageId,
    required DefenderBlockingSource source,
  }) {
    _runtime.temporaryBlockingTimer?.cancel();
    _runtime.blockingSource = source;
    _runtime.blockingMessageId.value = messageId;
    _ensureBlockingOverlay();
  }

  void _showTemporaryBlockingOverlay({
    required FlutterDefenderMessageId messageId,
  }) {
    if (_runtime.blockingSource != null &&
        _runtime.blockingSource != DefenderBlockingSource.screenshot) {
      return;
    }
    _runtime.blockingSource = DefenderBlockingSource.screenshot;
    _runtime.blockingMessageId.value = messageId;
    _ensureBlockingOverlay();
    _runtime.temporaryBlockingTimer?.cancel();
    _runtime.temporaryBlockingTimer = Timer(const Duration(seconds: 2), () {
      if (_runtime.blockingSource == DefenderBlockingSource.screenshot) {
        _clearBlockingOverlay();
      }
    });
  }

  void _ensureBlockingOverlay() {
    if (_runtime.blockingEntry != null) {
      return;
    }
    final NavigatorState? rootNavigator = navigatorObserver.rootNavigatorState;
    final OverlayState? overlayState =
        rootNavigator?.overlay ??
        navigatorObserver.currentNavigatorState?.overlay;
    if (overlayState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_runtime.blockingSource != null) {
          _ensureBlockingOverlay();
        }
      });
      return;
    }
    _runtime.blockingEntry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned.fill(
          child: ValueListenableBuilder<FlutterDefenderMessageId?>(
            valueListenable: _runtime.blockingMessageId,
            builder:
                (
                  BuildContext context,
                  FlutterDefenderMessageId? messageId,
                  Widget? child,
                ) {
                  if (messageId == null) {
                    return const SizedBox.shrink();
                  }
                  final String message =
                      FlutterDefenderMessages.resolved(context, messageId);
                  return _config.blockingScreenBuilder?.call(message) ??
                      BlockingScreen(
                        message: message,
                        theme: _config.uiTheme,
                      );
                },
          ),
        );
      },
    );
    overlayState.insert(_runtime.blockingEntry!);
  }

  void _clearBlockingOverlay() {
    if (_runtime.emulatorBlocked) {
      return;
    }
    _runtime.temporaryBlockingTimer?.cancel();
    _runtime.temporaryBlockingTimer = null;
    _runtime.resetBlockingState();
  }

  Future<void> _setFlagSecure(bool enabled) async {
    try {
      await FlutterDefenderPlatform.instance.setFlagSecure(enabled);
    } catch (_) {
      // Native support is best-effort and should not crash the app.
    }
  }

  Future<bool> _safeIsOverlayPermissionDetected() async {
    try {
      return await FlutterDefenderPlatform.instance
          .isOverlayPermissionDetected();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safeIsAppInForeground() async {
    try {
      return await FlutterDefenderPlatform.instance.isAppInForeground();
    } catch (_) {
      return true;
    }
  }

  Future<bool> _safeIsEmulator() async {
    try {
      return await FlutterDefenderPlatform.instance.isEmulator();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safeIsScreenCaptured() async {
    try {
      return await FlutterDefenderPlatform.instance.isScreenCaptured();
    } catch (_) {
      return false;
    }
  }

  bool _parseScreenCaptureState(Object? arguments) {
    return switch (arguments) {
      final Map<Object?, Object?> map =>
        map['active'] as bool? ?? _runtime.screenCaptureActive,
      final bool value => value,
      _ => _runtime.screenCaptureActive,
    };
  }
}
