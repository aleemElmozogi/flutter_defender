part of '../../flutter_defender.dart';

NativeDefenderSignals _collectNativeSignals() =>
    FlutterDefenderNative.instance.collectSignals();

typedef _PlatformResult<T> = ({T value, bool succeeded});

extension _FlutterDefenderPlatformSafety on FlutterDefender {
  Future<bool> _safeSetProtectionState({
    required bool secureActive,
    required bool overlayHardeningActive,
  }) async {
    try {
      await _platform.setProtectionState(
        secureActive: secureActive,
        overlayHardeningActive: overlayHardeningActive,
      );
      return true;
    } catch (_) {
      // Best-effort native hardening should never crash the host app.
      return false;
    }
  }

  Future<_PlatformResult<pigeon.NativeRuntimeState>>
  _safeGetRuntimeState() async {
    final bool nativeEmulatorDetected = FlutterDefenderNative.instance
        .detectEmulator();
    try {
      final pigeon.NativeRuntimeState runtimeState = await _platform
          .getRuntimeState();
      return (
        value: pigeon.NativeRuntimeState(
          isForeground: runtimeState.isForeground,
          isScreenCaptured: runtimeState.isScreenCaptured,
          isEmulator:
              (runtimeState.isEmulator ?? false) || nativeEmulatorDetected,
          supportsOverlayHardening: runtimeState.supportsOverlayHardening,
        ),
        succeeded: true,
      );
    } catch (_) {
      return (
        value: pigeon.NativeRuntimeState(
          isForeground: true,
          isScreenCaptured: false,
          isEmulator: nativeEmulatorDetected,
          supportsOverlayHardening: false,
        ),
        succeeded: false,
      );
    }
  }

  Future<_PlatformResult<pigeon.AdvancedSecuritySignals>>
  _safeGetAdvancedSecuritySignals() async {
    final Future<NativeDefenderSignals> nativeSignalsFuture =
        Isolate.run<NativeDefenderSignals>(_collectNativeSignals).onError(
          (Object _, StackTrace _) => const NativeDefenderSignals.unavailable(),
        );
    final Future<_PlatformResult<pigeon.AdvancedSecuritySignals?>>
    platformSignalsFuture = _platform
        .getAdvancedSecuritySignals()
        .then<_PlatformResult<pigeon.AdvancedSecuritySignals?>>(
          (pigeon.AdvancedSecuritySignals signals) =>
              (value: signals, succeeded: true),
        )
        .onError((Object _, StackTrace _) => (value: null, succeeded: false));
    final (
      NativeDefenderSignals nativeSignals,
      _PlatformResult<pigeon.AdvancedSecuritySignals?> platformResult,
    ) = await (
      nativeSignalsFuture,
      platformSignalsFuture,
    ).wait;

    final pigeon.AdvancedSecuritySignals? platformSignals =
        platformResult.value;
    if (platformSignals != null) {
      return (
        value: _mergeNativeSecuritySignals(platformSignals, nativeSignals),
        succeeded: platformResult.succeeded,
      );
    }
    return (
      value: pigeon.AdvancedSecuritySignals(
        rootedOrJailbroken: nativeSignals.rootedOrJailbroken,
        proxyEnabled: false,
        vpnEnabled: false,
        debuggerAttached: nativeSignals.debuggerAttached,
        tamperingDetected: nativeSignals.tamperingDetected,
        tamperingDetails: _nativeTamperingDetails(nativeSignals),
      ),
      succeeded: platformResult.succeeded,
    );
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
