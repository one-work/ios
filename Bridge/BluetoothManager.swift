import Foundation
import CoreBluetooth

final class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  
  // MARK: - Callbacks
  var onDevicesFound: (([[String: String]]) -> Void)?
  var onConnected: ((Bool) -> Void)?
  var onDataSent: (([String: Any]) -> Void)?
  
  // MARK: - Properties
  private var centralManager: CBCentralManager?
  private var discoveredPeripherals: [CBPeripheral] = []
  private var targetPeripheral: CBPeripheral?
  private var targetCharacteristic: CBCharacteristic?
  
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
    
    // 5秒后停止扫描并返回结果
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      self?.centralManager?.stopScan()
      self?.sendDeviceList()
    }
  }
  
  private func sendDeviceList() {
    let devices = discoveredPeripherals.map { peripheral -> [String: String] in
      return [
        "name": peripheral.name ?? "未知设备",
        "address": peripheral.identifier.uuidString
      ]
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
      onDataSent?(["success": false, "error": "未连接设备或未找到可写特征"])
      return
    }
    
    guard let sendData = data.data(using: .utf8) else {
      onDataSent?(["success": false, "error": "数据编码失败"])
      return
    }
    
    peripheral.writeValue(sendData, for: characteristic, type: .withResponse)
    onDataSent?(["success": true])
  }
  
  // MARK: - CBCentralManagerDelegate
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    // 蓝牙状态变化，可在此处理 .poweredOn / .poweredOff
  }
  
  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
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
    // 保存第一个可写的特征值
    targetCharacteristic = characteristics.first { $0.properties.contains(.write) }
  }
  
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if let error = error {
      onDataSent?(["success": false, "error": error.localizedDescription])
    } else {
      onDataSent?(["success": true])
    }
  }
}
