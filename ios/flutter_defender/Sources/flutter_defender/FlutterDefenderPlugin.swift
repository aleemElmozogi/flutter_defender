import Darwin
import Flutter
import MachO
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
        "/Applications/Sileo.app",
        "/Applications/Zebra.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/PreferenceLoader/PreferenceLoader.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/",
        "/private/var/stash",
        "/private/var/jb",
        "/var/jb",
        "/usr/lib/libjailbreak.dylib",
        "/usr/lib/libsubstitute.dylib",
        "/usr/lib/substrate",
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
    let https = (settings["HTTPSEnable"] as? NSNumber)?.boolValue ?? false
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
    hasSuspiciousDyldEnvironment() ||
      hasSuspiciousRuntimeClass() ||
      hasSuspiciousLoadedImage() ||
      hasSuspiciousInstrumentationPath()
  }

  private func hasSuspiciousDyldEnvironment() -> Bool {
    let environment = ProcessInfo.processInfo.environment
    let suspiciousKeys = [
      "DYLD_INSERT_LIBRARIES",
      "DYLD_LIBRARY_PATH",
      "DYLD_FRAMEWORK_PATH",
    ]
    return suspiciousKeys.contains { key in
      environment[key]?.isEmpty == false
    }
  }

  private func hasSuspiciousRuntimeClass() -> Bool {
    let suspiciousClasses = [
      "FridaGadget",
      "FridaScriptEngine",
      "CydiaSubstrate",
      "SubstrateLoader",
      "SubstrateBootstrap",
      "MSHookFunction",
      "CaptainHook",
      "CYListenServer",
    ]
    return suspiciousClasses.contains { NSClassFromString($0) != nil }
  }

  private func hasSuspiciousLoadedImage() -> Bool {
    let suspicious = [
      "frida",
      "gadget",
      "substrate",
      "substitute",
      "libhooker",
      "cycript",
      "sslkill",
      "flex",
      "libcolorpicker",
    ]
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

  private func hasSuspiciousInstrumentationPath() -> Bool {
    let suspiciousPaths = [
      "/usr/sbin/frida-server",
      "/usr/bin/frida-server",
      "/usr/lib/frida/frida-agent.dylib",
      "/usr/lib/frida/frida-gadget.dylib",
      "/Library/MobileSubstrate/DynamicLibraries/FridaGadget.dylib",
      "/Library/MobileSubstrate/DynamicLibraries/SSLKillSwitch2.dylib",
      "/Library/MobileSubstrate/DynamicLibraries/FLEX.dylib",
      "/Library/MobileSubstrate/DynamicLibraries/RevealServer.dylib",
    ]
    return suspiciousPaths.contains { FileManager.default.fileExists(atPath: $0) }
  }
}

private final class IosSecureStorageHelper {
  private let service = "flutter_defender_secure_store"

  func write(key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw PigeonError(code: "storage_encoding_error", message: "Failed to encode secure value.", details: nil)
    }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    let update: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if updateStatus == errSecSuccess {
      return
    }
    if updateStatus != errSecItemNotFound {
      throw PigeonError(code: "storage_write_error", message: "Failed to update keychain item.", details: Int(updateStatus))
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
      throw PigeonError(code: "storage_write_error", message: "Failed to write keychain item.", details: Int(addStatus))
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
      throw PigeonError(code: "storage_read_error", message: "Failed to read keychain item.", details: Int(status))
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
      throw PigeonError(code: "storage_delete_error", message: "Failed to delete keychain item.", details: Int(status))
    }
  }

  func clearAll() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw PigeonError(code: "storage_clear_error", message: "Failed to clear keychain items.", details: Int(status))
    }
  }
}

private final class IosSecureSurfaceTextField: UITextField {
  weak var forwardedView: UIView?

  override var canBecomeFirstResponder: Bool {
    false
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let forwardedView else {
      return nil
    }
    let forwardedPoint = forwardedView.convert(point, from: self)
    return forwardedView.hitTest(forwardedPoint, with: event)
  }
}

private final class IosSecureSurfaceController {
  private let viewProvider: () -> UIView?
  private var secureTextField: IosSecureSurfaceTextField?
  private var pendingEnable = false
  private weak var securedView: UIView?
  private weak var originalSuperview: UIView?
  private var originalIndex = 0
  private var originalFrame = CGRect.zero
  private var originalAutoresizingMask: UIView.AutoresizingMask = []
  private var originalTranslatesAutoresizingMaskIntoConstraints = true

  init(viewProvider: @escaping () -> UIView? = IosSecureSurfaceController.defaultFlutterRootView) {
    self.viewProvider = viewProvider
  }

  func setEnabled(_ enabled: Bool) {
    if Thread.isMainThread {
      if enabled {
        enableOrDefer()
      } else {
        pendingEnable = false
        disable()
      }
      return
    }
    DispatchQueue.main.async { [weak self] in
      self?.setEnabled(enabled)
    }
  }

