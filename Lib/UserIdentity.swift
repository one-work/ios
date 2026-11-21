import CloudKit
import Foundation
import HotwireNative
import Security
import WebKit

@MainActor
final class UserIdentity {
  static let shared = UserIdentity()

  private static let cloudRecordType = "UserIdentity"
  private static let cloudRecordName = "current-user"
  private static let cloudIdentifierKey = "identifier"

  private let webViews = NSHashTable<WKWebView>.weakObjects()
  private var cloudKitTask: Task<Void, Never>?

  private(set) var identifier: String

  var applicationUserAgentPrefix: String {
    "Hotwire XcPrinter-User-ID/\(identifier)"
  }

  private init() {
    if let savedIdentifier = UserIdentifierKeychain.load() {
      identifier = savedIdentifier
    } else {
      let generatedIdentifier = UUID().uuidString
      identifier = generatedIdentifier
      UserIdentifierKeychain.save(generatedIdentifier)
    }
  }

  func startCloudKitSynchronization() {
    guard cloudKitTask == nil else { return }

    cloudKitTask = Task { [weak self] in
      await self?.synchronizeWithCloudKit()
    }
  }

  func register(_ webView: WKWebView) {
    webViews.add(webView)
  }

  private func synchronizeWithCloudKit() async {
    defer { cloudKitTask = nil }

    let container = CKContainer.default()
    guard
      let accountStatus = try? await container.accountStatus(),
      accountStatus == .available
        else {
      return
    }

    let database = container.privateCloudDatabase
    let recordID = CKRecord.ID(recordName: Self.cloudRecordName)

    do {
      let record = try await database.record(for: recordID)
      adoptIdentifier(from: record)
    } catch let error as CKError {
      guard error.code == .unknownItem else { return }
      await createCloudRecord(in: database, recordID: recordID)
    } catch {
      return
    }
  }

  private func createCloudRecord(in database: CKDatabase, recordID: CKRecord.ID) async {
    let record = CKRecord(recordType: Self.cloudRecordType, recordID: recordID)
    record[Self.cloudIdentifierKey] = identifier as CKRecordValue

    do {
      _ = try await database.save(record)
    } catch let error as CKError {
      guard
        error.code == .serverRecordChanged,
        let savedRecord = try? await database.record(for: recordID)
          else {
        return
      }

      adoptIdentifier(from: savedRecord)
    } catch {
      return
    }
  }

  private func adoptIdentifier(from record: CKRecord) {
    guard
      let cloudIdentifier = record[Self.cloudIdentifierKey] as? String,
      UUID(uuidString: cloudIdentifier) != nil,
      cloudIdentifier != identifier
        else {
      return
    }

    let previousIdentifier = identifier
    identifier = cloudIdentifier
    UserIdentifierKeychain.save(cloudIdentifier)
    Hotwire.config.applicationUserAgentPrefix = applicationUserAgentPrefix

    for webView in webViews.allObjects {
      webView.evaluateJavaScript("navigator.userAgent") { result, _ in
        guard let userAgent = result as? String else { return }
        webView.customUserAgent = userAgent.replacingOccurrences(
          of: previousIdentifier,
          with: cloudIdentifier
        )
      }
    }
  }
}

private enum UserIdentifierKeychain {
  private static let service = (Bundle.main.bundleIdentifier ?? "com.xcprinter.xcprinter") + ".user-identity"
  private static let account = "user-identifier"

  private static var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }

  static func load() -> String? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard
      status == errSecSuccess,
      let data = result as? Data,
      let identifier = String(data: data, encoding: .utf8),
      UUID(uuidString: identifier) != nil
        else {
      return nil
    }

    return identifier
  }

  static func save(_ identifier: String) {
    let data = Data(identifier.utf8)
    let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    guard status == errSecItemNotFound else { return }

    var item = baseQuery
    item[kSecValueData as String] = data
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(item as CFDictionary, nil)
  }
}
