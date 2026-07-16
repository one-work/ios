import Foundation
import CoreBluetooth

struct SendResultData {
  let success: Bool
  let error: String?
}

final class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  
  // MARK: - Callbacks
  var onDevicesFound: (([DeviceInfo]) -> Void)?
  var onConnected: ((Bool) -> Void)?
  var onDataSent: ((SendResultData) -> Void)?
  
  // MARK: - Properties
  private var centralManager: CBCentralManager?
  private var discoveredPeripherals: [CBPeripheral] = []
  private var targetPeripheral: CBPeripheral?
  private var targetCharacteristic: CBCharacteristic?
  private var scanTimer: Timer?

  // MARK: - Initialization
  func initialize() {
    centralManager = CBCentralManager(delegate: self, queue: nil)
  }

  // MARK: - Scan
  func startScan() {
    discoveredPeripherals.removeAll()
    centralManager?.scanForPeripherals(
      withServices: nil,
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
    )

    scanTimer?.invalidate()
    scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
      self?.centralManager?.stopScan()
      self?.sendDeviceList()
    }
  }

  private func sendDeviceList() {
    let devices: [DeviceInfo] = discoveredPeripherals.map { peripheral in
      return DeviceInfo(
        name: peripheral.name ?? "未知设备",
        address: peripheral.identifier.uuidString
      )
    }
    onDevicesFound?(devices)
  }

  // MARK: - Connect
  func connect(to uuidString: String) {
    guard let peripheral = discoveredPeripherals.first(where: {
      $0.identifier.uuidString == uuidString
    }) else {
      onConnected?(false)
      return
    }

    targetPeripheral = peripheral
    centralManager?.connect(peripheral, options: nil)
  }
  
  // MARK: - Send Data
  func send(data: String) {
    guard let peripheral = targetPeripheral,
          let characteristic = targetCharacteristic else {
      onDataSent?(SendResultData(success: false, error: "未连接设备"))
      return
    }

    guard let sendData = data.data(using: .utf8) else {
      onDataSent?(SendResultData(success: false, error: "数据编码失败"))
      return
    }

    peripheral.writeValue(sendData, for: characteristic, type: .withResponse)
    onDataSent?(SendResultData(success: true, error: nil))
  }
  
  // MARK: - CBCentralManagerDelegate
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {}

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let alreadyExists = discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier })
    if !alreadyExists {
      discoveredPeripherals.append(peripheral)
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didConnect peripheral: CBPeripheral
  ) {
    peripheral.delegate = self
    peripheral.discoverServices(nil)
    onConnected?(true)
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    onConnected?(false)
  }
  
  // MARK: - CBPeripheralDelegate
  
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverServices error: Error?
  ) {
    guard let services = peripheral.services else { return }
    for service in services {
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }
  
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    guard let characteristics = service.characteristics else { return }
    targetCharacteristic = characteristics.first(where: { $0.properties.contains(.write) })
  }
  
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if let error = error {
      onDataSent?(SendResultData(success: false, error: error.localizedDescription))
    } else {
      onDataSent?(SendResultData(success: true, error: nil))
    }
  }
}

// MARK: - 设备信息结构体
struct DeviceInfo: Encodable {
  let name: String
  let address: String
}
