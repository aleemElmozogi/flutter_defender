import Flutter
import Foundation
import UIKit

private enum SnapshotKey {
  static let lastBackgroundedAtMs = "flutter_defender.last_backgrounded_at_ms"
  static let wasAuthenticated = "flutter_defender.was_authenticated"
  static let activeGuardKind = "flutter_defender.active_guard_kind"
}

typealias FlutterDefenderAppStateProvider = () -> UIApplication.State
typealias FlutterDefenderScreenCaptureProvider = () -> Bool
typealias FlutterDefenderEmulatorProvider = () -> Bool

public final class FlutterDefenderPlugin: NSObject, FlutterPlugin, DefenderHostApi {
  private let notificationCenter: NotificationCenter
  private let appStateProvider: FlutterDefenderAppStateProvider
  private let screenCaptureProvider: FlutterDefenderScreenCaptureProvider
  private let isEmulatorProvider: FlutterDefenderEmulatorProvider
  private let userDefaults: UserDefaults
  private let flutterApi: DefenderFlutterApiProtocol
  private let securityDetector: IosAdvancedSecurityDetector
  private let appAttestProvider: AppAttestProvider
  private let secureStorageHelper: IosSecureStorageHelper
  private let secureSurfaceController: IosSecureSurfaceController
  private let detectorQueue = DispatchQueue(
    label: "flutter_defender.security.detector",
    qos: .utility
  )
  private let storageQueue = DispatchQueue(
    label: "flutter_defender.secure.storage",
    qos: .utility
  )

  private var screenshotObserver: NSObjectProtocol?
  private var captureObserver: NSObjectProtocol?
  private var screenConnectObserver: NSObjectProtocol?
  private var screenDisconnectObserver: NSObjectProtocol?
  private var didBecomeActiveObserver: NSObjectProtocol?
  private var willResignActiveObserver: NSObjectProtocol?

  // MARK: - Plugin lifecycle

