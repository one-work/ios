import HotwireNative
import UIKit

final class RightButtonComponent: BridgeComponent {
  override class var name: String { "right-button" }

  private var viewController: UIViewController? {
    delegate?.destination as? UIViewController
  }

  override func onReceive(message: Message) {
    guard let viewController else { return }
    addButton(via: message, to: viewController)
  }

  private func addButton(via message: Message, to viewController: UIViewController) {
    guard let data: MessageData = message.data() else { return }

    let action = UIAction { [unowned self] _ in
      self.reply(to: "connect")
    }
    let item = UIBarButtonItem(
      title: data.title,
      image: .init(systemName: "ellipsis"),
      primaryAction: action
    )
    viewController.navigationItem.rightBarButtonItem = item
  }
}

private extension RightButtonComponent {
  struct MessageData: Decodable {
    let title: String
  }
}
