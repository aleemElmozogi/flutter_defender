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
    Widget Function(String message)? blockingScreenBuilder,
    VoidCallback? onLogoutRequested,
    FlutterDefenderUiTheme uiTheme = FlutterDefenderUiTheme.defaults,
    Locale? blockingLocale,
    String Function(BuildContext context, FlutterDefenderMessageId id)?
    messageResolver,
    String Function(BuildContext context)? blockingTitleResolver,
  }) {
    final int resolvedAuthenticatedBackgroundTimeoutSeconds =
        pinBackgroundTimeoutSeconds ?? authenticatedBackgroundTimeoutSeconds;
    final Future<void> future = _performInit(
      otpBackgroundTimeoutSeconds: otpBackgroundTimeoutSeconds,
      authenticatedBackgroundTimeoutSeconds:
          resolvedAuthenticatedBackgroundTimeoutSeconds,
      enableForegroundCheck: enableForegroundCheck,
      enableEmulatorDetectionRelease: enableEmulatorDetectionRelease,
      blockingScreenBuilder: blockingScreenBuilder,
      onLogoutRequested: onLogoutRequested,
      uiTheme: uiTheme,
      blockingLocale: blockingLocale,
      messageResolver: messageResolver,
      blockingTitleResolver: blockingTitleResolver,
    );
    _initFuture = future;
    return future;
  }

  void setAuthenticated(bool authenticated) {
    _runtime
      ..isAuthenticated = authenticated
      ..logoutTriggeredForCurrentBackground = false;
    if (!authenticated) {
      _runtime.pausedAtMs = null;
    }
    unawaited(
      _persistLifecycleSnapshot(lastBackgroundedAtMs: _runtime.pausedAtMs),
    );
  }

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);

  void dispose() {
    if (_runtime.initialized) {
      WidgetsBinding.instance.removeObserver(this);
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
