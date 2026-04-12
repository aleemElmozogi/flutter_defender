import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'flutter_defender_localization_support.dart';
import 'flutter_defender_platform_interface.dart';
import 'l10n/flutter_defender_localizations.dart';
import 'src/blocking_screen.dart';
import 'src/flutter_defender_config.dart';
import 'src/flutter_defender_message_id.dart';
import 'src/flutter_defender_messages.dart';
import 'src/flutter_defender_runtime_state.dart';
import 'src/flutter_defender_ui_theme.dart';
import 'src/pigeon/defender_messages.g.dart' as pigeon;

export 'flutter_defender_localization_support.dart';
export 'l10n/flutter_defender_localizations.dart';
export 'src/blocking_screen.dart';
export 'src/flutter_defender_message_id.dart';
export 'src/flutter_defender_messages.dart';
export 'src/flutter_defender_ui_theme.dart';

class _GuardBinding {
  _GuardBinding({
    required this.type,
    required this.popRoute,
  });

  final FlutterDefenderGuardType type;
  final VoidCallback popRoute;
}

class _DefenderNotifier extends ChangeNotifier {
  void emit() {
    notifyListeners();
  }
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
  void debugSetNowProvider(DateTime Function() provider) {
    _nowProvider = provider;
  }

  @visibleForTesting
  void debugResetNowProvider() {
    _nowProvider = DateTime.now;
  }

