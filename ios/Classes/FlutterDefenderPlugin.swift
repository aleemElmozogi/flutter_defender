import Darwin
import Flutter
import Security
import UIKit

private enum SnapshotKey {
  static let lastBackgroundedAtMs = "flutter_defender.last_backgrounded_at_ms"
  static let wasAuthenticated = "flutter_defender.was_authenticated"
  static let activeGuardKind = "flutter_defender.active_guard_kind"
}

typealias FlutterDefenderAppStateProvider = () -> UIApplication.State
typealias FlutterDefenderScreenCaptureProvider = () -> Bool
typealias FlutterDefenderEmulatorProvider = () -> Bool

private final class IosAdvancedSecurityDetector {
  func collectSignals() -> AdvancedSecuritySignals {
    let debuggerAttached = isDebuggerAttached()
    let tamperingDetected = isHookingDetected()
    let details = [debuggerAttached ? "debugger" : nil, tamperingDetected ? "hooking" : nil]
      .compactMap { $0 }
      .joined(separator: ",")

    return AdvancedSecuritySignals(
      rootedOrJailbroken: isJailbroken(),
      proxyEnabled: isProxyEnabled(),
      vpnEnabled: isVpnEnabled(),
      debuggerAttached: debuggerAttached,
      tamperingDetected: tamperingDetected,
      tamperingDetails: details.isEmpty ? nil : details
    )
  }

  private func isJailbroken() -> Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      let suspiciousPaths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/",
        "/private/var/stash",
      ]
      if suspiciousPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
        return true
      }
      if canOpen(path: "/Applications/Cydia.app") {
        return true
      }
      return canWriteOutsideSandbox()
    #endif
  }

  private func canOpen(path: String) -> Bool {
    let file = fopen(path, "r")
    if file != nil {
      fclose(file)
      return true
    }
    return false
  }

  private func canWriteOutsideSandbox() -> Bool {
    let testPath = "/private/flutter_defender_jb_check.txt"
    do {
      try "x".write(toFile: testPath, atomically: true, encoding: .utf8)
      try FileManager.default.removeItem(atPath: testPath)
      return true
    } catch {
      return false
    }
  }

  private func isProxyEnabled() -> Bool {
    guard
      let unmanaged = CFNetworkCopySystemProxySettings(),
      let settings = unmanaged.takeRetainedValue() as? [String: Any]
    else {
      return false
    }
    let http = (settings[kCFNetworkProxiesHTTPEnable as String] as? NSNumber)?.boolValue ?? false
    let https = (settings[kCFNetworkProxiesHTTPSEnable as String] as? NSNumber)?.boolValue ?? false
    return http || https
  }

  private func isVpnEnabled() -> Bool {
    guard
      let unmanaged = CFNetworkCopySystemProxySettings(),
      let settings = unmanaged.takeRetainedValue() as? [String: Any],
      let scoped = settings["__SCOPED__"] as? [String: Any]
    else {
      return false
    }
    return scoped.keys.contains { key in
      key.hasPrefix("tap") || key.hasPrefix("tun") || key.hasPrefix("ppp") || key.hasPrefix("ipsec") || key.hasPrefix("utun")
    }
  }

  private func isDebuggerAttached() -> Bool {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    let result = name.withUnsafeMutableBufferPointer { ptr in
      sysctl(ptr.baseAddress, 4, &info, &size, nil, 0)
    }
    if result != 0 {
      return false
    }
    return (info.kp_proc.p_flag & P_TRACED) != 0
  }

  private func isHookingDetected() -> Bool {
    let suspicious = ["frida", "substrate", "cycript", "xposed", "libhook"]
    for index in 0..<_dyld_image_count() {
      guard let rawName = _dyld_get_image_name(index) else {
        continue
      }
      let image = String(cString: rawName).lowercased()
      if suspicious.contains(where: { image.contains($0) }) {
        return true
      }
    }
    return false
  }
}

private final class IosSecureStorageHelper {
  private let service = "flutter_defender_secure_store"

  func write(key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw FlutterError(code: "storage_encoding_error", message: "Failed to encode secure value.", details: nil)
    }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    let deleteStatus = SecItemDelete(query as CFDictionary)
    if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
      throw FlutterError(code: "storage_delete_error", message: "Failed to delete existing keychain item.", details: deleteStatus)
    }

    let add: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    let addStatus = SecItemAdd(add as CFDictionary, nil)
    if addStatus != errSecSuccess {
      throw FlutterError(code: "storage_write_error", message: "Failed to write keychain item.", details: addStatus)
    }
  }

  func read(key: String) throws -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: kCFBooleanTrue as Any,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess,
          let data = item as? Data
    else {
      throw FlutterError(code: "storage_read_error", message: "Failed to read keychain item.", details: status)
    }
    return String(data: data, encoding: .utf8)
  }

  func delete(key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw FlutterError(code: "storage_delete_error", message: "Failed to delete keychain item.", details: status)
    }
  }

  func clearAll() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw FlutterError(code: "storage_clear_error", message: "Failed to clear keychain items.", details: status)
    }
  }
}

public final class FlutterDefenderPlugin: NSObject, FlutterPlugin, DefenderHostApi {
  private let notificationCenter: NotificationCenter
  private let appStateProvider: FlutterDefenderAppStateProvider
  private let screenCaptureProvider: FlutterDefenderScreenCaptureProvider
  private let isEmulatorProvider: FlutterDefenderEmulatorProvider
  private let userDefaults: UserDefaults
  private let flutterApi: DefenderFlutterApiProtocol
  private let securityDetector: IosAdvancedSecurityDetector
  private let secureStorageHelper: IosSecureStorageHelper
  private let detectorQueue = DispatchQueue(
    label: "flutter_defender.security.detector",
    qos: .utility
  )
  private var advancedSignalsCache = AdvancedSecuritySignals(
    rootedOrJailbroken: false,
    proxyEnabled: false,
    vpnEnabled: false,
    debuggerAttached: false,
    tamperingDetected: false,
    tamperingDetails: nil
  )

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
    self.securityDetector = IosAdvancedSecurityDetector()
    self.secureStorageHelper = IosSecureStorageHelper()
    super.init()
    startObservers()
    scheduleSecurityRefresh()
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

  func setProtectionState(secureActive: Bool, overlayHardeningActive: Bool) throws {
    if secureActive || overlayHardeningActive {
      scheduleSecurityRefresh()
    }
  }

  func getRuntimeState() throws -> NativeRuntimeState {
    NativeRuntimeState(
      isForeground: appStateProvider() == .active,
      isScreenCaptured: screenCaptureProvider(),
      isEmulator: isEmulatorProvider(),
      supportsOverlayHardening: false
    )
  }

  func getAdvancedSecuritySignals() throws -> AdvancedSecuritySignals {
    advancedSignalsCache
  }

  func secureWrite(key: String, value: String) throws {
    try secureStorageHelper.write(key: key, value: value)
  }

  func secureRead(key: String) throws -> String? {
    try secureStorageHelper.read(key: key)
  }

  func secureDelete(key: String) throws {
    try secureStorageHelper.delete(key: key)
  }

  func secureClearAll() throws {
    try secureStorageHelper.clearAll()
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
      self?.scheduleSecurityRefresh()
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

  private func scheduleSecurityRefresh() {
    detectorQueue.async { [weak self] in
      guard let self else { return }
      let signals = self.securityDetector.collectSignals()
      DispatchQueue.main.async { [weak self] in
        self?.advancedSignalsCache = signals
      }
    }
  }
}
