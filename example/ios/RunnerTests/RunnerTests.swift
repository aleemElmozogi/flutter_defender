import Flutter
import UIKit
import XCTest

@testable import flutter_defender

final class RunnerTests: XCTestCase {
  func testGetPlatformVersionReturnsExpectedValue() {
    let plugin = makePlugin()
    let result = invoke(plugin, method: "getPlatformVersion")

    XCTAssertEqual(result as? String, "iOS " + UIDevice.current.systemVersion)
  }

  func testIsAppInForegroundUsesInjectedState() {
    let activePlugin = makePlugin(appState: .active)
    let inactivePlugin = makePlugin(appState: .background)

    XCTAssertEqual(invoke(activePlugin, method: "isAppInForeground") as? Bool, true)
    XCTAssertEqual(invoke(inactivePlugin, method: "isAppInForeground") as? Bool, false)
  }

  func testIsEmulatorUsesInjectedProvider() {
    let emulatorPlugin = makePlugin(isEmulator: true)
    let devicePlugin = makePlugin(isEmulator: false)

    XCTAssertEqual(invoke(emulatorPlugin, method: "isEmulator") as? Bool, true)
    XCTAssertEqual(invoke(devicePlugin, method: "isEmulator") as? Bool, false)
  }

  func testIsScreenCapturedUsesInjectedProvider() {
    let capturedPlugin = makePlugin(isScreenCaptured: true)
    let normalPlugin = makePlugin(isScreenCaptured: false)

    XCTAssertEqual(invoke(capturedPlugin, method: "isScreenCaptured") as? Bool, true)
    XCTAssertEqual(invoke(normalPlugin, method: "isScreenCaptured") as? Bool, false)
  }

  func testOverlayDetectionAlwaysReturnsFalseOnIOS() {
    let plugin = makePlugin()

    XCTAssertEqual(invoke(plugin, method: "isOverlayPermissionDetected") as? Bool, false)
  }

  func testScreenshotNotificationInvokesFlutterCallback() {
    let expectation = expectation(description: "screenshot callback")
    let channel = FakeFlutterDefenderChannel {
      expectation.fulfill()
    }
    let notificationCenter = NotificationCenter()
    _ = makePlugin(channel: channel, notificationCenter: notificationCenter)

    notificationCenter.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)

    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(channel.calls.map(\.method), ["onScreenshotAttempted"])
    XCTAssertNil(channel.calls.first?.arguments)
  }

  func testScreenCaptureNotificationInvokesFlutterCallbackWithState() {
    let expectation = expectation(description: "capture callback")
    let channel = FakeFlutterDefenderChannel {
      expectation.fulfill()
    }
    let notificationCenter = NotificationCenter()
    _ = makePlugin(
      channel: channel,
      notificationCenter: notificationCenter,
      isScreenCaptured: true)

    if #available(iOS 11.0, *) {
      notificationCenter.post(name: UIScreen.capturedDidChangeNotification, object: nil)
      wait(for: [expectation], timeout: 1)
      XCTAssertEqual(channel.calls.map(\.method), ["onScreenCaptureChanged"])
      let payload = channel.calls.first?.arguments as? [String: Bool]
      XCTAssertEqual(payload?["active"], true)
    }
  }

  private func makePlugin(
    channel: FakeFlutterDefenderChannel = FakeFlutterDefenderChannel(),
    notificationCenter: NotificationCenter = NotificationCenter(),
    appState: UIApplication.State = .active,
    isScreenCaptured: Bool = false,
    isEmulator: Bool = false
  ) -> FlutterDefenderPlugin {
    FlutterDefenderPlugin(
      channel: channel,
      notificationCenter: notificationCenter,
      appStateProvider: { appState },
      screenCaptureProvider: { isScreenCaptured },
      isEmulatorProvider: { isEmulator }
    )
  }

  private func invoke(_ plugin: FlutterDefenderPlugin, method: String) -> Any? {
    let expectation = expectation(description: method)
    var capturedResult: Any?

    plugin.handle(FlutterMethodCall(methodName: method, arguments: nil)) { result in
      capturedResult = result
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1)
    return capturedResult
  }
}

private final class FakeFlutterDefenderChannel: FlutterDefenderChanneling {
  struct Call {
    let method: String
    let arguments: Any?
  }

  private let onInvoke: (() -> Void)?
  private(set) var calls: [Call] = []

  init(onInvoke: (() -> Void)? = nil) {
    self.onInvoke = onInvoke
  }

  func invokeMethod(_ method: String, arguments: Any?) {
    calls.append(Call(method: method, arguments: arguments))
    onInvoke?()
  }
}
