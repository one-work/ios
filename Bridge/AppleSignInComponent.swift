import AuthenticationServices
import HotwireNative
import UIKit

final class AppleSignInComponent: BridgeComponent {
  override class var name: String { "apple-sign-in" }

  // 强引用持有 coordinator，保证授权流程期间不被释放
  private lazy var coordinator = AppleSignInCoordinator(
    onSuccess: { [weak self] data in
      self?.reply(to: "signIn", with: data)
    },
    onFailure: { [weak self] error, cancelled in
      let payload = UserData(success: true, cancelled: cancelled, error: error)
      self?.reply(to: "signIn", with: payload)
    },
    anchorProvider: { [weak self] in
      if let vc = self?.delegate?.destination as? UIViewController,
         let window = vc.view.window {
        return window
      }
      return UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
        .first ?? ASPresentationAnchor(frame: .zero)
    }
  )

  override func onReceive(message: Message) {
    guard message.event == "signIn" else { return }
    coordinator.start()
  }
}

private struct UserData: Encodable {
  let success: Bool
  let cancelled: Bool
  let error: String
}
