part of '../../flutter_defender.dart';

extension _FlutterDefenderPolicySync on FlutterDefender {
  Future<void> _requestLogout() async {
    if (_config.enableSecureStorageHelper &&
        _config.clearSecureStorageOnLogout) {
      await _safeSecureClearAll();
    }
    _config.onLogoutRequested?.call();
  }

  Future<void> _handleAppResumed() async {
    final int? pausedAtMs = _runtime.pausedAtMs;
    _runtime.pausedAtMs = null;
    await _safeClearLifecycleSnapshot();

    if (pausedAtMs != null) {
      final int elapsedSeconds =
          (_nowProvider().millisecondsSinceEpoch - pausedAtMs) ~/ 1000;
      if (_currentGuardKind == pigeon.DefenderGuardKind.otp &&
          elapsedSeconds >= _config.otpBackgroundTimeoutSeconds) {
        _popLatestOtpGuard();
        await _syncProtection(concealUntilProtectionReady: false);
        return;
      }
      if (_runtime.isAuthenticated &&
          !_runtime.logoutTriggeredForCurrentBackground &&
          elapsedSeconds >= _config.authenticatedBackgroundTimeoutSeconds) {
        _runtime.logoutTriggeredForCurrentBackground = true;
        await _requestLogout();
      }
    }

    _runtime
      ..overlayViolationActive = false
      ..windowFocusConcealActive = false;
    await _syncProtection(concealUntilProtectionReady: false);
  }

