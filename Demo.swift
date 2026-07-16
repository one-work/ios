import Foundation

struct Demo {
  static let remote = URL(string: "https://linlishenghuo.com")!
  static let local = URL(string: "http://localhost:3000")!
  static let example = URL(string: "https://hotwire-native-demo.dev")!

  static var current: URL {
    example
  }
}
