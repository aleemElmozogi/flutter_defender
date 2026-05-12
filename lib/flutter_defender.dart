import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'flutter_defender_localization_support.dart';
import 'flutter_defender_platform_interface.dart';
import 'l10n/flutter_defender_localizations.dart';
import 'src/core/flutter_defender_config.dart';
import 'src/core/flutter_defender_runtime_state.dart';
import 'src/platform/pigeon/defender_messages.g.dart' as pigeon;
import 'src/ui/blocking_screen.dart';
import 'src/ui/flutter_defender_message_id.dart';
import 'src/ui/flutter_defender_messages.dart';
import 'src/ui/flutter_defender_ui_theme.dart';

export 'flutter_defender_localization_support.dart';
export 'l10n/flutter_defender_localizations.dart';
export 'src/ui/blocking_screen.dart';
export 'src/ui/flutter_defender_message_id.dart';
export 'src/ui/flutter_defender_messages.dart';
export 'src/ui/flutter_defender_ui_theme.dart';

part 'src/ui/flutter_defender_blocking_ui.dart';
part 'src/controller/flutter_defender_guard_management.dart';
part 'src/ui/flutter_defender_guard_widgets.dart';
part 'src/controller/flutter_defender_init.dart';
part 'src/controller/flutter_defender_platform_safety.dart';
part 'src/controller/flutter_defender_policy_blocking.dart';
part 'src/controller/flutter_defender_policy_sync.dart';

class _GuardBinding {
  _GuardBinding({required this.type, required this.popRoute});

  final FlutterDefenderGuardType type;
  final VoidCallback popRoute;
}

class _DefenderNotifier extends ChangeNotifier {
  void emit() => notifyListeners();
}

class _PendingInitRequest {
  _PendingInitRequest({
    required this.otpBackgroundTimeoutSeconds,
    required this.authenticatedBackgroundTimeoutSeconds,
    required this.enableForegroundCheck,
    required this.enableEmulatorDetectionRelease,
    required this.enableRootDetection,
    required this.enableProxyVpnDetection,
    required this.enableRaspDetection,
    required this.enableSecureStorageHelper,
    required this.clearSecureStorageOnLogout,
    required this.blockingScreenBuilder,
    required this.onLogoutRequested,
    required this.onRootDetected,
    required this.onProxyOrVpnDetected,
    required this.onTamperingDetected,
    required this.uiTheme,
    required this.blockingLocale,
    required this.messageResolver,
    required this.blockingTitleResolver,
  });

  final int otpBackgroundTimeoutSeconds;
  final int authenticatedBackgroundTimeoutSeconds;
  final bool enableForegroundCheck;
  final bool enableEmulatorDetectionRelease;
  final bool enableRootDetection;
  final bool enableProxyVpnDetection;
  final bool enableRaspDetection;
  final bool enableSecureStorageHelper;
  final bool clearSecureStorageOnLogout;
  final Widget Function(String message)? blockingScreenBuilder;
  final VoidCallback? onLogoutRequested;
  final VoidCallback? onRootDetected;
  final VoidCallback? onProxyOrVpnDetected;
  final VoidCallback? onTamperingDetected;
  final FlutterDefenderUiTheme uiTheme;
  final Locale? blockingLocale;
  final String Function(BuildContext context, FlutterDefenderMessageId id)?
  messageResolver;
  final String Function(BuildContext context)? blockingTitleResolver;
}

class FlutterDefender with WidgetsBindingObserver implements Listenable {
  FlutterDefender._internal();

  static final FlutterDefender instance = FlutterDefender._internal();

  factory FlutterDefender() => instance;

  final FlutterDefenderRuntimeState _runtime = FlutterDefenderRuntimeState();
  final LinkedHashMap<Object, _GuardBinding> _activeGuards =
      LinkedHashMap<Object, _GuardBinding>();
  final _DefenderNotifier _notifier = _DefenderNotifier();

  FlutterDefenderConfig _config = const FlutterDefenderConfig();
  Future<void>? _initFuture;
  Future<void>? _initDrainFuture;
  _PendingInitRequest? _pendingInitRequest;
  bool _observerRegistered = false;
  int _syncGeneration = 0;
  DateTime Function() _nowProvider = DateTime.now;

  FlutterDefenderPlatform get _platform => FlutterDefenderPlatform.instance;

