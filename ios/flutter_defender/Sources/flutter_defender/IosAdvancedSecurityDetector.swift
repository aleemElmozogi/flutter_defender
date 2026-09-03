import CFNetwork
import Darwin
import Foundation
import MachO

final class IosAdvancedSecurityDetector {
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
      key.hasPrefix("tap") || key.hasPrefix("tun") || key.hasPrefix("ppp") || key.hasPrefix("ipsec")
        || key.hasPrefix("utun")
    }
  }

  private func isDebuggerAttached() -> Bool {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    let result = name.withUnsafeMutableBufferPointer { pointer in
      sysctl(pointer.baseAddress, 4, &info, &size, nil, 0)
    }
    if result != 0 {
      return false
    }
    return (info.kp_proc.p_flag & P_TRACED) != 0
  }

  private func isHookingDetected() -> Bool {
    hasSuspiciousDyldEnvironment() || hasSuspiciousRuntimeClass() || hasSuspiciousLoadedImage()
      || hasSuspiciousInstrumentationPath()
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
