import Foundation
import CoreBluetooth

struct SendResultData {
  let success: Bool
  let error: String?
}

final class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  static let shared = BluetoothManager()

  // MARK: - 打印机 GATT 服务/特征值（对照安卓 BluetoothPrinterManager 与流控文档 §2）
  private let serviceUUID = CBUUID(string: "FF00")
  private let writeCharUUID = CBUUID(string: "FF02")   // Write No Response 下行数据通道
  private let notifyCharUUID = CBUUID(string: "FF03")  // Notify 上行流控通道（MTU + Credits）

  // MARK: - FF03 通知包类型标识（首字节，对照文档 §2.3）
  private let notifyTypeCredits: UInt8 = 0x01
  private let notifyTypeMTU: UInt8 = 0x02

  // MARK: - 流控参数（对照文档 §3）
  /// 协商前的保守单包大小（默认 ATT MTU 23 - 3）
  private let defaultPacketSize = 20
  /// 启用 FF03 通知后等待首帧 Credits 的提示超时（仅日志提示，不阻断）
  private let creditsTimeoutSeconds: TimeInterval = 5
  /// 应用层连接超时兜底
  private let connectTimeoutSeconds: TimeInterval = 30
  private let scanDurationSeconds: TimeInterval = 5

  // MARK: - Callbacks（统一在主线程派发）
  var onReady: ((Bool) -> Void)?
  var onDeviceFound: ((DeviceInfo) -> Void)?
  var onConnected: ((Bool) -> Void)?
  var onDisconnected: ((Bool) -> Void)?
  var onDataSent: ((SendResultData) -> Void)?

  // MARK: - Properties
  /// 所有 CoreBluetooth 系统回调与流控状态都在该串行队列上处理，
  /// 保证线程安全与包按入队顺序到达打印机（对照文档 §3.2 规则 4）
  private let bleQueue = DispatchQueue(label: "com.xcprinter.ble.queue")
  private var centralManager: CBCentralManager!

  private var discoveredPeripherals: [CBPeripheral] = []
  private var targetPeripheral: CBPeripheral?
  private var writeCharacteristic: CBCharacteristic?
  private var notifyCharacteristic: CBCharacteristic?

  private var isScanning = false
  private var connectInFlight = false
  private var suppressDisconnectNotify = false

  private var scanStopWorkItem: DispatchWorkItem?
  private var connectTimeoutWorkItem: DispatchWorkItem?
  private var creditsTimeoutWorkItem: DispatchWorkItem?

  // MARK: - 流控状态（仅 bleQueue 访问，对照文档 §3.1）
  /// 单包最大字节：先取系统协商的 MTU 载荷，后以 FF03 MTU 通知为准
  private var packetSize: Int = 20
  /// 当前可用发送配额：协议规定初始为 0，必须等待 FF03 Credits 通知
  private var credits = 0
  private var creditsReceived = false
  private var mtuNegotiated = false
  /// 待发送分包队列（FIFO）
  private var sendQueue: [Data] = []
  /// 每个 send() 调用对应一条记录，remaining 归零时回调成功（对照安卓 PendingSend）
  private var pendingSends: [PendingSend] = []

  private final class PendingSend {
    var remaining: Int
    init(_ remaining: Int) { self.remaining = remaining }
  }

  // MARK: - Initialization
  override init() {
    super.init()
    centralManager = CBCentralManager(delegate: self, queue: bleQueue)
  }

  private func dispatchOnMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
  }

  // MARK: - Scan
  func startScan() {
    bleQueue.async { [weak self] in
      guard let self = self else { return }
      self.discoveredPeripherals.removeAll()
      self.scanStopWorkItem?.cancel()
      guard self.centralManager.state == .poweredOn else { return }

      self.isScanning = true
      self.centralManager.scanForPeripherals(
        withServices: nil,
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
      )

      let stopItem = DispatchWorkItem { [weak self] in self?.stopScan() }
      self.scanStopWorkItem = stopItem
      self.bleQueue.asyncAfter(deadline: .now() + self.scanDurationSeconds, execute: stopItem)
    }
  }

  private func stopScan() {
    guard isScanning else { return }
    isScanning = false
    scanStopWorkItem?.cancel()
    scanStopWorkItem = nil
    centralManager.stopScan()
  }

  // MARK: - Connect
  func connect(to uuidString: String) {
    bleQueue.async { [weak self] in
      guard let self = self else { return }
      guard let peripheral = self.resolvePeripheral(uuidString) else {
        // 未找到设备：重新扫描，等待设备下次广播（保持原有行为）
        self.startScan()
        return
      }

      // 扫描与连接并发会显著降低建链成功率，连接前先停止扫描
      self.stopScan()
      // 重连前收尾旧连接（对照安卓 closeGatt），其断开回调静默处理
      if let old = self.targetPeripheral,
         old.identifier != peripheral.identifier,
         old.state != .disconnected {
        self.suppressDisconnectNotify = true
        self.centralManager.cancelPeripheralConnection(old)
      }
      self.resetFlowControl()

      self.targetPeripheral = peripheral
      peripheral.delegate = self
      self.connectInFlight = true
      self.centralManager.connect(peripheral, options: nil)
      self.scheduleConnectTimeout()
    }
  }

  // MARK: - Disconnect
  func disconnect(to uuidString: String) {
    bleQueue.async { [weak self] in
      guard let self = self else { return }
      var peripheral = self.resolvePeripheral(uuidString)
      if peripheral == nil, self.targetPeripheral?.identifier.uuidString == uuidString {
        peripheral = self.targetPeripheral
      }
      guard let target = peripheral else {
        self.dispatchOnMain { self.onDisconnected?(true) }
        return
      }
      self.centralManager.cancelPeripheralConnection(target)
    }
  }

  private func resolvePeripheral(_ uuidString: String) -> CBPeripheral? {
    if let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == uuidString }) {
      return peripheral
    }
    if let uuid = UUID(uuidString: uuidString) {
      return centralManager.retrievePeripherals(withIdentifiers: [uuid]).first
    }
    return nil
  }

  private func scheduleConnectTimeout() {
    connectTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self = self, self.connectInFlight, let peripheral = self.targetPeripheral else { return }
      print("[Bluetooth] 连接超时（\(Int(self.connectTimeoutSeconds))s），取消连接")
      self.centralManager.cancelPeripheralConnection(peripheral)
    }
    connectTimeoutWorkItem = item
    bleQueue.asyncAfter(deadline: .now() + connectTimeoutSeconds, execute: item)
  }

  // MARK: - Send Data
  /**
   * 发送业务数据（对照安卓 send / 小程序 ble.send）：
   * 按 packetSize 切片入队，由 Credits 流控驱动经 FF02 writeNoResponse 串行写出。
   * 数据先排队，收到打印机 Credits 后自动发出；onDataSent 在本次调用的
   * 全部数据写完后回调一次。
   *
   * 注意：运行期间若收到新的 FF03 MTU 通知，仅影响后续 send 调用的切片，
   * 已入队的旧包不重新切分（对照文档 §3.2 规则 5）。
   */
  func send(bytes: [UInt8]) {
    bleQueue.async { [weak self] in
      guard let self = self else { return }
      guard let peripheral = self.targetPeripheral, peripheral.state == .connected else {
        self.dispatchOnMain { self.onDataSent?(SendResultData(success: false, error: "未连接设备")) }
        return
      }
      if bytes.isEmpty {
        self.dispatchOnMain { self.onDataSent?(SendResultData(success: true, error: nil)) }
        return
      }

      let size = max(1, self.packetSize)
      let data = Data(bytes)
      var count = 0
      var offset = 0
      while offset < data.count {
        let end = min(offset + size, data.count)
        self.sendQueue.append(data.subdata(in: offset..<end))
        offset = end
        count += 1
      }
      self.pendingSends.append(PendingSend(count))
      print("[Bluetooth] 入队 \(data.count) 字节（\(count) 包，packetSize=\(size)，credits=\(self.credits)）")
      self.flushQueue()
    }
  }

  /**
   * 冲刷发送队列（对照安卓 flushQueue / 文档 §3.3）：
   * credits<=0 时挂起，等待 FF03 Credits 通知恢复；
   * canSendWriteWithoutResponse 为 false 时挂起，等待
   * peripheralIsReady(toSendWriteWithoutResponse:) 恢复（iOS 本地队列防溢出）。
   */
  private func flushQueue() {
    guard let peripheral = targetPeripheral,
          let writeChar = writeCharacteristic,
          peripheral.state == .connected else { return }

    while credits > 0, !sendQueue.isEmpty, peripheral.canSendWriteWithoutResponse {
      let packet = sendQueue.removeFirst()
      credits -= 1
      peripheral.writeValue(packet, for: writeChar, type: .withoutResponse)

      if let pending = pendingSends.first {
        pending.remaining -= 1
        if pending.remaining <= 0 {
          pendingSends.removeFirst()
          dispatchOnMain { self.onDataSent?(SendResultData(success: true, error: nil)) }
        }
      }
    }

    if credits <= 0, !sendQueue.isEmpty {
      print("[Bluetooth] credits 耗尽，挂起发送（队列剩余 \(sendQueue.count) 包）")
    }
  }

  /**
   * 写入失败/断开时清空发送队列并向上层报错（每条 pending 记录回调一次）。
   * 桥接层每条 send_data 消息需明确答复，故直接报错由 JS 决定重发（对照安卓实现）。
   */
  private func failPendingSends(_ error: String) {
    let count = pendingSends.count
    sendQueue.removeAll()
    pendingSends.removeAll()
    guard count > 0 else { return }
    dispatchOnMain { [weak self] in
      guard let self = self else { return }
      for _ in 0..<count {
        self.onDataSent?(SendResultData(success: false, error: error))
      }
    }
  }

  /// 断开后复位全部流控状态（对照文档 §4.4 resetState）
  private func resetFlowControl() {
    sendQueue.removeAll()
    pendingSends.removeAll()
    credits = 0
    creditsReceived = false
    mtuNegotiated = false
    packetSize = defaultPacketSize
    writeCharacteristic = nil
    notifyCharacteristic = nil
    creditsTimeoutWorkItem?.cancel()
    creditsTimeoutWorkItem = nil
  }

  private func scheduleCreditsTimeout() {
    creditsTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self = self, !self.creditsReceived else { return }
      print("[Bluetooth] 启用 FF03 通知 \(Int(self.creditsTimeoutSeconds))s 后仍未收到 Credits，请检查打印机连接")
    }
    creditsTimeoutWorkItem = item
    bleQueue.asyncAfter(deadline: .now() + creditsTimeoutSeconds, execute: item)
  }

  /// 获取当前已连接的设备列表 (必须提供该设备的 Service UUID)
  func getConnectedPeripherals(identifiers: [UUID]) -> [CBPeripheral] {
    return centralManager.retrievePeripherals(withIdentifiers: identifiers)
  }

  // MARK: - CBCentralManagerDelegate
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      print("蓝牙已开启")
      dispatchOnMain { self.onReady?(true) }
    case .poweredOff:
      print("蓝牙已关闭")
    default:
      break
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    guard peripheral.name != nil,
          !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) else { return }
    discoveredPeripherals.append(peripheral)
    let info = DeviceInfo(name: peripheral.name, address: peripheral.identifier.uuidString)
    dispatchOnMain { self.onDeviceFound?(info) }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    connectInFlight = false
    connectTimeoutWorkItem?.cancel()
    // 系统建链时已自动协商 MTU，先取协商值作为临时切片长度（对照 wx.setBLEMTU 的效果）；
    // 后续若收到 FF03 MTU 通知则以打印机真实上限覆盖（对照文档 §6.3）
    packetSize = max(defaultPacketSize, peripheral.maximumWriteValueLength(for: .withoutResponse))
    mtuNegotiated = true
    print("[Bluetooth] 已连接，临时 packetSize=\(packetSize)")
    peripheral.delegate = self
    // 仅枚举 FF00 服务，加快就绪速度
    peripheral.discoverServices([serviceUUID])
    dispatchOnMain { self.onConnected?(true) }
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
    connectInFlight = false
    connectTimeoutWorkItem?.cancel()
    if targetPeripheral?.identifier == peripheral.identifier { targetPeripheral = nil }
    print(error?.localizedDescription ?? "连接失败")
    dispatchOnMain { self.onConnected?(false) }
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
    let wasConnecting = connectInFlight
    connectInFlight = false
    connectTimeoutWorkItem?.cancel()
    failPendingSends("连接已断开")
    resetFlowControl()
    if targetPeripheral?.identifier == peripheral.identifier { targetPeripheral = nil }

    if suppressDisconnectNotify {
      // 主动取消（重连前的收尾 / 非目标设备），不上报断开
      suppressDisconnectNotify = false
    } else if wasConnecting {
      dispatchOnMain { self.onConnected?(false) }
    } else {
      dispatchOnMain { self.onDisconnected?(true) }
    }
  }

  // MARK: - CBPeripheralDelegate
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
    guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
      // 找不到 FF00 → 判定非目标设备，主动断开物理连接（对照安卓 _forceDisconnect）
      print("[Bluetooth] 未找到 FF00 服务，判定非目标设备，断开连接")
      suppressDisconnectNotify = true
      centralManager.cancelPeripheralConnection(peripheral)
      return
    }
    peripheral.discoverCharacteristics([writeCharUUID, notifyCharUUID], for: service)
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
    guard error == nil,
          let write = service.characteristics?.first(where: { $0.uuid == writeCharUUID }),
          let notify = service.characteristics?.first(where: { $0.uuid == notifyCharUUID }) else {
      // 找不全 FF02/FF03 → 同样主动断开并报错
      print("[Bluetooth] GATT 枚举不完整（缺少 FF02/FF03），判定非目标设备，断开连接")
      suppressDisconnectNotify = true
      centralManager.cancelPeripheralConnection(peripheral)
      return
    }

    writeCharacteristic = write
    notifyCharacteristic = notify
    // 枚举期间系统可能已完成 MTU 协商，刷新一次临时切片长度（FF03 MTU 通知到达后仍以其为准）
    packetSize = max(defaultPacketSize, peripheral.maximumWriteValueLength(for: .withoutResponse))
    // 启用 FF03 通知（MTU + Credits 流控通道），并启动 5 秒 Credits 等待提示
    peripheral.setNotifyValue(true, for: notify)
    scheduleCreditsTimeout()
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
    if let error = error {
      print("[Bluetooth] 启用 FF03 通知失败: \(error.localizedDescription)")
      return
    }
    if characteristic.uuid == notifyCharUUID, characteristic.isNotifying {
      scheduleCreditsTimeout()
    }
  }

  /// FF03 上行流控通知（对照安卓 onCharacteristicChanged / 文档 §2.3）
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
    guard error == nil,
          characteristic.uuid == notifyCharUUID,
          let value = characteristic.value,
          !value.isEmpty else { return }

    switch value[0] {
    // (a) MTU 通知包：0x02 + 小端 16bit 单包最大字节数，覆盖协商值
    case notifyTypeMTU:
      if value.count >= 3 {
        let size = Int(value[1]) | (Int(value[2]) << 8)
        packetSize = size
        mtuNegotiated = true
        print("[Bluetooth] FF03 MTU 通知：packetSize=\(size)")
      }
    // (b) Credits 通知包：0x01 + 增量配额，credits += N 并恢复挂起的发送
    case notifyTypeCredits:
      if value.count >= 2 {
        let delta = Int(value[1])
        let first = !creditsReceived
        creditsReceived = true
        creditsTimeoutWorkItem?.cancel()
        creditsTimeoutWorkItem = nil
        credits += delta
        if first { print("[Bluetooth] 收到首个 Credits（+\(delta)），开始下发数据") }
        flushQueue()
      }
    default:
      break
    }
  }

  /// iOS 本地发送队列恢复可写（MTU 变化或队列腾出空间时触发），驱动挂起的冲刷
  func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
    flushQueue()
  }
}

// MARK: - 设备信息结构体
struct DeviceInfo: Encodable {
  let name: String?
  let address: String
}
