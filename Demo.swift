import Foundation

struct Demo {
  static let remote = URL(string: "https://admin.linlishenghuo.com")!
  static let local = URL(string: "http://localhost:3000")!
  
  /// Update this to choose which demo is run
  static var current: URL {
    remote
  }
}
