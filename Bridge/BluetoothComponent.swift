import HotwireNative
import XCPrinterBluetooth
import Foundation
import CoreBluetooth

final class BluetoothComponent: BridgeComponent {
  override class var name: String { "bluetooth" }

  private let bluetoothManager = BluetoothManager()
  private var readyTask: Task<Void, Never>?
  private var disconnectionTask: Task<Void, Never>?
  private var scanTask: Task<Void, Never>?

  deinit {
    readyTask?.cancel()
    disconnectionTask?.cancel()
    scanTask?.cancel()
  }

  public override func onReceive(message: Message) {
    observeBluetoothEvents()

    switch message.event {
    case "connect":
      handleConnect()
    case "search":
      handleSearch()
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

  private func observeBluetoothEvents() {
    if readyTask == nil {
      readyTask = Task { @MainActor [weak self] in
        guard let events = self?.bluetoothManager.readyEvents else { return }
        for await ready in events {
          let address = UserDefaults.standard.string(forKey: "address")
          let name = UserDefaults.standard.string(forKey: "name")
          let payload = ConnectStatus(address: address, name: name, ready: ready)
          self?.reply(to: "connect", with: payload, completion: nil)
        }
      }
    }

    if disconnectionTask == nil {
      disconnectionTask = Task { @MainActor [weak self] in
        guard let events = self?.bluetoothManager.disconnectionEvents else { return }
        for await disconnected in events {
          let payload = ConnectResult(success: disconnected)
          self?.reply(to: "disconnect_device", with: payload, completion: nil)
        }
      }
    }
  }

  private func handleConnect() {
    Task { @MainActor [weak self] in
      guard let self = self else { return }
      let address = UserDefaults.standard.string(forKey: "address")
      let name = UserDefaults.standard.string(forKey: "name")
      var state = "disconnected"
      print("connect address: \(address ?? "nil")")

      if let address = address, let uuid = UUID(uuidString: address) {
        let results = await bluetoothManager.getConnectedPeripherals(identifiers: [uuid])
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

      reply(to: "connect", with: ConnectStatus(address: address, name: name, state: state), completion: nil)
    }
  }

  private func handleSearch() {
    scanTask?.cancel()
    scanTask = Task { @MainActor [weak self] in
      guard let devices = self?.bluetoothManager.scan() else { return }
      for await device in devices {
        let payload = SearchResult(device: device)
        self?.reply(to: "search", with: payload, completion: nil)
      }
    }
  }

  private func handleConnectDevice(_ message: Message) {
    let data: ConnectDeviceData? = message.data()
    guard let address = data?.address else { return }
    guard let name = data?.name else { return }
    UserDefaults.standard.set(address, forKey: "address")
    UserDefaults.standard.set(name, forKey: "name")

    Task { @MainActor [weak self] in
      guard let manager = self?.bluetoothManager else { return }
      let success = await manager.connect(to: address)
      let payload = ConnectResult(success: success)
      self?.reply(to: "connect_device", with: payload, completion: nil)
    }
  }

  private func handleDisconnectDevice(_ message: Message) {
    let data: DisconnectDeviceData? = message.data()
    guard let address = data?.address else { return }
    UserDefaults.standard.removeObject(forKey: "address")
    UserDefaults.standard.removeObject(forKey: "name")

    Task { @MainActor [weak self] in
      guard let manager = self?.bluetoothManager else { return }
      let success = await manager.disconnect(to: address)
      let payload = ConnectResult(success: success)
      self?.reply(to: "disconnect_device", with: payload, completion: nil)
    }
  }

  private func handleSendData(_ message: Message) {
    let data: SendData? = message.data()
    guard let text = data?.data else { return }

    Task { @MainActor [weak self] in
      guard let manager = self?.bluetoothManager else { return }
      let result = await manager.send(bytes: text)
      let payload = SendResult(success: result.success, error: result.error)
      self?.reply(to: "send_data", with: payload, completion: nil)
    }
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
