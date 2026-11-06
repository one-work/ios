import HotwireNative
import Foundation
import CoreBluetooth

final class BluetoothComponent: BridgeComponent {
  override class var name: String { "bluetooth" }

  public override func onReceive(message: Message) {
    setupBluetoothManager()

    switch message.event {
    case "connect":
      let address = UserDefaults.standard.string(forKey: "address")
      let name = UserDefaults.standard.string(forKey: "name")
      var state = "disconnected"
      print("connect address: \(address ?? "nil")")

      if let address = address, let uuid = UUID(uuidString: address) {
        let results = BluetoothManager.shared.getConnectedPeripherals(identifiers: [uuid])
        if let result = results.first {
          switch result.state {
          case .connected:
            state = "connected"
          case .connecting:
            state = "connecting"
          case .disconnected:
            state = "disconnected"
          case .disconnecting:
            state = "disconnecting"
          @unknown default:
            state = "unknown"
          }
        }
      }

      reply(to: "connect", with: ConnectStatus(address: address, name: name, state: state))
    case "search":
      BluetoothManager.shared.startScan()
    case "connect_device":
      handleConnectDevice(message)
    case "disconnect_device":
      handleDisconnectDevice(message)
    case "send_data":
      handleSendData(message)
    default:
      break
    }
  }

  private func setupBluetoothManager() {
    BluetoothManager.shared.onReady = {
      [weak self] success in
      guard let self = self else { return }
      let address = UserDefaults.standard.string(forKey: "address")
      let name = UserDefaults.standard.string(forKey: "name")
      let payload = ConnectStatus(address: address, name: name, ready: success)

      self.reply(to: "connect", with: payload)
    }
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
    BluetoothManager.shared.onDisconnected = {
      [weak self] success in
      guard let self = self else { return }
      let payload = ConnectResult(success: success)
      self.reply(to: "disconnect_device", with: payload)
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
    guard let name = data?.name else { return }
    UserDefaults.standard.set(address, forKey: "address")
    UserDefaults.standard.set(name, forKey: "name")
    BluetoothManager.shared.connect(to: address)
  }

  private func handleDisconnectDevice(_ message: Message) {
    let data: DisconnectDeviceData? = message.data()
    guard let address = data?.address else { return }
    UserDefaults.standard.removeObject(forKey: "address")
    UserDefaults.standard.removeObject(forKey: "name")
    BluetoothManager.shared.disconnect(to: address)
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
  let name: String
}

private struct DisconnectDeviceData: Decodable {
  let address: String
}

private struct SendData: Decodable {
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
  let name: String?
  var state: String?
  var ready: Bool?
}
