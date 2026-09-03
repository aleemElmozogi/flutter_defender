import UIKit

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

final class IosSecureSurfaceController {
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
  /// cold start is recreated rather than left stranded.
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

  /// Engages the secure surface only once the host window is ready. Reparenting
  /// during launch can leave a blank surface, so activation is deferred until
  /// the application and Flutter root view are ready.
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
    secureTextField.translatesAutoresizingMaskIntoConstraints =
      view.translatesAutoresizingMaskIntoConstraints
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
    self.originalTranslatesAutoresizingMaskIntoConstraints =
      view.translatesAutoresizingMaskIntoConstraints

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
      securedView.translatesAutoresizingMaskIntoConstraints =
        originalTranslatesAutoresizingMaskIntoConstraints
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
