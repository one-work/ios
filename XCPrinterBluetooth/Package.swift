// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "XCPrinterBluetooth",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "XCPrinterBluetooth",
            targets: ["XCPrinterBluetooth"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "XCPrinterBluetooth",
            path: "XCPrinterBluetooth.xcframework"
        )
    ]
)
