import Foundation
import CoreBluetooth

struct SendResultData {
  let success: Bool
  let error: String?
}

final class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  static let shared = BluetoothManager()

  // MARK: - Callbacks
  var onDeviceFound: ((DeviceInfo) -> Void)?
  var onConnected: ((Bool) -> Void)?
  var onDisconnected: ((Bool) -> Void)?
  var onDataSent: ((SendResultData) -> Void)?

  // MARK: - Properties
  private var centralManager: CBCentralManager?
  private var discoveredPeripherals: [CBPeripheral] = []
  private var targetPeripheral: CBPeripheral?
  private var targetCharacteristic: CBCharacteristic?
  private var scanTimer: Timer?

  // MARK: - Initialization
  override init() {
    super.init()
    centralManager = CBCentralManager(delegate: self, queue: nil)
  }

  // MARK: - Scan
  func startScan() {
    discoveredPeripherals.removeAll()
    centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    scanTimer?.invalidate()
    scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
      self?.centralManager?.stopScan()
    }
  }

  // MARK: - Connect
  func connect(to uuidString: String) {
    guard let centralManager = centralManager else {
      onConnected?(false)
      return
    }

    if let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == uuidString }) {
      targetPeripheral = peripheral
      centralManager.connect(peripheral, options: nil)
      return
    }

    if let uuid = UUID(uuidString: uuidString) {
      let peripherals = getConnectedPeripherals(identifiers: [uuid])
      if let peripheral = peripherals.first {
        targetPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        return
      }
    }

    centralManager.scanForPeripherals(withServices: nil, options: nil)
  }

  // MARK: - Disconnect
  func disconnect(to uuidString: String) {
    guard let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == uuidString }) else { onDisconnected?(false); return }

    targetPeripheral = peripheral
    centralManager?.cancelPeripheralConnection(peripheral)
  }

  // MARK: - Send Data
  func send(bytes: [UInt8]) {
    guard let peripheral = targetPeripheral,
          let characteristic = targetCharacteristic else {
      onDataSent?(SendResultData(success: false, error: "未连接设备"))
      return
    }

    let packet = Data(bytes)
    peripheral.writeValue(packet, for: characteristic, type: .withResponse)
  }

  /// 获取当前已连接的设备列表 (必须提供该设备的 Service UUID)
  func getConnectedPeripherals(identifiers: [UUID]) -> [CBPeripheral] {
    return centralManager?.retrievePeripherals(withIdentifiers: identifiers) ?? []
  }

  // MARK: - CBCentralManagerDelegate
  func centralManagerDidUpdateState(_ central: CBCentralManager) {

    switch central.state {
    case .poweredOn:
      print("蓝牙已开启")
    case .poweredOff:
      print("蓝牙已关闭")
    default:
      break
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    let alreadyExists = discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier })
    if !alreadyExists && peripheral.name != nil {
      discoveredPeripherals.append(peripheral)
      onDeviceFound?(DeviceInfo(name: peripheral.name, address: peripheral.identifier.uuidString))
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    peripheral.delegate = self
    peripheral.discoverServices(nil)
    onConnected?(true)
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
    onDisconnected?(true)
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
    print(error?.localizedDescription ?? "连接失败")
    onConnected?(false)
  }

  // MARK: - CBPeripheralDelegate
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    for service in services {
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else { return }
    targetCharacteristic = characteristics.first(where: { $0.properties.contains(.write) })
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error = error {
      onDataSent?(SendResultData(success: false, error: error.localizedDescription))
    } else {
      onDataSent?(SendResultData(success: true, error: nil))
    }
  }
}

// MARK: - 设备信息结构体
struct DeviceInfo: Encodable {
  let name: String?
  let address: String
}