  /// Re-evaluates protection when the app returns to the foreground. Completes
  /// an enable that had to be deferred during launch, and otherwise rebuilds an
  /// existing secure surface from scratch so a canvas that came up blank at
  /// cold start is recreated rather than left stranded (the white-screen
  /// recovery path).
  func handleDidBecomeActive() {
    if Thread.isMainThread {
      if pendingEnable {
        enableOrDefer()
      } else if secureTextField != nil {
        disable()
        enable()
      }
      return
    }
    DispatchQueue.main.async { [weak self] in
      self?.handleDidBecomeActive()
    }
  }

  /// Engages the secure surface only once the host window is ready. During
  /// launch the reparenting trick can leave a permanently blank surface if the
  /// application state is not yet `.active` or the Flutter root view has no
  /// laid-out bounds, so we defer and complete it from `handleDidBecomeActive`.
  private func enableOrDefer() {
    guard isReadyForSecureSurface() else {
      pendingEnable = true
      return
    }
    pendingEnable = false
    enableOrRefresh()
  }

  private func isReadyForSecureSurface() -> Bool {
    guard UIApplication.shared.applicationState == .active else {
      return false
    }
    guard let view = viewProvider(),
          view.superview != nil,
          view.bounds.width > 0,
          view.bounds.height > 0
    else {
      return false
    }
    return true
  }

  private func enableOrRefresh() {
    if secureTextField == nil {
      enable()
      return
    }
    if !refreshEnabledSurface() {
      disable()
      enable()
    }
  }

  private func enable() {
    guard secureTextField == nil,
          let view = viewProvider(),
          let superview = view.superview
    else {
      return
    }

    let originalIndex = superview.subviews.firstIndex(of: view) ?? superview.subviews.count
    let secureTextField = IosSecureSurfaceTextField(frame: view.frame)
    secureTextField.isSecureTextEntry = true
    secureTextField.borderStyle = .none
    secureTextField.backgroundColor = .clear
    secureTextField.textColor = .clear
    secureTextField.tintColor = .clear
    secureTextField.autocorrectionType = .no
    secureTextField.spellCheckingType = .no
    secureTextField.autocapitalizationType = .none
    secureTextField.translatesAutoresizingMaskIntoConstraints = view.translatesAutoresizingMaskIntoConstraints
    secureTextField.autoresizingMask = view.autoresizingMask

    superview.insertSubview(secureTextField, at: originalIndex)
    secureTextField.layoutIfNeeded()

    guard let secureContainer = secureContainerView(in: secureTextField) else {
      secureTextField.removeFromSuperview()
      return
    }

    self.secureTextField = secureTextField
    self.securedView = view
    self.originalSuperview = superview
    self.originalIndex = originalIndex
    self.originalFrame = view.frame
    self.originalAutoresizingMask = view.autoresizingMask
    self.originalTranslatesAutoresizingMaskIntoConstraints = view.translatesAutoresizingMaskIntoConstraints

    view.removeFromSuperview()
    view.translatesAutoresizingMaskIntoConstraints = true
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.frame = secureContainer.bounds
    secureContainer.clipsToBounds = true
    secureContainer.addSubview(view)
    secureTextField.forwardedView = view
    _ = refreshEnabledSurface()
  }

  private func disable() {
    guard let secureTextField else {
      return
    }

    if let securedView {
      securedView.removeFromSuperview()
      securedView.translatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizingMaskIntoConstraints
      securedView.autoresizingMask = originalAutoresizingMask
      securedView.frame = originalFrame
      if let originalSuperview {
        let restoredIndex = min(originalIndex, originalSuperview.subviews.count)
        originalSuperview.insertSubview(securedView, at: restoredIndex)
      }
    }
    secureTextField.forwardedView = nil
    secureTextField.removeFromSuperview()

    self.secureTextField = nil
    self.securedView = nil
    self.originalSuperview = nil
  }

  private func refreshEnabledSurface() -> Bool {
    guard let secureTextField,
          let securedView,
          let originalSuperview,
          secureTextField.superview != nil,
          let secureContainer = secureContainerView(in: secureTextField)
    else {
      return false
    }

    secureTextField.frame = originalSuperview.bounds
    secureContainer.clipsToBounds = true
    if securedView.superview !== secureContainer {
      securedView.removeFromSuperview()
      secureContainer.addSubview(securedView)
    }
    securedView.translatesAutoresizingMaskIntoConstraints = true
    securedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    securedView.frame = secureContainer.bounds
    secureTextField.forwardedView = securedView
    return true
  }

  private func secureContainerView(in textField: UITextField) -> UIView? {
    textField.layoutIfNeeded()
    return textField.subviews.first { subview in
      let className = String(describing: type(of: subview))
      return className.contains("Canvas") || className.contains("Content")
    } ?? textField.subviews.first
  }

  private static func defaultFlutterRootView() -> UIView? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    return window?.rootViewController?.view ?? window?.subviews.first
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
