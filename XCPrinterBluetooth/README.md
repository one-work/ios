# XCPrinterBluetooth

基于 CoreBluetooth 的打印机 SDK，支持设备扫描、连接、断开、数据发送，以及打印机 MTU 和 Credits 流控。

- 最低系统版本：iOS 14
- 依赖：Foundation、CoreBluetooth
- 不依赖 HotwireNative，可在普通 iOS 项目中独立使用

## 接入方式

### Xcode 本地 Package

在 Xcode 中选择 **File > Add Package Dependencies…**，添加本地的 `XCPrinterBluetooth` 目录，然后将 `XCPrinterBluetooth` library 添加到 App target。

### Swift Package 依赖

在其他 Package 中使用时：

```swift
.package(path: "../XCPrinterBluetooth")
```

并在 target 中添加：

```swift
.product(
    name: "XCPrinterBluetooth",
    package: "XCPrinterBluetooth"
)
```

路径请根据实际项目位置调整。

## 配置蓝牙权限

接入 SDK 的 App 必须在自己的 `Info.plist` 中添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要访问蓝牙以搜索并连接打印机进行打印</string>
```

权限说明文字可根据 App 的实际用途调整。

## 创建实例

```swift
import XCPrinterBluetooth

let bluetooth = BluetoothManager()
```

请持有该实例，并使用同一个实例完成扫描、连接、发送和断开操作。不同实例分别管理自己的 CoreBluetooth 会话，不要为每次操作创建新实例。

## 扫描设备

`scan()` 返回 `AsyncStream<DeviceInfo>`。每次扫描持续 5 秒，发现设备时产生事件：

```swift
let scanTask = Task {
    for await device in bluetooth.scan() {
        print("名称：\(device.name ?? "未知")")
        print("标识：\(device.address)")
    }
}
```

`DeviceInfo` 属性：

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `name` | `String?` | 设备广播名称 |
| `address` | `String` | iOS 分配的设备 UUID 字符串，用于连接和断开 |

如需停止消费扫描事件，可以取消对应的 Task：

```swift
scanTask.cancel()
```

## 连接设备

使用扫描结果中的 `address`：

```swift
let connected = await bluetooth.connect(to: device.address)

if connected {
    print("连接成功")
} else {
    print("连接失败")
}
```

建议先完成设备扫描，再发起连接。如果找不到指定设备，当前实现会重新开始扫描并返回 `false`。

连接结果表示系统蓝牙链路已经建立；SDK 会继续在后台完成 FF00 服务、FF02/FF03 特征值和通知初始化。

## 发送数据

接口接收 `[UInt8]`：

```swift
let bytes: [UInt8] = [0x1B, 0x40]
let result = await bluetooth.send(bytes: bytes)

if result.success {
    print("数据已写入蓝牙通道")
} else {
    print("发送失败：\(result.error ?? "未知错误")")
}
```

如果已有 `Data`，可以这样转换：

```swift
let result = await bluetooth.send(bytes: Array(data))
```

SDK 会根据 MTU 自动分包，并通过 Credits 流控串行发送。`success == true` 表示本次调用的数据已全部提交到蓝牙写通道，不表示打印机已经完成打印。

未连接设备时会返回：

```swift
SendResultData(success: false, error: "未连接设备")
```

连接断开时，尚未完成的发送会返回失败结果，由调用方决定是否重发。

## 断开连接

```swift
let disconnected = await bluetooth.disconnect(to: device.address)
```

设备已经不存在或未连接时，当前实现返回 `true`。

## 监听蓝牙就绪事件

蓝牙变为可用时，`readyEvents` 会发出 `true`：

```swift
let readyTask = Task {
    for await isReady in bluetooth.readyEvents {
        print("蓝牙就绪：\(isReady)")
    }
}
```

## 监听意外断开事件

非主动调用 `disconnect` 导致的设备断开，会通过 `disconnectionEvents` 通知：

```swift
let disconnectionTask = Task {
    for await disconnected in bluetooth.disconnectionEvents {
        print("设备已断开：\(disconnected)")
    }
}
```

不再需要监听时，取消对应 Task：

```swift
readyTask.cancel()
disconnectionTask.cancel()
```

## 查询已知设备状态

如果已经持有设备 UUID，可以查询系统当前记录的设备：

```swift
if let uuid = UUID(uuidString: device.address) {
    let peripherals = await bluetooth.getConnectedPeripherals(
        identifiers: [uuid]
    )

    if let peripheral = peripherals.first {
        print("连接状态：\(peripheral.state.rawValue)")
    }
}
```

该方法返回 CoreBluetooth 的 `CBPeripheral`，需要时可在调用文件中导入：

```swift
import CoreBluetooth
```
