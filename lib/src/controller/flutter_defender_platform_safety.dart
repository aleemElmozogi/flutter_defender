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
    final bool nativeEmulatorDetected = FlutterDefenderNative.instance
        .detectEmulator();
    try {
      final pigeon.NativeRuntimeState runtimeState = await _platform
          .getRuntimeState();
      return pigeon.NativeRuntimeState(
        isForeground: runtimeState.isForeground,
        isScreenCaptured: runtimeState.isScreenCaptured,
        isEmulator:
            (runtimeState.isEmulator ?? false) || nativeEmulatorDetected,
        supportsOverlayHardening: runtimeState.supportsOverlayHardening,
      );
    } catch (_) {
      return pigeon.NativeRuntimeState(
        isForeground: true,
        isScreenCaptured: false,
        isEmulator: nativeEmulatorDetected,
        supportsOverlayHardening: false,
      );
    }
  }

  Future<pigeon.AdvancedSecuritySignals>
  _safeGetAdvancedSecuritySignals() async {
    final NativeDefenderSignals nativeSignals = FlutterDefenderNative.instance
        .collectSignals();
    try {
      final pigeon.AdvancedSecuritySignals signals = await _platform
          .getAdvancedSecuritySignals();
      return _mergeNativeSecuritySignals(signals, nativeSignals);
    } catch (_) {
      return pigeon.AdvancedSecuritySignals(
        rootedOrJailbroken: nativeSignals.rootedOrJailbroken,
        proxyEnabled: false,
        vpnEnabled: false,
        debuggerAttached: nativeSignals.debuggerAttached,
        tamperingDetected: nativeSignals.tamperingDetected,
        tamperingDetails: _nativeTamperingDetails(nativeSignals),
      );
    }
  }

  pigeon.AdvancedSecuritySignals _mergeNativeSecuritySignals(
    pigeon.AdvancedSecuritySignals signals,
    NativeDefenderSignals nativeSignals,
  ) {
    return pigeon.AdvancedSecuritySignals(
      rootedOrJailbroken:
          (signals.rootedOrJailbroken ?? false) ||
          nativeSignals.rootedOrJailbroken,
      proxyEnabled: signals.proxyEnabled,
      vpnEnabled: signals.vpnEnabled,
      debuggerAttached:
          (signals.debuggerAttached ?? false) || nativeSignals.debuggerAttached,
      tamperingDetected:
          (signals.tamperingDetected ?? false) ||
          nativeSignals.tamperingDetected,
      tamperingDetails: _mergeTamperingDetails(
        signals.tamperingDetails,
        _nativeTamperingDetails(nativeSignals),
      ),
    );
  }

  String? _nativeTamperingDetails(NativeDefenderSignals nativeSignals) {
    final List<String> details = <String>[];
    if (nativeSignals.debuggerAttached) {
      details.add('native-debugger');
    }
    if (nativeSignals.tamperingDetected) {
      details.add('native-tampering');
    }
    if (nativeSignals.rootedOrJailbroken) {
      details.add('native-root-jailbreak');
    }
    return details.isEmpty ? null : details.join(',');
  }

  String? _mergeTamperingDetails(
    String? platformDetails,
    String? nativeDetails,
  ) {
    final Set<String> details = <String>{
      ...?platformDetails?.split(',').where((String value) => value.isNotEmpty),
      ...?nativeDetails?.split(',').where((String value) => value.isNotEmpty),
    };
    return details.isEmpty ? null : details.join(',');
  }

  Future<void> _safeSecureWrite({
    required String key,
    required String value,
  }) async {
    await _platform.secureWrite(key: key, value: value);
  }

  Future<String?> _safeSecureRead(String key) async {
    return _platform.secureRead(key);
  }

  Future<void> _safeSecureDelete(String key) async {
    await _platform.secureDelete(key);
  }

  Future<void> _safeSecureClearAll() async {
    await _platform.secureClearAll();
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
