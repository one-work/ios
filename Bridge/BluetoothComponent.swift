import HotwireNative
import Foundation

final class BluetoothComponent: BridgeComponent {
    public override class var name: String { "bluetooth" }
    
    private lazy var bluetoothManager: BluetoothManager = {
        let manager = BluetoothManager()
        manager.onDevicesFound = { [weak self] devices in
            self?.reply(to: "search", with: ["devices": devices])
        }
        manager.onConnected = { [weak self] success in
            self?.reply(to: "connect_device", with: success)
        }
        manager.onDataSent = { [weak self] result in
            self?.reply(to: "send_data", with: result)
        }
        return manager
    }()
    
    public override func onReceive(message: Message) {
        switch message.event {
        case "connect":
            bluetoothManager.initialize()
            reply(to: "connect")
            
        case "search":
            bluetoothManager.startScan()
            
        case "connect_device":
            if let data: ConnectDeviceData = message.data() {
                bluetoothManager.connect(to: data.address)
            }
            
        case "send_data":
            if let data: SendData = message.data() {
                bluetoothManager.send(data: data.data)
            }
            
        default:
            break
        }
    }
}

// MARK: - Data Models

private extension BluetoothComponent {
    struct ConnectDeviceData: Decodable {
        let address: String
    }
    
    struct SendData: Decodable {
        let address: String
        let data: String
    }
}
