import Foundation

struct Demo {
  static let remote = URL(string: "https://admin.linlishenghuo.com")!
  static let local = URL(string: "https://hotwire-native-demo.dev")!
  
  /// Update this to choose which demo is run
  static var current: URL {
    local
  }
}
