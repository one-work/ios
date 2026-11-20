import Foundation
import UIKit
import HotwireNative

extension HotwireTab {
  static let all: [HotwireTab] = {
    var tabs: [HotwireTab] = [
      .navigation,
      .resources
    ]

    if Demo.current == Demo.local {
      tabs.append(.bugsAndFixes)
    }

    return tabs
  }()

  static let navigation = HotwireTab(
    title: "Home",
    image: .init(systemName: "house.fill")!,
    url: Demo.current.appendingPathComponent("auth/apps")
  )

  static let resources = HotwireTab(
    title: "Help",
    image: .init(systemName: "questionmark.text.page.fill")!,
    url: URL(string: "https://app-demo.xcprinter.com/README")!
  )
}