  init(
    binaryMessenger: FlutterBinaryMessenger,
    notificationCenter: NotificationCenter = .default,
    userDefaults: UserDefaults = .standard,
    appStateProvider: @escaping FlutterDefenderAppStateProvider = {
      UIApplication.shared.applicationState
    },
    screenCaptureProvider: @escaping FlutterDefenderScreenCaptureProvider = {
      if #available(iOS 11.0, *) {
        return UIScreen.screens.contains { $0.isCaptured }
      }
      return false
    },
    isEmulatorProvider: @escaping FlutterDefenderEmulatorProvider = {
      #if targetEnvironment(simulator)
        return true
      #else
        return false
      #endif
    }
  ) {
    self.notificationCenter = notificationCenter
    self.userDefaults = userDefaults
    self.appStateProvider = appStateProvider
    self.screenCaptureProvider = screenCaptureProvider
    self.isEmulatorProvider = isEmulatorProvider
    self.flutterApi = DefenderFlutterApi(binaryMessenger: binaryMessenger)
    self.securityDetector = IosAdvancedSecurityDetector()
    self.appAttestProvider = AppAttestProvider()
    self.secureStorageHelper = IosSecureStorageHelper()
    self.secureSurfaceController = IosSecureSurfaceController()
    super.init()
    startObservers()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    FlutterDefenderNativeLinker.keepLinked()
    let instance = FlutterDefenderPlugin(binaryMessenger: registrar.messenger())
    DefenderHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  deinit {
    secureSurfaceController.setEnabled(false)
    if let screenshotObserver {
      notificationCenter.removeObserver(screenshotObserver)
    }
    if let captureObserver {
      notificationCenter.removeObserver(captureObserver)
    }
    if let screenConnectObserver {
      notificationCenter.removeObserver(screenConnectObserver)
    }
    if let screenDisconnectObserver {
      notificationCenter.removeObserver(screenDisconnectObserver)
    }
    if let didBecomeActiveObserver {
      notificationCenter.removeObserver(didBecomeActiveObserver)
    }
    if let willResignActiveObserver {
      notificationCenter.removeObserver(willResignActiveObserver)
    }
  }

  // MARK: - Runtime protection

  func setProtectionState(secureActive: Bool, overlayHardeningActive: Bool) throws {
    secureSurfaceController.setEnabled(secureActive)
  }

  func getRuntimeState() throws -> NativeRuntimeState {
    NativeRuntimeState(
      isForeground: appStateProvider() == .active,
      isScreenCaptured: screenCaptureProvider(),
      isEmulator: isEmulatorProvider(),
      supportsOverlayHardening: false
    )
  }

  func getAdvancedSecuritySignals(
    completion: @escaping (Result<AdvancedSecuritySignals, Error>) -> Void
  ) {
    let detector = securityDetector
    detectorQueue.async {
      let signals = detector.collectSignals()
      DispatchQueue.main.async {
        completion(.success(signals))
      }
    }
  }

  // MARK: - Platform attestation

  func preparePlayIntegrity(
    cloudProjectNumber: Int64,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    completion(
      .failure(
        PigeonError(
          code: "unsupported-platform",
          message: "Play Integrity is only available on Android.",
          details: nil
        )
      )
    )
  }

  func requestPlayIntegrityToken(
    requestHash: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    completion(
      .failure(
        PigeonError(
          code: "unsupported-platform",
          message: "Play Integrity is only available on Android.",
          details: nil
        )
      )
    )
  }

  func isAppAttestSupported() throws -> Bool {
    appAttestProvider.isSupported
  }

  func generateAppAttestKey(completion: @escaping (Result<String, Error>) -> Void) {
    appAttestProvider.generateKey { result in
      self.completeAppAttest(result, completion: completion)
    }
  }

  func attestAppAttestKey(
    keyId: String,
    clientDataHash: FlutterStandardTypedData,
    completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void
  ) {
    appAttestProvider.attestKey(keyId: keyId, clientDataHash: clientDataHash.data) { result in
      self.completeAppAttest(
        result.map { FlutterStandardTypedData(bytes: $0) },
        completion: completion
      )
    }
  }

  func generateAppAttestAssertion(
    keyId: String,
    clientDataHash: FlutterStandardTypedData,
    completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void
  ) {
    appAttestProvider.generateAssertion(
      keyId: keyId,
      clientDataHash: clientDataHash.data
    ) { result in
      self.completeAppAttest(
        result.map { FlutterStandardTypedData(bytes: $0) },
        completion: completion
      )
    }
  }

  private func completeAppAttest<T>(
    _ result: Result<T, Error>,
    completion: @escaping (Result<T, Error>) -> Void
  ) {
    switch result {
    case .success(let value):
      completion(.success(value))
    case .failure(let error):
      let nativeError = error as NSError
      completion(
        .failure(
          PigeonError(
            code: "app-attest",
            message: error.localizedDescription,
            details: "\(nativeError.domain):\(nativeError.code)"
          )
        )
      )
    }
  }

  // MARK: - Secure storage

  func secureWrite(
    key: String,
    value: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    performStorage(completion: completion) { helper in
      try helper.write(key: key, value: value)
    }
  }

  func secureRead(
    key: String,
    completion: @escaping (Result<String?, Error>) -> Void
  ) {
    performStorage(completion: completion) { helper in
      try helper.read(key: key)
    }
  }

  func secureDelete(
    key: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    performStorage(completion: completion) { helper in
      try helper.delete(key: key)
    }
  }

  func secureClearAll(completion: @escaping (Result<Void, Error>) -> Void) {
    performStorage(completion: completion) { helper in
      try helper.clearAll()
    }
  }

  // MARK: - Lifecycle snapshots

  func saveLifecycleSnapshot(snapshot: LifecycleSnapshot) throws {
    if let lastBackgroundedAtMs = snapshot.lastBackgroundedAtMs {
      userDefaults.set(lastBackgroundedAtMs, forKey: SnapshotKey.lastBackgroundedAtMs)
    } else {
      userDefaults.removeObject(forKey: SnapshotKey.lastBackgroundedAtMs)
    }
    userDefaults.set(snapshot.wasAuthenticated ?? false, forKey: SnapshotKey.wasAuthenticated)
    userDefaults.set(
      snapshot.activeGuardKind?.rawValue ?? DefenderGuardKind.none.rawValue,
      forKey: SnapshotKey.activeGuardKind
    )
  }

  func loadLifecycleSnapshot() throws -> LifecycleSnapshot {
    let hasTimestamp = userDefaults.object(forKey: SnapshotKey.lastBackgroundedAtMs) != nil
    let timestamp =
      hasTimestamp
      ? userDefaults.object(forKey: SnapshotKey.lastBackgroundedAtMs) as? Int64
      : nil
    let storedGuardKind = userDefaults.object(forKey: SnapshotKey.activeGuardKind) as? Int

    return LifecycleSnapshot(
      lastBackgroundedAtMs: timestamp,
      wasAuthenticated: userDefaults.bool(forKey: SnapshotKey.wasAuthenticated),
      activeGuardKind: storedGuardKind.flatMap(DefenderGuardKind.init(rawValue:))
    )
  }

  func clearLifecycleSnapshot() throws {
    userDefaults.removeObject(forKey: SnapshotKey.lastBackgroundedAtMs)
    userDefaults.removeObject(forKey: SnapshotKey.wasAuthenticated)
    userDefaults.removeObject(forKey: SnapshotKey.activeGuardKind)
  }

  // MARK: - System observers

  private func startObservers() {
    screenshotObserver = notificationCenter.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.flutterApi.onScreenshotDetected { _ in }
    }

    if #available(iOS 11.0, *) {
      captureObserver = notificationCenter.addObserver(
        forName: UIScreen.capturedDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emitScreenCaptureState()
      }
      screenConnectObserver = notificationCenter.addObserver(
        forName: UIScreen.didConnectNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emitScreenCaptureState()
      }
      screenDisconnectObserver = notificationCenter.addObserver(
        forName: UIScreen.didDisconnectNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emitScreenCaptureState()
      }
    }

    didBecomeActiveObserver = notificationCenter.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.secureSurfaceController.handleDidBecomeActive()
      self?.flutterApi.onForegroundStateChanged(active: true) { _ in }
    }

    willResignActiveObserver = notificationCenter.addObserver(
      forName: UIApplication.willResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.flutterApi.onForegroundStateChanged(active: false) { _ in }
    }
  }

  private func emitScreenCaptureState() {
    flutterApi.onScreenCaptureChanged(active: screenCaptureProvider()) { _ in }
  }

  private func performStorage<T>(
    completion: @escaping (Result<T, Error>) -> Void,
    operation: @escaping (IosSecureStorageHelper) throws -> T
  ) {
    let helper = secureStorageHelper
    storageQueue.async {
      let result = Result { try operation(helper) }
      DispatchQueue.main.async {
        completion(result)
      }
    }
  }
}
