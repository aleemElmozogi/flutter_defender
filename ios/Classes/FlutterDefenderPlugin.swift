import Flutter
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

  private var screenshotObserver: NSObjectProtocol?
  private var captureObserver: NSObjectProtocol?
  private var didBecomeActiveObserver: NSObjectProtocol?
  private var willResignActiveObserver: NSObjectProtocol?

  init(
    binaryMessenger: FlutterBinaryMessenger,
    notificationCenter: NotificationCenter = .default,
    userDefaults: UserDefaults = .standard,
    appStateProvider: @escaping FlutterDefenderAppStateProvider = {
      UIApplication.shared.applicationState
    },
    screenCaptureProvider: @escaping FlutterDefenderScreenCaptureProvider = {
      if #available(iOS 11.0, *) {
        return UIScreen.main.isCaptured
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
    super.init()
    startObservers()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterDefenderPlugin(binaryMessenger: registrar.messenger())
    DefenderHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  deinit {
    if let screenshotObserver {
      notificationCenter.removeObserver(screenshotObserver)
    }
    if let captureObserver {
      notificationCenter.removeObserver(captureObserver)
    }
    if let didBecomeActiveObserver {
      notificationCenter.removeObserver(didBecomeActiveObserver)
    }
    if let willResignActiveObserver {
      notificationCenter.removeObserver(willResignActiveObserver)
    }
  }

  func setProtectionState(secureActive: Bool, overlayHardeningActive: Bool) throws {}

  func getRuntimeState() throws -> NativeRuntimeState {
    NativeRuntimeState(
      isForeground: appStateProvider() == .active,
      isScreenCaptured: screenCaptureProvider(),
      isEmulator: isEmulatorProvider(),
      supportsOverlayHardening: false
    )
  }

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
    let timestamp = hasTimestamp ? userDefaults.object(forKey: SnapshotKey.lastBackgroundedAtMs) as? Int64 : nil
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
        guard let self else { return }
        self.flutterApi.onScreenCaptureChanged(active: self.screenCaptureProvider()) { _ in }
      }
    }

    didBecomeActiveObserver = notificationCenter.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
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
}
