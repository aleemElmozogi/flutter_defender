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

  Future<pigeon.AdvancedSecuritySignals>
  _safeGetAdvancedSecuritySignals() async {
    try {
      return await _platform.getAdvancedSecuritySignals();
    } catch (_) {
      return pigeon.AdvancedSecuritySignals(
        rootedOrJailbroken: false,
        proxyEnabled: false,
        vpnEnabled: false,
        debuggerAttached: false,
        tamperingDetected: false,
      );
    }
  }

  Future<void> _safeSecureWrite({
    required String key,
    required String value,
  }) async {
    try {
      await _platform.secureWrite(key: key, value: value);
    } catch (_) {
      // Ignore secure storage failures; app decides fallback behavior.
    }
  }

  Future<String?> _safeSecureRead(String key) async {
    try {
      return await _platform.secureRead(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeSecureDelete(String key) async {
    try {
      await _platform.secureDelete(key);
    } catch (_) {
      // Ignore secure storage failures.
    }
  }

  Future<void> _safeSecureClearAll() async {
    try {
      await _platform.secureClearAll();
    } catch (_) {
      // Ignore secure storage failures.
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
