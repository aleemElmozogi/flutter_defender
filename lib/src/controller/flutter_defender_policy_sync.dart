part of '../../flutter_defender.dart';

extension _FlutterDefenderPolicySync on FlutterDefender {
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
    _showTemporaryBlocking(FlutterDefenderMessageId.screenshotsBlocked);
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
}
