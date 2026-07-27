import Foundation
import UIKit
import HotwireNative

extension HotwireTab {
  static let all: [HotwireTab] = {
    var tabs: [HotwireTab] = [
      .navigation,
      .bridgeComponents,
      .resources
    ]

    if Demo.current == Demo.local {
      tabs.append(.bugsAndFixes)
    }

    return tabs
  }()

  static let navigation = HotwireTab(
    title: "Home",
    image: .init(systemName: "arrow.left.arrow.right")!,
    url: Demo.current.appendingPathComponent("auth/apps")
  )

  static let bridgeComponents = HotwireTab(
    title: "Bluetooth",
    image: .init(systemName: "widget.small")!,
    url: Demo.current.appendingPathComponent("bluetooth")
  )

  static let resources = HotwireTab(
    title: "Help",
    image: .init(systemName: "questionmark.text.page")!,
    url: Demo.current.appendingPathComponent("resources")
  )

  static let bugsAndFixes = HotwireTab(
    title: "Bugs & Fixes",
    image: .init(systemName: "ladybug")!,
    url: Demo.current.appendingPathComponent("bugs")
  )
}
