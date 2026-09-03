import Foundation
import Security

final class IosSecureStorageHelper {
  private let service = "flutter_defender_secure_store"

  func write(key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw PigeonError(
        code: "storage_encoding_error",
        message: "Failed to encode secure value.",
        details: nil
      )
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
      throw PigeonError(
        code: "storage_write_error",
        message: "Failed to update keychain item.",
        details: Int(updateStatus)
      )
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
      throw PigeonError(
        code: "storage_write_error",
        message: "Failed to write keychain item.",
        details: Int(addStatus)
      )
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
      throw PigeonError(
        code: "storage_read_error",
        message: "Failed to read keychain item.",
        details: Int(status)
      )
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
      throw PigeonError(
        code: "storage_delete_error",
        message: "Failed to delete keychain item.",
        details: Int(status)
      )
    }
  }

  func clearAll() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw PigeonError(
        code: "storage_clear_error",
        message: "Failed to clear keychain items.",
        details: Int(status)
      )
    }
  }
}
