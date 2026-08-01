import Foundation
import HotwireNative
import UIKit

/// Bridge component to display a native 3-dot menu in the toolbar,
/// which will notify the web when it has been tapped.
final class OverflowMenuComponent: BridgeComponent {
  override class var name: String { "overflow-menu" }
  
  /// 兜底地址：web 消息里没带 url 时使用
  private static let defaultFormURL = URL(string: "https://linlishenghuo.com/bluetooth/menus")!
  private var formURL: URL?

  override func onReceive(message: Message) {
    guard let event = Event(rawValue: message.event) else {
      return
    }

    switch event {
    case .connect:
      handleConnectEvent(message: message)
    }
  }

  // MARK: Private
  private var viewController: UIViewController? {
    delegate?.destination as? UIViewController
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
