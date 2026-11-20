import HotwireNative
import SafariServices
import UIKit
import WebKit

final class SceneController: UIResponder {
  var window: UIWindow?

  private let rootURL = Demo.current
  private lazy var tabBarController = HotwireTabBarController(navigatorDelegate: self, lazyLoadTabs: true)
  private var isInitialInterruptionInProgress = false
  private var shouldRetryFailedVisit = false
  private var didHandleInitialInterruption = false
  private var failedVisitRetries: [ObjectIdentifier: (retryHandler: NavigatorDelegate.RetryBlock?, errorPresenter: any ErrorPresenter)] = [:]

  // MARK: - Authentication
  private func promptForAuthentication() {
    // Clean up empty screen from 401 response.
    tabBarController.activeNavigator.pop(animated: false)

    let authURL = rootURL.appendingPathComponent("/session/new")
    tabBarController.activeNavigator.route(authURL)
  }
}

extension SceneController: UIWindowSceneDelegate {

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }

    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = tabBarController
    window?.makeKeyAndVisible()
    tabBarController.load(HotwireTab.all)

    tagIdleWebViews()
  }

  func sceneWillResignActive(_ scene: UIScene) {
    guard !didHandleInitialInterruption else { return }
    isInitialInterruptionInProgress = true
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    guard isInitialInterruptionInProgress, !didHandleInitialInterruption else { return }
    isInitialInterruptionInProgress = false
    didHandleInitialInterruption = true

    // 网络权限没有授权结果回调；系统权限弹窗结束后重新加载配置并重试失败的访问。
    Hotwire.loadPathConfiguration(
      from: [
        .server(Demo.current.appendingPathComponent("configurations/ios_v1.json"))
      ]
    )
    shouldRetryFailedVisit = true
    retryFailedVisitsIfPossible()
  }

  private func retryFailedVisitsIfPossible() {
    guard shouldRetryFailedVisit, !failedVisitRetries.isEmpty else { return }
    shouldRetryFailedVisit = false

    let retries = failedVisitRetries
    failedVisitRetries.removeAll()

    for retry in retries.values {
      retry.retryHandler?()
      retry.errorPresenter.removeErrorViewController()
    }
  }

  // 给还没加载内容的 WebView 打标记，让 Safari 检查器里能分清是谁
  private func tagIdleWebViews() {
    for tab in HotwireTab.all {
      guard let navigator = tabBarController.navigator(for: tab) else { continue }

      if navigator.session.webView.url == nil {
        navigator.session.webView.loadMarkerTitle("主栈 · \(tab.title)")
      }
      if navigator.modalSession.webView.url == nil {
        navigator.modalSession.webView.loadMarkerTitle("模态栈 · \(tab.title)")
      }
    }
  }
}

private extension WKWebView {
  func loadMarkerTitle(_ title: String) {
    loadHTMLString("<html><head><title>\(title)</title></head><body></body></html>", baseURL: nil)
  }
}

extension SceneController: NavigatorDelegate {

  func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {

    switch proposal.viewController {
    default:
      return .acceptCustom(WebViewController(url: proposal.url, navigator: navigator))
    }
  }

  func visitableDidFailRequest(_ visitable: any Visitable, error: HotwireNativeError, retryHandler: RetryBlock?) {
    switch error {
    case .http(.client(.unauthorized)):
      promptForAuthentication()
    default:
      if let errorPresenter = visitable as? ErrorPresenter {
        let visitableID = ObjectIdentifier(visitable)
        failedVisitRetries[visitableID] = (retryHandler, errorPresenter)

        if shouldRetryFailedVisit {
          retryFailedVisitsIfPossible()
          return
        }

        errorPresenter.presentError(error) { [weak self] in
          self?.failedVisitRetries.removeValue(forKey: visitableID)
          retryHandler?()
        }
      } else {
        let alert = UIAlertController(title: "Visit failed!", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        tabBarController.activeNavigator.present(alert, animated: true)
      }
    }
  }
}

extension Navigator {
  private enum ExternalSessionRegistry {
    // 键为弱引用：Navigator 销毁后条目自动失效，无需手动清理
    static let sessions = NSMapTable<Navigator, ExternalWebSession>(keyOptions: .weakMemory, valueOptions: .strongMemory)
  }

  // 与 session / modalSession 平行的外部站点 Session
  var externalSession: ExternalWebSession {
    if let existing = ExternalSessionRegistry.sessions.object(forKey: self) {
      return existing
    }
    let created = ExternalWebSession(navigator: self)
    ExternalSessionRegistry.sessions.setObject(created, forKey: self)
    return created
  }

  // 主、modal、外部三个 Session 一起刷新
  func reloadAllSessions() {
    reload()
    externalSession.session.reload()
  }
}
