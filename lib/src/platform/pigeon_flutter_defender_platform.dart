import '../../flutter_defender_platform_interface.dart';
import 'pigeon/defender_messages.g.dart';

class _DefenderFlutterApiAdapter extends DefenderFlutterApi {
  _DefenderFlutterApiAdapter(this._callbacks);

  final FlutterDefenderPlatformCallbacks _callbacks;

  @override
  void onForegroundStateChanged(bool active) {
    _callbacks.onForegroundStateChanged?.call(active);
  }

  @override
  void onOverlayViolation() {
    _callbacks.onOverlayViolation?.call();
  }

  @override
  void onScreenCaptureChanged(bool active) {
    _callbacks.onScreenCaptureChanged?.call(active);
  }

  @override
  void onScreenshotDetected() {
    _callbacks.onScreenshotDetected?.call();
  }
}

class PigeonFlutterDefenderPlatform extends FlutterDefenderPlatform {
  PigeonFlutterDefenderPlatform({DefenderHostApi? hostApi})
    : _hostApi = hostApi ?? DefenderHostApi();

  final DefenderHostApi _hostApi;

  @override
  Future<void> clearLifecycleSnapshot() {
    return _hostApi.clearLifecycleSnapshot();
  }

  @override
  Future<LifecycleSnapshot> loadLifecycleSnapshot() {
    return _hostApi.loadLifecycleSnapshot();
  }

  @override
  Future<NativeRuntimeState> getRuntimeState() {
    return _hostApi.getRuntimeState();
  }

  @override
  Future<AdvancedSecuritySignals> getAdvancedSecuritySignals() {
    return _hostApi.getAdvancedSecuritySignals();
  }

  @override
  Future<void> secureWrite({required String key, required String value}) {
    return _hostApi.secureWrite(key, value);
  }

  @override
  Future<String?> secureRead(String key) {
    return _hostApi.secureRead(key);
  }

  @override
  Future<void> secureDelete(String key) {
    return _hostApi.secureDelete(key);
  }

  @override
  Future<void> secureClearAll() {
    return _hostApi.secureClearAll();
  }

  @override
  Future<void> saveLifecycleSnapshot(LifecycleSnapshot snapshot) {
    return _hostApi.saveLifecycleSnapshot(snapshot);
  }

  @override
  Future<void> setProtectionState({
    required bool secureActive,
    required bool overlayHardeningActive,
  }) {
    return _hostApi.setProtectionState(secureActive, overlayHardeningActive);
  }

  @override
  void setCallbacks(FlutterDefenderPlatformCallbacks? callbacks) {
    DefenderFlutterApi.setUp(
      callbacks == null ? null : _DefenderFlutterApiAdapter(callbacks),
    );
  }
}
