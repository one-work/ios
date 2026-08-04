// AppleSignInComponent.swift
import AuthenticationServices
import HotwireNative
import UIKit

final class AppleSignInComponent: BridgeComponent {
  override class var name: String { "apple-sign-in" }

  override func onReceive(message: Message) {
    guard message.event == "signIn" else { return }
    startSignInWithAppleFlow()
  }

  private func startSignInWithAppleFlow() {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
  }

  private func replyError(_ description: String, cancelled: Bool = false) {
    let payload = ErrData(success: false, cancelled: cancelled, error: description)
    reply(to: "signIn", with: payload)
  }
}

// MARK: - 授权回调
extension AppleSignInComponent: ASAuthorizationControllerDelegate {

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
          let tokenData = credential.identityToken,
          let identityToken = String(data: tokenData, encoding: .utf8) else {
      replyError("无法获取 identityToken")
      return
    }

    var payload = UserData(success: true, identityToken: identityToken, userIdentifier: credential.user)
    // email / fullName 只有首次授权时才返回
    if let email = credential.email { payload.email = email }
    if let name = credential.fullName {
      if let given = name.givenName { payload.givenName = given }
      if let family = name.familyName { payload.familyName = family }
    }

    reply(to: "signIn", with: payload)
  }
  
  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    let nsError = error as NSError
    let cancelled = nsError.code == ASAuthorizationError.canceled.rawValue
    replyError(error.localizedDescription, cancelled: cancelled)
  }
}

// MARK: - 授权窗口锚点
extension AppleSignInComponent: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    if let vc = delegate?.destination as? UIViewController, let window = vc.view.window {
      return window
    }
    let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first { $0.isKeyWindow } }.first
    return window ?? ASPresentationAnchor(frame: .zero)
  }
}

// MARK: Events
private extension FormComponent {
  enum Event: String {
    case connect
    case submitEnabled
    case submitDisabled
  }
}

// MARK: Message data
private extension AppleSignInComponent {
  struct UserData: Encodable {
    let success: Bool
    let identityToken: String
    let userIdentifier: String
    let email: String?
    let givenName: String?
    let familyName: String?
  }
  
  struct ErrData: Encodable {
    let success: Bool
    let cancelled: Bool
    let error: String
  }
}
