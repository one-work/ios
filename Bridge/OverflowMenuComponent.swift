import Foundation
import HotwireNative
import UIKit

/// 在右上角显示按钮，点击后跳转到指定地址
final class OverflowMenuComponent: BridgeComponent {
  override class var name: String { "overflow-menu" }

  /// 兜底地址：web 消息里没带 url 时使用
  private static let defaultFormURL = URL(string: "https://linlishenghuo.com/bluetooth/menus")!
  private var formURL: URL?
  private var viewController: UIViewController? {
    delegate?.destination as? UIViewController
  }

  override func onReceive(message: Message) {
    guard let event = Event(rawValue: message.event) else {
      return
    }

    switch event {
    case .connect:
      handleConnectEvent(message: message)
    }
  }

  private func handleConnectEvent(message: Message) {
    guard let data: MessageData = message.data() else { return }
    if let urlString = data.url, let url = URL(string: urlString) {
      formURL = url
    }
    showOverflowMenuItem(data)
  }

  private func showOverflowMenuItem(_ data: MessageData) {
    guard let viewController else { return }

    let action = UIAction { [unowned self] _ in
      overflowAction()
    }

    viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: data.label,
      image: .init(systemName: "ellipsis"),
      primaryAction: action
    )
  }

  private func overflowAction() {
    let url = formURL ?? Self.defaultFormURL
    (viewController as? WebViewController)?.navigator?.route(url)
  }
}

// MARK: Events
private extension OverflowMenuComponent {
  enum Event: String {
    case connect
  }
}

// MARK: Message data
private extension OverflowMenuComponent {
  struct MessageData: Decodable {
    let label: String
    let url: String?
  }
}
