import Foundation
import HotwireNative
import UIKit
import WebKit
import CoreBluetooth

/// 蓝牙逻辑
final class BluetoothComponent: BridgeComponent, CBCentralManagerDelegate {
  func isKind(of aClass: AnyClass) -> Bool {
    <#code#>
  }
  
  func isMember(of aClass: AnyClass) -> Bool {
    <#code#>
  }
  
  func conforms(to aProtocol: Protocol) -> Bool {
    <#code#>
  }
  
  
  @MainActor required init(destination: any BridgeDestination, delegate: any BridgingDelegate) {
    fatalError("init(destination:delegate:) has not been implemented")
  }
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    <#code#>
  }
  
  func isEqual(_ object: Any?) -> Bool {
    <#code#>
  }
  
  let hash: Int
  
  let superclass: AnyClass?
  
  func `self`() -> Self {
    <#code#>
  }
  
  func perform(_ aSelector: Selector!) -> Unmanaged<AnyObject>! {
    <#code#>
  }
  
  func perform(_ aSelector: Selector!, with object: Any!) -> Unmanaged<AnyObject>! {
    <#code#>
  }
  
  func perform(_ aSelector: Selector!, with object1: Any!, with object2: Any!) -> Unmanaged<AnyObject>! {
    <#code#>
  }
  
  func isProxy() -> Bool {
    <#code#>
  }
  
  
  func responds(to aSelector: Selector!) -> Bool {
    <#code#>
  }
  
  let description: String
  
  override class var name: String { "bluetooth" }

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
    showAlertSheet(with: data.title, items: data.items, source: data.source)
  }

  private func showAlertSheet(with title: String, items: [Item], source: Source) {
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
    
    // Set popoverController for devices that support them (iPad, iOS 26+)
    if let popoverController = alertController.popoverPresentationController,
       let vc = viewController as? Visitable,
       let sourceView = viewController?.view,
       let webView = vc.visitableView.webView
    {
      popoverController.sourceView = sourceView
      
      // The source coordinates come from the bridge component relative to the web page content.
      // The web view's scroll view has content insets for the navigation bar,
      // so we need to account for the inset at the top.
      let contentInsetTop = webView.scrollView.adjustedContentInset.top
      let y = source.y + Double(contentInsetTop)

      popoverController.sourceRect = CGRect(
        x: source.x, y: y, width: source.width, height: source.height
      )
    }
    
    viewController?.present(alertController, animated: true)
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
  struct Source: Decodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
  }
  
  struct MessageData: Decodable {
    let title: String
    let items: [Item]
    let source: Source
  }
  
  struct Item: Decodable {
    let title: String
    let index: Int
  }
  
  struct SelectionMessageData: Encodable {
    let selectedIndex: Int
  }
}
