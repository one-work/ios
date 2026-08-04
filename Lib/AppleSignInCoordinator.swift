import AuthenticationServices
import HotwireNative
import Foundation

final class AppleSignInCoordinator: NSObject {
  private let onSuccess: (MessageData) -> Void
  private let onFailure: (String, Bool) -> Void
  private let anchorProvider: () -> ASPresentationAnchor

  init(onSuccess: @escaping (MessageData) -> Void, onFailure: @escaping (String, Bool) -> Void, anchorProvider: @escaping () -> ASPresentationAnchor) {
    self.onSuccess = onSuccess
    self.onFailure = onFailure
    self.anchorProvider = anchorProvider
  }

  func start() {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
  }
}

// NSObject 子类可以正常遵守这两个协议
extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
          let tokenData = credential.identityToken,
          let identityToken = String(data: tokenData, encoding: .utf8) else {
      onFailure("无法获取 identityToken", false)
      return
    }

    var data = MessageData(success: true, identityToken: identityToken, userIdentifier: credential.user)
    // email / fullName 只有首次授权时才返回
    if let email = credential.email { data.email = email }
    if let name = credential.fullName {
      if let given = name.givenName { data.givenName = given }
      if let family = name.familyName { data.familyName = family }
    }
    onSuccess(data)
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    let nsError = error as NSError
    onFailure(error.localizedDescription, nsError.code == ASAuthorizationError.canceled.rawValue)
  }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    anchorProvider()
  }
}

extension AppleSignInCoordinator {
  struct MessageData: Encodable {
    let success: Bool
    let identityToken: String
    let userIdentifier: String
    let email: String?
    let givenName: String?
    let familyName: String?
  }
}
