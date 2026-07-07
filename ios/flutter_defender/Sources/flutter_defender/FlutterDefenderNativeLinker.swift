#if SWIFT_PACKAGE
import flutter_defender_native
#else
@_silgen_name("fd_native_is_debugger_attached")
private func fd_native_is_debugger_attached() -> Int32

@_silgen_name("fd_native_is_rooted_or_jailbroken")
private func fd_native_is_rooted_or_jailbroken() -> Int32

@_silgen_name("fd_native_is_emulator")
private func fd_native_is_emulator() -> Int32

@_silgen_name("fd_native_is_tampered")
private func fd_native_is_tampered() -> Int32

@_silgen_name("fd_native_hmac_sha256_hex")
private func fd_native_hmac_sha256_hex(
  _ data: UnsafePointer<UInt8>?,
  _ dataLength: Int32,
  _ key: UnsafePointer<UInt8>?,
  _ keyLength: Int32
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("fd_native_free_string")
private func fd_native_free_string(_ value: UnsafeMutablePointer<CChar>?)
#endif

@_cdecl("fd_is_debugger_attached")
public func flutterDefenderIsDebuggerAttached() -> Int32 {
  fd_native_is_debugger_attached()
}

@_cdecl("fd_is_rooted_or_jailbroken")
public func flutterDefenderIsRootedOrJailbroken() -> Int32 {
  fd_native_is_rooted_or_jailbroken()
}

@_cdecl("fd_is_emulator")
public func flutterDefenderIsEmulator() -> Int32 {
  fd_native_is_emulator()
}

@_cdecl("fd_is_tampered")
public func flutterDefenderIsTampered() -> Int32 {
  fd_native_is_tampered()
}

@_cdecl("fd_hmac_sha256_hex")
public func flutterDefenderHmacSha256Hex(
  _ data: UnsafePointer<UInt8>?,
  _ dataLength: Int32,
  _ key: UnsafePointer<UInt8>?,
  _ keyLength: Int32
) -> UnsafeMutablePointer<CChar>? {
  fd_native_hmac_sha256_hex(data, dataLength, key, keyLength)
}

@_cdecl("fd_free_string")
public func flutterDefenderFreeString(_ value: UnsafeMutablePointer<CChar>?) {
  fd_native_free_string(value)
}

enum FlutterDefenderNativeLinker {
  static func keepLinked() {
    _ = flutterDefenderIsDebuggerAttached()
    _ = flutterDefenderIsRootedOrJailbroken()
    _ = flutterDefenderIsEmulator()
    _ = flutterDefenderIsTampered()
    _ = flutterDefenderHmacSha256Hex(nil, 0, nil, 0)
    flutterDefenderFreeString(nil)
  }
}
