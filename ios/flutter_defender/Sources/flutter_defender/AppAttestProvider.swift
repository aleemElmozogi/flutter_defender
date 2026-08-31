import DeviceCheck
import Foundation

enum DefenderAttestationError: LocalizedError {
  case unsupported(String)
  case invalidInput(String)
  case missingResult(String)

  var errorDescription: String? {
    switch self {
    case .unsupported(let message), .invalidInput(let message), .missingResult(let message):
      return message
    }
  }
}

final class AppAttestProvider {
  var isSupported: Bool {
    if #available(iOS 14.0, *) {
      return DCAppAttestService.shared.isSupported
    }
    return false
  }

  func generateKey(completion: @escaping (Result<String, Error>) -> Void) {
    guard #available(iOS 14.0, *), DCAppAttestService.shared.isSupported else {
      return complete(
        .failure(DefenderAttestationError.unsupported("App Attest is unavailable on this device.")),
        completion: completion
      )
    }

    DCAppAttestService.shared.generateKey { keyId, error in
      if let error {
        return self.complete(.failure(error), completion: completion)
      }
      guard let keyId else {
        return self.complete(
          .failure(DefenderAttestationError.missingResult("App Attest returned no key identifier.")),
          completion: completion
        )
      }
      guard !keyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return self.complete(
          .failure(DefenderAttestationError.missingResult("App Attest returned an empty key identifier.")),
          completion: completion
        )
      }
      self.complete(.success(keyId), completion: completion)
    }
  }

  func attestKey(
    keyId: String,
    clientDataHash: Data,
    completion: @escaping (Result<Data, Error>) -> Void
  ) {
    guard !keyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return complete(
        .failure(DefenderAttestationError.invalidInput("App Attest key identifier is empty.")),
        completion: completion
      )
    }
    guard clientDataHash.count == 32 else {
      return complete(
        .failure(DefenderAttestationError.invalidInput("App Attest client data hash must contain 32 bytes.")),
        completion: completion
      )
    }
    guard #available(iOS 14.0, *), DCAppAttestService.shared.isSupported else {
      return complete(
        .failure(DefenderAttestationError.unsupported("App Attest is unavailable on this device.")),
        completion: completion
      )
    }

    DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash) {
      attestation,
      error in
      if let error {
        return self.complete(.failure(error), completion: completion)
      }
      guard let attestation else {
        return self.complete(
          .failure(DefenderAttestationError.missingResult("App Attest returned no attestation.")),
          completion: completion
        )
      }
      guard !attestation.isEmpty else {
        return self.complete(
          .failure(DefenderAttestationError.missingResult("App Attest returned an empty attestation.")),
          completion: completion
        )
      }
      self.complete(.success(attestation), completion: completion)
    }
  }

  func generateAssertion(
    keyId: String,
    clientDataHash: Data,
    completion: @escaping (Result<Data, Error>) -> Void
  ) {
    guard !keyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return complete(
        .failure(DefenderAttestationError.invalidInput("App Attest key identifier is empty.")),
        completion: completion
      )
    }
    guard clientDataHash.count == 32 else {
      return complete(
        .failure(DefenderAttestationError.invalidInput("App Attest client data hash must contain 32 bytes.")),
        completion: completion
      )
    }
    guard #available(iOS 14.0, *), DCAppAttestService.shared.isSupported else {
      return complete(
        .failure(DefenderAttestationError.unsupported("App Attest is unavailable on this device.")),
        completion: completion
      )
    }

    DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash) {
      assertion,
      error in
      if let error {
        return self.complete(.failure(error), completion: completion)
      }
      guard let assertion else {
        return self.complete(
          .failure(DefenderAttestationError.missingResult("App Attest returned no assertion.")),
          completion: completion
        )
      }
      guard !assertion.isEmpty else {
        return self.complete(
          .failure(DefenderAttestationError.missingResult("App Attest returned an empty assertion.")),
          completion: completion
        )
      }
      self.complete(.success(assertion), completion: completion)
    }
  }

  private func complete<T>(
    _ result: Result<T, Error>,
    completion: @escaping (Result<T, Error>) -> Void
  ) {
    DispatchQueue.main.async {
      completion(result)
    }
  }
}
