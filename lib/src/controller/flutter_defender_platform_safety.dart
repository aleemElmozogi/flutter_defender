part of '../../flutter_defender.dart';

extension _FlutterDefenderPlatformSafety on FlutterDefender {
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
