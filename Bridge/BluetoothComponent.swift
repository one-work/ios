import HotwireNative
import Foundation

final class BluetoothComponent: BridgeComponent {
  public override class var name: String { "bluetooth" }
  private var bluetoothManager: BluetoothManager!

  public override func onReceive(message: Message) {
    switch message.event {
    case "connect":
      setupBluetoothManager()
      bluetoothManager.initialize()
      reply(to: "connect")
    case "search":
      setupBluetoothManager()
      bluetoothManager.startScan()
    case "connect_device":
      handleConnectDevice(message)
    case "send_data":
      handleSendData(message)
    default:
      break
    }
  }

  private func setupBluetoothManager() {
    guard bluetoothManager == nil else { return }
    
    let manager = BluetoothManager()
    manager.onDevicesFound = { [weak self] devices in
      guard let self = self else { return }
      // 使用 Codable 结构体
      let payload = SearchResult(devices: devices)
      self.reply(to: "search", with: payload)
    }

    manager.onConnected = { [weak self] success in
      guard let self = self else { return }
      let payload = ConnectResult(success: success)
      self.reply(to: "connect_device", with: payload)
    }

    manager.onDataSent = { [weak self] result in
      guard let self = self else { return }
      let payload = SendResult(success: result.success, error: result.error)
      self.reply(to: "send_data", with: payload)
    }

    self.bluetoothManager = manager
  }
  
  private func handleConnectDevice(_ message: Message) {
    let data: ConnectDeviceData? = message.data()
    guard let address = data?.address else { return }
    setupBluetoothManager()
    bluetoothManager.connect(to: address)
  }
  
  private func handleSendData(_ message: Message) {
    let data: SendData? = message.data()
    guard let text = data?.data else { return }
    setupBluetoothManager()
    bluetoothManager.send(data: text)
  }
}

// MARK: - 接收数据模型（Decodable）
private struct ConnectDeviceData: Decodable {
  let address: String
}

private struct SendData: Decodable {
  let address: String
  let data: String
}

// MARK: - 发送数据模型（Encodable）
private struct SearchResult: Encodable {
  let devices: [DeviceInfo]
}

private struct ConnectResult: Encodable {
  let success: Bool
}

private struct SendResult: Encodable {
  let success: Bool
  let error: String?
}