  Future<void> _applyColdStartSnapshot(
    pigeon.LifecycleSnapshot snapshot,
  ) async {
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
        elapsedSeconds >= _config.authenticatedBackgroundTimeoutSeconds) {
      await _requestLogout();
    }
    if (activeGuardKind == pigeon.DefenderGuardKind.otp &&
        elapsedSeconds >= _config.otpBackgroundTimeoutSeconds) {
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

  Future<void> _syncProtection({
    bool concealUntilProtectionReady = true,
  }) async {
    final int generation = ++_syncGeneration;
    final bool hasGuards = _activeGuards.isNotEmpty;
    if (!hasGuards) {
      if (_runtime.nativeProtectionActive) {
        await _safeSetProtectionState(
          secureActive: false,
          overlayHardeningActive: false,
        );
        if (generation != _syncGeneration) {
          return;
        }
        _runtime.nativeProtectionActive = false;
      }
      _runtime
        ..platformUnavailableBlocked = false
        ..windowFocusConcealActive = false
        ..rootBlocked = false
        ..proxyOrVpnBlocked = false
        ..tamperingBlocked = false;
      _clearBlockingState();
      _runtime.protectionReady = true;
      _notifyListeners();
      return;
    }

    final bool needsProtectionWarmup =
        concealUntilProtectionReady && !_runtime.nativeProtectionActive;
    if (needsProtectionWarmup) {
      _runtime.protectionReady = false;
      _notifyListeners();
    }

    final bool protectionStateSucceeded = await _safeSetProtectionState(
      secureActive: hasGuards,
      overlayHardeningActive: hasGuards,
    );
    if (generation != _syncGeneration) {
      return;
    }
    _runtime.nativeProtectionActive = hasGuards && protectionStateSucceeded;

    final bool advancedDetectionEnabled =
        hasGuards &&
        (_config.enableRootDetection ||
            _config.enableProxyVpnDetection ||
            _config.enableRaspDetection);
    final Future<_PlatformResult<pigeon.NativeRuntimeState>>
    runtimeStateFuture = _safeGetRuntimeState();
    final Future<_PlatformResult<pigeon.AdvancedSecuritySignals>?>
    advancedSignalsFuture = advancedDetectionEnabled
        ? _safeGetAdvancedSecuritySignals().then(
            (_PlatformResult<pigeon.AdvancedSecuritySignals> result) => result,
          )
        : Future<_PlatformResult<pigeon.AdvancedSecuritySignals>?>.value();
    final (
      _PlatformResult<pigeon.NativeRuntimeState> runtimeStateResult,
      _PlatformResult<pigeon.AdvancedSecuritySignals>? advancedSignalsResult,
    ) = await (
      runtimeStateFuture,
      advancedSignalsFuture,
    ).wait;
    if (generation != _syncGeneration) {
      return;
    }
    _runtime.platformUnavailableBlocked =
        _config.failClosedOnPlatformError &&
        (!protectionStateSucceeded ||
            !runtimeStateResult.succeeded ||
            advancedSignalsResult?.succeeded == false);
    _applyRuntimeState(runtimeStateResult.value);
    if (advancedSignalsResult != null) {
      _applyAdvancedSecuritySignals(advancedSignalsResult.value);
    } else {
      _runtime
        ..rootBlocked = false
        ..proxyOrVpnBlocked = false
        ..tamperingBlocked = false;
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

  void _applyAdvancedSecuritySignals(pigeon.AdvancedSecuritySignals signals) {
    final bool rootDetected = signals.rootedOrJailbroken ?? false;
    final bool proxyOrVpnDetected =
        (signals.proxyEnabled ?? false) || (signals.vpnEnabled ?? false);
    final bool tamperingDetected =
        (signals.debuggerAttached ?? false) ||
        (signals.tamperingDetected ?? false);

    _runtime.rootBlocked = _config.enableRootDetection && rootDetected;
    _runtime.proxyOrVpnBlocked =
        _config.enableProxyVpnDetection && proxyOrVpnDetected;
    _runtime.tamperingBlocked =
        _config.enableRaspDetection && tamperingDetected;

    if (_runtime.rootBlocked && !_runtime.rootCallbackEmitted) {
      _runtime.rootCallbackEmitted = true;
      _config.onRootDetected?.call();
    } else if (!_runtime.rootBlocked) {
      _runtime.rootCallbackEmitted = false;
    }

    if (_runtime.proxyOrVpnBlocked && !_runtime.proxyVpnCallbackEmitted) {
      _runtime.proxyVpnCallbackEmitted = true;
      _config.onProxyOrVpnDetected?.call();
    } else if (!_runtime.proxyOrVpnBlocked) {
      _runtime.proxyVpnCallbackEmitted = false;
    }

    if (_runtime.tamperingBlocked && !_runtime.tamperingCallbackEmitted) {
      _runtime.tamperingCallbackEmitted = true;
      _config.onTamperingDetected?.call();
    } else if (!_runtime.tamperingBlocked) {
      _runtime.tamperingCallbackEmitted = false;
    }
  }

  void _handleScreenshotDetected() {
    if (_activeGuards.isEmpty || _runtime.hasPersistentBlockingSource) {
      return;
    }
    _showTemporaryBlocking(FlutterDefenderMessageId.screenshotsBlocked);
    _notifyListeners();
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

  /// Focus-only interruptions (for example a biometric prompt window over a
  /// guarded screen) conceal guarded content but never start background
  /// timeouts or the foreground blocking screen; those remain tied to actual
  /// activity pause/resume signals.
  void _handleWindowFocusChanged(bool hasFocus) {
    final bool concealActive = !hasFocus && _activeGuards.isNotEmpty;
    if (_runtime.windowFocusConcealActive == concealActive) {
      return;
    }
    _runtime.windowFocusConcealActive = concealActive;
    _notifyListeners();
  }

  void _handleForegroundStateChanged(bool active) {
    final bool wasForeground = _runtime.isForeground;
    _runtime.isForeground = active;
    if (active) {
      _runtime
        ..overlayViolationActive = false
        ..windowFocusConcealActive = false;
      unawaited(_handleAppResumed());
      return;
    }
    if (wasForeground) {
      final int nowMs = _nowProvider().millisecondsSinceEpoch;
      _runtime
        ..pausedAtMs = nowMs
        ..logoutTriggeredForCurrentBackground = false;
      unawaited(_persistLifecycleSnapshot(lastBackgroundedAtMs: nowMs));
    }
    _recomputeBlockingState();
    _notifyListeners();
  }
}
