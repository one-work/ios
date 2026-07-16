import CoreBluetooth
import Foundation

final class BluetoothManager: NSObject, CBCentralManagerDelegate {
  private var centralManager: CBCentralManager?

  override init() {
    super.init()
    centralManager = CBCentralManager(delegate: self, queue: nil)
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      central.scanForPeripherals(withServices: nil, options: [
        CBCentralManagerScanOptionAllowDuplicatesKey: false
      ])
    case .unauthorized:
      print("蓝牙无权限")
    case .poweredOff:
      print("蓝牙已关闭")
    default:
      break
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    print("发现设备: \(peripheral.name ?? "Unknown")")
  }
}