  bool get hasBlockingOverlay =>
      _activeGuards.isNotEmpty && _runtime.blockingMessageId.value != null;

  bool get shouldConcealGuardedContent => _runtime.shouldConcealGuardedContent;

  @visibleForTesting
  void debugSetNowProvider(DateTime Function() provider) =>
      _nowProvider = provider;

  @visibleForTesting
  void debugResetNowProvider() => _nowProvider = DateTime.now;

  Future<void> init({
    int otpBackgroundTimeoutSeconds = 60,
    int authenticatedBackgroundTimeoutSeconds = 120,
    @Deprecated(
      'Use authenticatedBackgroundTimeoutSeconds instead. '
      'This timeout applies to the authenticated session, not a specific PIN page.',
    )
    int? pinBackgroundTimeoutSeconds,
    bool enableForegroundCheck = true,
    bool enableEmulatorDetectionRelease = true,
    bool? enableRootDetection,
    bool? enableProxyVpnDetection,
    bool? enableRaspDetection,
    bool enableSecureStorageHelper = false,
    bool clearSecureStorageOnLogout = false,
    Widget Function(String message)? blockingScreenBuilder,
    VoidCallback? onLogoutRequested,
    VoidCallback? onRootDetected,
    VoidCallback? onProxyOrVpnDetected,
    VoidCallback? onTamperingDetected,
    FlutterDefenderUiTheme uiTheme = FlutterDefenderUiTheme.defaults,
    Locale? blockingLocale,
    String Function(BuildContext context, FlutterDefenderMessageId id)?
    messageResolver,
    String Function(BuildContext context)? blockingTitleResolver,
  }) {
    final int resolvedAuthenticatedBackgroundTimeoutSeconds =
        pinBackgroundTimeoutSeconds ?? authenticatedBackgroundTimeoutSeconds;
    final bool releaseEnabledByDefault = kReleaseMode;
    _pendingInitRequest = _PendingInitRequest(
      otpBackgroundTimeoutSeconds: otpBackgroundTimeoutSeconds,
      authenticatedBackgroundTimeoutSeconds:
          resolvedAuthenticatedBackgroundTimeoutSeconds,
      enableForegroundCheck: enableForegroundCheck,
      enableEmulatorDetectionRelease: enableEmulatorDetectionRelease,
      enableRootDetection: enableRootDetection ?? releaseEnabledByDefault,
      enableProxyVpnDetection:
          enableProxyVpnDetection ?? releaseEnabledByDefault,
      enableRaspDetection: enableRaspDetection ?? releaseEnabledByDefault,
      enableSecureStorageHelper: enableSecureStorageHelper,
      clearSecureStorageOnLogout: clearSecureStorageOnLogout,
      blockingScreenBuilder: blockingScreenBuilder,
      onLogoutRequested: onLogoutRequested,
      onRootDetected: onRootDetected,
      onProxyOrVpnDetected: onProxyOrVpnDetected,
      onTamperingDetected: onTamperingDetected,
      uiTheme: uiTheme,
      blockingLocale: blockingLocale,
      messageResolver: messageResolver,
      blockingTitleResolver: blockingTitleResolver,
    );

    final Future<void> future = _scheduleInitDrain();
    _initFuture = future;
    return future;
  }

  Future<void> _scheduleInitDrain() {
    return _initDrainFuture ??= _drainInitQueue();
  }

  Future<void> _drainInitQueue() async {
    try {
      while (_pendingInitRequest != null) {
        final _PendingInitRequest request = _pendingInitRequest!;
        _pendingInitRequest = null;
        await _performInit(
          otpBackgroundTimeoutSeconds: request.otpBackgroundTimeoutSeconds,
          authenticatedBackgroundTimeoutSeconds:
              request.authenticatedBackgroundTimeoutSeconds,
          enableForegroundCheck: request.enableForegroundCheck,
          enableEmulatorDetectionRelease:
              request.enableEmulatorDetectionRelease,
          enableRootDetection: request.enableRootDetection,
          enableProxyVpnDetection: request.enableProxyVpnDetection,
          enableRaspDetection: request.enableRaspDetection,
          enableSecureStorageHelper: request.enableSecureStorageHelper,
          clearSecureStorageOnLogout: request.clearSecureStorageOnLogout,
          blockingScreenBuilder: request.blockingScreenBuilder,
          onLogoutRequested: request.onLogoutRequested,
          onRootDetected: request.onRootDetected,
          onProxyOrVpnDetected: request.onProxyOrVpnDetected,
          onTamperingDetected: request.onTamperingDetected,
          uiTheme: request.uiTheme,
          blockingLocale: request.blockingLocale,
          messageResolver: request.messageResolver,
          blockingTitleResolver: request.blockingTitleResolver,
        );
      }
    } finally {
      _initDrainFuture = null;
      if (_pendingInitRequest != null) {
        _initFuture = _scheduleInitDrain();
      }
    }
  }