  Future<void> init({
    int otpBackgroundTimeoutSeconds = 60,
    int pinBackgroundTimeoutSeconds = 120,
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
    final Future<void> future = _performInit(
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
    _initFuture = future;
    return future;
  }

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

    final pigeon.LifecycleSnapshot snapshot = await _safeLoadLifecycleSnapshot();
    final pigeon.NativeRuntimeState runtimeState = await _safeGetRuntimeState();

    _applyRuntimeState(runtimeState);
    _applyColdStartSnapshot(snapshot);

    _runtime.initialized = true;
    _runtime.initInFlight = false;

    await _safeClearLifecycleSnapshot();
    await _syncProtection();
  }

  void setAuthenticated(bool authenticated) {
    _runtime.isAuthenticated = authenticated;
    _runtime.logoutTriggeredForCurrentBackground = false;
    if (!authenticated) {
      _runtime.pausedAtMs = null;
    }
    unawaited(_persistLifecycleSnapshot(lastBackgroundedAtMs: _runtime.pausedAtMs));
  }

  @override
  void addListener(VoidCallback listener) {
    _notifier.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _notifier.removeListener(listener);
  }

  void _notifyListeners() {
    _notifier.emit();
  }

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
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        final int nowMs = _nowProvider().millisecondsSinceEpoch;
        _runtime.pausedAtMs = nowMs;
        _runtime.logoutTriggeredForCurrentBackground = false;
        unawaited(_persistLifecycleSnapshot(lastBackgroundedAtMs: nowMs));
        break;
      case AppLifecycleState.resumed:
        unawaited(_handleAppResumed());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> registerGuard({
    required Object token,
    required FlutterDefenderGuardType type,
    required VoidCallback popRoute,
  }) async {
    await (_initFuture ??
        Future<void>.error(
          StateError(
            'FlutterDefender.init() must complete before guarded screens are used.',
          ),
        ));

    _activeGuards[token] = _GuardBinding(type: type, popRoute: popRoute);
    await _syncProtection();

    if (type == FlutterDefenderGuardType.otp && _runtime.pendingColdStartOtpPop) {
      _runtime.pendingColdStartOtpPop = false;
      _notifyListeners();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final _GuardBinding? binding = _activeGuards[token];
        if (binding != null && binding.type == FlutterDefenderGuardType.otp) {
          binding.popRoute();
        }
      });
    }
  }

  Future<void> unregisterGuard(Object token) async {
    _activeGuards.remove(token);
    if (_activeGuards.isEmpty) {
      _runtime.overlayViolationActive = false;
      _clearBlockingState();
    }
    await _syncProtection();
  }

  Widget buildGuardPlaceholder() {
    return ColoredBox(color: _config.uiTheme.backgroundColor);
  }

  Widget buildBlockingOverlay(BuildContext context) {
    final FlutterDefenderMessageId? messageId = _runtime.blockingMessageId.value;
    if (messageId == null) {
      return const SizedBox.shrink();
    }

    return _wrapBlockingLocalizationScope(
      context,
      Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          AbsorbPointer(
            absorbing: true,
            child: Builder(
              builder: (BuildContext innerContext) {
                final String message = _resolveBlockingMessage(
                  innerContext,
                  messageId,
                );
                final String? explicitTitle =
                    _config.blockingTitleResolver != null
                    ? _resolveBlockingTitle(innerContext)
                    : null;

                return _config.blockingScreenBuilder?.call(message) ??
                    BlockingScreen(
                      title: explicitTitle,
                      message: message,
                      theme: _config.uiTheme,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAppResumed() async {
    final int? pausedAtMs = _runtime.pausedAtMs;
    _runtime.pausedAtMs = null;
    await _safeClearLifecycleSnapshot();

    if (pausedAtMs != null) {
      final int elapsedSeconds =
          (_nowProvider().millisecondsSinceEpoch - pausedAtMs) ~/ 1000;

      if (_currentGuardKind == pigeon.DefenderGuardKind.otp &&
          elapsedSeconds > _config.otpBackgroundTimeoutSeconds) {
        _popLatestOtpGuard();
        await _syncProtection();
        return;
      }

      if (_runtime.isAuthenticated &&
          !_runtime.logoutTriggeredForCurrentBackground &&
          elapsedSeconds > _config.pinBackgroundTimeoutSeconds) {
        _runtime.logoutTriggeredForCurrentBackground = true;
        _config.onLogoutRequested?.call();
      }
    }

    _runtime.overlayViolationActive = false;
    await _syncProtection();
  }

  void _applyColdStartSnapshot(pigeon.LifecycleSnapshot snapshot) {
    final int? backgroundedAtMs = snapshot.lastBackgroundedAtMs;
    if (backgroundedAtMs == null) {
      return;
    }

    final int elapsedSeconds =
        (_nowProvider().millisecondsSinceEpoch - backgroundedAtMs) ~/ 1000;
    final bool wasAuthenticated = snapshot.wasAuthenticated ?? false;
    final pigeon.DefenderGuardKind activeGuardKind =
        snapshot.activeGuardKind ?? pigeon.DefenderGuardKind.none;

    if (wasAuthenticated &&
        elapsedSeconds > _config.pinBackgroundTimeoutSeconds) {
      _config.onLogoutRequested?.call();
    }

    if (activeGuardKind == pigeon.DefenderGuardKind.otp &&
        elapsedSeconds > _config.otpBackgroundTimeoutSeconds) {
      _runtime.pendingColdStartOtpPop = true;
    }
  }

  Future<void> _persistLifecycleSnapshot({
    required int? lastBackgroundedAtMs,
  }) async {
    final pigeon.DefenderGuardKind activeGuardKind = _currentGuardKind;
    final bool shouldClear =
        lastBackgroundedAtMs == null &&
        !_runtime.isAuthenticated &&
        activeGuardKind == pigeon.DefenderGuardKind.none;
    if (shouldClear) {
      await _safeClearLifecycleSnapshot();
      return;
    }
    await _safeSaveLifecycleSnapshot(
      pigeon.LifecycleSnapshot(
        lastBackgroundedAtMs: lastBackgroundedAtMs,
        wasAuthenticated: _runtime.isAuthenticated,
        activeGuardKind: activeGuardKind,
      ),
    );
  }

  Future<void> _syncProtection() async {
    final int generation = ++_syncGeneration;
    _runtime.protectionReady = false;
    _notifyListeners();

    final bool hasGuards = _activeGuards.isNotEmpty;
    await _safeSetProtectionState(
      secureActive: hasGuards,
      overlayHardeningActive: hasGuards,
    );

    final pigeon.NativeRuntimeState runtimeState = await _safeGetRuntimeState();
    if (generation != _syncGeneration) {
      return;
    }

    _applyRuntimeState(runtimeState);

    if (!hasGuards) {
      _clearBlockingState();
      _runtime.protectionReady = true;
      _notifyListeners();
      return;
    }

    _recomputeBlockingState();
    _runtime.protectionReady = true;
    _notifyListeners();
  }

  void _applyRuntimeState(pigeon.NativeRuntimeState runtimeState) {
    _runtime.isForeground = runtimeState.isForeground ?? true;
    _runtime.screenCaptureActive = runtimeState.isScreenCaptured ?? false;
    _runtime.emulatorBlocked =
        kReleaseMode &&
        _config.enableEmulatorDetectionRelease &&
        (runtimeState.isEmulator ?? false);
  }

  void _handleScreenshotDetected() {
    if (_activeGuards.isEmpty || _runtime.hasPersistentBlockingSource) {
      return;
    }
    _showTemporaryBlocking(
      FlutterDefenderMessageId.screenshotsBlocked,
    );
  }

  void _handleScreenCaptureChanged(bool active) {
    _runtime.screenCaptureActive = active;
    _recomputeBlockingState();
    _notifyListeners();
  }

  void _handleOverlayViolation() {
    if (_activeGuards.isEmpty) {
      return;
    }
    _runtime.overlayViolationActive = true;
    _showBlocking(
      FlutterDefenderMessageId.overlaysBlocked,
      DefenderBlockingSource.overlay,
    );
    _notifyListeners();
  }

  void _handleForegroundStateChanged(bool active) {
    _runtime.isForeground = active;
    if (active) {
      _runtime.overlayViolationActive = false;
    }
    _recomputeBlockingState();
    _notifyListeners();
  }

  void _recomputeBlockingState() {
    if (_activeGuards.isEmpty) {
      _clearBlockingState();
      return;
    }

    if (_runtime.emulatorBlocked) {
      _showBlocking(
        FlutterDefenderMessageId.emulatorReleaseBlocked,
        DefenderBlockingSource.emulator,
      );
      return;
    }

    if (_runtime.screenCaptureActive) {
      _showBlocking(
        FlutterDefenderMessageId.screenCaptureBlocked,
        DefenderBlockingSource.screenCapture,
      );
      return;
    }

    if (_config.enableForegroundCheck && !_runtime.isForeground) {
      _showBlocking(
        FlutterDefenderMessageId.foregroundRequired,
        DefenderBlockingSource.foreground,
      );
      return;
    }

    if (_runtime.overlayViolationActive) {
      _showBlocking(
        FlutterDefenderMessageId.overlaysBlocked,
        DefenderBlockingSource.overlay,
      );
      return;
    }

    if (_runtime.hasPersistentBlockingSource) {
      _clearBlockingState();
    }
  }

  void _showBlocking(
    FlutterDefenderMessageId messageId,
    DefenderBlockingSource source,
  ) {
    _runtime.cancelTimers();
    _runtime.blockingSource = source;
    _runtime.blockingMessageId.value = messageId;
  }

  void _showTemporaryBlocking(FlutterDefenderMessageId messageId) {
    if (_runtime.hasPersistentBlockingSource) {
      return;
    }
    _runtime.cancelTimers();
    _runtime.blockingSource = DefenderBlockingSource.screenshot;
    _runtime.blockingMessageId.value = messageId;
    _runtime.temporaryBlockingTimer = Timer(const Duration(seconds: 2), () {
      if (_runtime.blockingSource == DefenderBlockingSource.screenshot) {
        _clearBlockingState();
        _notifyListeners();
      }
    });
  }

  void _clearBlockingState() {
    _runtime.cancelTimers();
    _runtime.blockingSource = null;
    _runtime.blockingMessageId.value = null;
  }

  pigeon.DefenderGuardKind get _currentGuardKind {
    for (final _GuardBinding binding in _activeGuards.values.toList().reversed) {
      if (binding.type == FlutterDefenderGuardType.otp) {
        return pigeon.DefenderGuardKind.otp;
      }
    }
    return _activeGuards.isEmpty
        ? pigeon.DefenderGuardKind.none
        : pigeon.DefenderGuardKind.sensitive;
  }

  void _popLatestOtpGuard() {
    for (final _GuardBinding binding in _activeGuards.values.toList().reversed) {
      if (binding.type == FlutterDefenderGuardType.otp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          binding.popRoute();
        });
        break;
      }
    }
  }

  Widget _wrapBlockingLocalizationScope(
    BuildContext overlayContext,
    Widget child,
  ) {
    final Locale? forced = _config.blockingLocale;
    if (forced == null) {
      return child;
    }
    return Localizations.override(
      context: overlayContext,
      locale: forced,
      delegates: FlutterDefenderLocalizations.localizationsDelegates,
      child: Directionality(
        textDirection: flutterDefenderTextDirectionForLocale(forced),
        child: child,
      ),
    );
  }

  String _resolveBlockingMessage(
    BuildContext context,
    FlutterDefenderMessageId messageId,
  ) {
    final String Function(BuildContext, FlutterDefenderMessageId)? resolver =
        _config.messageResolver;
    if (resolver != null) {
      return resolver(context, messageId);
    }
    return FlutterDefenderMessages.resolved(context, messageId);
  }

  String _resolveBlockingTitle(BuildContext context) {
    final String Function(BuildContext)? resolver =
        _config.blockingTitleResolver;
    if (resolver != null) {
      return resolver(context);
    }
    return FlutterDefenderMessages.blockingTitleFor(context);
  }

  Future<void> _safeSetProtectionState({
    required bool secureActive,
    required bool overlayHardeningActive,
  }) async {
    try {
      await _platform.setProtectionState(
        secureActive: secureActive,
        overlayHardeningActive: overlayHardeningActive,
      );
    } catch (_) {
      // Best-effort native hardening should never crash the host app.
    }
  }

  Future<pigeon.NativeRuntimeState> _safeGetRuntimeState() async {
    try {
      return await _platform.getRuntimeState();
    } catch (_) {
      return pigeon.NativeRuntimeState(
        isForeground: true,
        isScreenCaptured: false,
        isEmulator: false,
        supportsOverlayHardening: false,
      );
    }
  }

  Future<void> _safeSaveLifecycleSnapshot(
    pigeon.LifecycleSnapshot snapshot,
  ) async {
    try {
      await _platform.saveLifecycleSnapshot(snapshot);
    } catch (_) {
      // Ignore persistence failures; runtime behavior stays best-effort.
    }
  }

  Future<pigeon.LifecycleSnapshot> _safeLoadLifecycleSnapshot() async {
    try {
      return await _platform.loadLifecycleSnapshot();
    } catch (_) {
      return pigeon.LifecycleSnapshot(
        lastBackgroundedAtMs: null,
        wasAuthenticated: false,
        activeGuardKind: pigeon.DefenderGuardKind.none,
      );
    }
  }

  Future<void> _safeClearLifecycleSnapshot() async {
    try {
      await _platform.clearLifecycleSnapshot();
    } catch (_) {
      // Ignore persistence failures.
    }
  }
}

abstract class _FlutterDefenderGuardState<T extends StatefulWidget>
    extends State<T> {
  final Object _token = Object();
  bool _registrationReady = false;

  FlutterDefender get defender => FlutterDefender.instance;

  FlutterDefenderGuardType get guardType;

  Widget get guardedChild;

  Future<void> _register() async {
    await defender.registerGuard(
      token: _token,
      type: guardType,
      popRoute: _popCurrentRoute,
    );
    if (mounted) {
      setState(() {
        _registrationReady = true;
      });
    }
  }

  void _popCurrentRoute() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      Navigator.of(context).maybePop();
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_register());
  }

  @override
  void dispose() {
    unawaited(defender.unregisterGuard(_token));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: defender,
      builder: (BuildContext context, Widget? child) {
        final bool showChild =
            _registrationReady && !defender.shouldConcealGuardedContent;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: showChild ? guardedChild : defender.buildGuardPlaceholder(),
            ),
            if (defender.hasBlockingOverlay)
              Positioned.fill(child: defender.buildBlockingOverlay(context)),
          ],
        );
      },
    );
  }
}

class FlutterDefenderSensitiveGuard extends StatefulWidget {
  const FlutterDefenderSensitiveGuard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<FlutterDefenderSensitiveGuard> createState() =>
      _FlutterDefenderSensitiveGuardState();
}

class _FlutterDefenderSensitiveGuardState
    extends _FlutterDefenderGuardState<FlutterDefenderSensitiveGuard> {
  @override
  FlutterDefenderGuardType get guardType => FlutterDefenderGuardType.sensitive;

  @override
  Widget get guardedChild => widget.child;
}

class FlutterDefenderOtpGuard extends StatefulWidget {
  const FlutterDefenderOtpGuard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<FlutterDefenderOtpGuard> createState() =>
      _FlutterDefenderOtpGuardState();
}

class _FlutterDefenderOtpGuardState
    extends _FlutterDefenderGuardState<FlutterDefenderOtpGuard> {
  @override
  FlutterDefenderGuardType get guardType => FlutterDefenderGuardType.otp;

  @override
  Widget get guardedChild => widget.child;
}
