import Flutter
import UIKit

protocol FlutterDefenderChanneling: AnyObject {
  func invokeMethod(_ method: String, arguments: Any?)
}

extension FlutterMethodChannel: FlutterDefenderChanneling {}

typealias FlutterDefenderAppStateProvider = () -> UIApplication.State
typealias FlutterDefenderScreenCaptureProvider = () -> Bool
typealias FlutterDefenderEmulatorProvider = () -> Bool

public class FlutterDefenderPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterDefenderChanneling
  private let notificationCenter: NotificationCenter
  private let appStateProvider: FlutterDefenderAppStateProvider
  private let screenCaptureProvider: FlutterDefenderScreenCaptureProvider
  private let isEmulatorProvider: FlutterDefenderEmulatorProvider
  private var screenshotObserver: NSObjectProtocol?
  private var captureObserver: NSObjectProtocol?

  init(
    channel: FlutterDefenderChanneling,
    notificationCenter: NotificationCenter = .default,
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
    self.channel = channel
    self.notificationCenter = notificationCenter
    self.appStateProvider = appStateProvider
    self.screenCaptureProvider = screenCaptureProvider
    self.isEmulatorProvider = isEmulatorProvider
    super.init()
    startObservers()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "flutter_defender",
      binaryMessenger: registrar.messenger())
    let instance = FlutterDefenderPlugin(channel: methodChannel)
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "setFlagSecure":
      result(nil)
    case "isOverlayPermissionDetected":
      result(false)
    case "isAppInForeground":
      result(appStateProvider() == .active)
    case "isEmulator":
      result(isEmulatorProvider())
    case "isScreenCaptured":
      result(screenCaptureProvider())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  deinit {
    if let screenshotObserver {
      notificationCenter.removeObserver(screenshotObserver)
    }
    if let captureObserver {
      notificationCenter.removeObserver(captureObserver)
    }
  }

  private func startObservers() {
    screenshotObserver = notificationCenter.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.channel.invokeMethod("onScreenshotAttempted", arguments: nil)
    }

    if #available(iOS 11.0, *) {
      captureObserver = notificationCenter.addObserver(
        forName: UIScreen.capturedDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.channel.invokeMethod(
          "onScreenCaptureChanged",
          arguments: ["active": self?.screenCaptureProvider() ?? false]
        )
      }
    }
  }
}
