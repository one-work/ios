import Foundation
import HotwireNative
import UIKit
import WebKit
import CoreBluetooth

/// 蓝牙逻辑
final class BluetoothComponent: BridgeComponent {
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

extension BluetoothComponent : CBCentralManagerDelegate {
  func isEqual(_ object: Any?) -> Bool {
    <#code#>
  }
  
  var hash: Int {
    <#code#>
  }
  
  var superclass: AnyClass? {
    <#code#>
  }
  
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
  
  func isKind(of aClass: AnyClass) -> Bool {
    <#code#>
  }
  
  func isMember(of aClass: AnyClass) -> Bool {
    <#code#>
  }
  
  func conforms(to aProtocol: Protocol) -> Bool {
    <#code#>
  }
  
  func responds(to aSelector: Selector!) -> Bool {
    <#code#>
  }
  
  var description: String {
    <#code#>
  }
  
  func centralManagerDidUpdateState(central: CBCentralManager){
          switch central.state {
          case CBCentralManagerState.poweredOn:
              //扫描周边蓝牙外设.
              //写nil表示扫描所有蓝牙外设，如果传上面的kServiceUUID,那么只能扫描出FFEO这个服务的外设。
              //CBCentralManagerScanOptionAllowDuplicatesKey为true表示允许扫到重名，false表示不扫描重名的。
              self.manager.scanForPeripheralsWithServices(nil, options:[CBCentralManagerScanOptionAllowDuplicatesKey: false])
              print("蓝牙已打开,请扫描外设")
              discoverDevice()
              
          case CBCentralManagerState.Unauthorized:
              print("这个应用程序是无权使用蓝牙低功耗")
          case CBCentralManagerState.PoweredOff:
              print("蓝牙目前已关闭")
          default:
              print("中央管理器没有改变状态")
          }
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