  void setAuthenticated(bool authenticated) {
    _runtime
      ..isAuthenticated = authenticated
      ..logoutTriggeredForCurrentBackground = false;
    if (!authenticated) {
      _runtime.pausedAtMs = null;
      if (_config.enableSecureStorageHelper &&
          _config.clearSecureStorageOnLogout) {
        unawaited(
          _safeSecureClearAll().catchError((Object _, StackTrace _) {
            // Keep setter signature synchronous; fail-fast semantics are enforced
            // in async timeout/logout paths and direct storage API calls.
          }),
        );
      }
    }
    unawaited(
      _persistLifecycleSnapshot(lastBackgroundedAtMs: _runtime.pausedAtMs),
    );
  }

  Future<void> secureWrite({required String key, required String value}) async {
    if (!_config.enableSecureStorageHelper) {
      throw StateError(
        'Secure storage helper is disabled. Enable it with '
        'enableSecureStorageHelper: true in FlutterDefender.init().',
      );
    }
    await _safeSecureWrite(key: key, value: value);
  }

  Future<String?> secureRead(String key) async {
    if (!_config.enableSecureStorageHelper) {
      throw StateError(
        'Secure storage helper is disabled. Enable it with '
        'enableSecureStorageHelper: true in FlutterDefender.init().',
      );
    }
    return _safeSecureRead(key);
  }

  Future<void> secureDelete(String key) async {
    if (!_config.enableSecureStorageHelper) {
      throw StateError(
        'Secure storage helper is disabled. Enable it with '
        'enableSecureStorageHelper: true in FlutterDefender.init().',
      );
    }
    await _safeSecureDelete(key);
  }

  Future<void> secureClearAll() async {
    if (!_config.enableSecureStorageHelper) {
      throw StateError(
        'Secure storage helper is disabled. Enable it with '
        'enableSecureStorageHelper: true in FlutterDefender.init().',
      );
    }
    await _safeSecureClearAll();
  }

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);

  void dispose() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
    _platform.setCallbacks(null);
    _activeGuards.clear();
    unawaited(
      _platform.setProtectionState(
        secureActive: false,
        overlayHardeningActive: false,
      ),
    );
    unawaited(_safeClearLifecycleSnapshot());
    _runtime.reset();
    _initFuture = null;
    _initDrainFuture = null;
    _pendingInitRequest = null;
    _nowProvider = DateTime.now;
    _notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_runtime.initialized) {
      return;
    }
    switch (state) {
      case AppLifecycleState.inactive:
        _setInactivePrivacyShield(active: _shouldShieldOnInactive);
        final int nowMs = _nowProvider().millisecondsSinceEpoch;
        _runtime
          ..pausedAtMs = nowMs
          ..logoutTriggeredForCurrentBackground = false;
        unawaited(_persistLifecycleSnapshot(lastBackgroundedAtMs: nowMs));
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _setInactivePrivacyShield(active: false);
        final int nowMs = _nowProvider().millisecondsSinceEpoch;
        _runtime
          ..pausedAtMs = nowMs
          ..logoutTriggeredForCurrentBackground = false;
        unawaited(_persistLifecycleSnapshot(lastBackgroundedAtMs: nowMs));
        break;
      case AppLifecycleState.resumed:
        _setInactivePrivacyShield(active: false);
        unawaited(_handleAppResumed());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  bool get _shouldShieldOnInactive =>
      defaultTargetPlatform == TargetPlatform.iOS;

  void _setInactivePrivacyShield({required bool active}) {
    if (_runtime.inactivePrivacyShieldActive == active) {
      return;
    }
    _runtime.inactivePrivacyShieldActive = active;
    _notifyListeners();
  }

  void _notifyListeners() => _notifier.emit();
}
