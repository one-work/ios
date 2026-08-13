import HotwireNative
import UIKit
import VisionKit

final class ScanComponent: BridgeComponent {
  override class var name: String { "scan" }
  
  private var viewController: UIViewController? {
    delegate?.destination as? UIViewController
  }

  override func onReceive(message: Message) {
    switch message.event {
    case "start":
      presentScanner()
    default:
      break
    }
  }

  private func presentScanner() {
    guard let viewController else { return }

    // 设备不支持（如模拟器）时直接回复空结果
    guard DataScannerViewController.isSupported,
          DataScannerViewController.isAvailable else {
      reply(to: "start", with: #"{"value": null}"#)
      return
    }

    let scanner = DataScannerViewController(
      recognizedDataTypes: [
        .barcode(symbologies: [.qr, .ean13, .ean8, .code128, .code39, .upce, .pdf417])
      ],
      qualityLevel: .balanced,
      recognizesMultipleItems: false,
      isPinchToZoomEnabled: true,
      isHighlightingEnabled: true
    )
    scanner.delegate = self

    viewController.present(scanner, animated: true) {
      try? scanner.startScanning()
    }
  }
}

extension ScanComponent: DataScannerViewControllerDelegate {

  func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
    guard case .barcode(let barcode) = addedItems.first else { return }

    dataScanner.stopScanning()
    let value = barcode.payloadStringValue ?? ""

    dataScanner.dismiss(animated: true) { [weak self] in
      self?.replyWithValue(value)
    }
  }

  private func replyWithValue(_ value: String) {
    // 用 JSONEncoder 防止码值中包含引号导致 JSON 非法
    struct Reply: Encodable { let value: String }
    guard let data = try? JSONEncoder().encode(Reply(value: value)),
          let json = String(data: data, encoding: .utf8) else { return }
    reply(to: "start", with: json)
  }
}
