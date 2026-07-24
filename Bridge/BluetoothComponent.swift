import HotwireNative
import Foundation

final class BluetoothComponent: BridgeComponent {
  public override class var name: String { "bluetooth" }

  public override func onReceive(message: Message) {
    setupBluetoothManager()

    switch message.event {
    case "connect":
      let address = UserDefaults.standard.string(forKey: "address")
      print("connect address: \(address ?? "nil")")
      reply(to: "connect", with: ConnectStatus(address: address))
    case "search":
      BluetoothManager.shared.startScan()
    case "connect_device":
      handleConnectDevice(message)
    case "send_data":
      handleSendData(message)
    default:
      break
    }
  }

  private func setupBluetoothManager() {
    BluetoothManager.shared.onDeviceFound = {
      [weak self] device in
      guard let self = self else { return }
      let payload = SearchResult(device: device)
      self.reply(to: "search", with: payload)
    }
    BluetoothManager.shared.onConnected = {
      [weak self] success in
      guard let self = self else { return }
      let payload = ConnectResult(success: success)
      self.reply(to: "connect_device", with: payload)
    }
    BluetoothManager.shared.onDataSent = {
      [weak self] result in
      guard let self = self else { return }
      let payload = SendResult(success: result.success, error: result.error)
      self.reply(to: "send_data", with: payload)
    }
  }

  private func handleConnectDevice(_ message: Message) {
    let data: ConnectDeviceData? = message.data()
    guard let address = data?.address else { return }
    UserDefaults.standard.set(address, forKey: "address")
    BluetoothManager.shared.connect(to: address)
  }

  private func handleSendData(_ message: Message) {
    let data: SendData? = message.data()
    guard let text = data?.data else { return }
    BluetoothManager.shared.send(bytes: text)
  }
}

// MARK: - 接收数据模型（Decodable）
private struct ConnectDeviceData: Decodable {
  let address: String
}

private struct SendData: Decodable {
  let address: String
  let data: [UInt8]
}

// MARK: - 发送数据模型（Encodable）
private struct SearchResult: Encodable {
  let device: DeviceInfo
}

private struct ConnectResult: Encodable {
  let success: Bool
}

private struct SendResult: Encodable {
  let success: Bool
  let error: String?
}

private struct ConnectStatus: Encodable {
  let address: String?
}
