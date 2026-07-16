import Foundation
import HotwireNative
import UIKit
import WebKit

/// 蓝牙逻辑
final class BluetoothComponent: BridgeComponent {
  override class var name: String { "bluetooth" }
  private let bluetoothManager = BluetoothManager()

  override func onReceive(message: Message) {
    guard let event = Event(rawValue: message.event) else {
      return
    }

    switch event {
    case .display:
      handleDisplayEvent(message: message)
    }
  }

  // MARK: Private
  private var viewController: UIViewController? {
    delegate?.destination as? UIViewController
  }

  private func handleDisplayEvent(message: Message) {
    guard let data: MessageData = message.data() else { return }
    showAlertSheet(with: data.title, items: data.items)
  }

  private func showAlertSheet(with title: String, items: [Item]) {
    let alertController = UIAlertController(
      title: title,
      message: nil,
      preferredStyle: .actionSheet
    )

    for item in items {
      let action = UIAlertAction(title: item.title, style: .default) { [unowned self] _ in
        onItemSelected(item: item)
      }
      alertController.addAction(action)
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
    alertController.addAction(cancelAction)
  }

  private func onItemSelected(item: Item) {
    reply(
      to: Event.display.rawValue,
      with: SelectionMessageData(selectedIndex: item.index)
    )
  }
}

// MARK: Events
private extension BluetoothComponent {
  enum Event: String {
    case display
  }
}

// MARK: Message data
private extension BluetoothComponent {
  struct MessageData: Decodable {
    let title: String
    let items: [Item]

  }
  
  struct Item: Decodable {
    let title: String
    let index: Int
  }
  
  struct SelectionMessageData: Encodable {
    let selectedIndex: Int
  }
}
